#if __APPLE__
#include "TargetConditionals.h"
#endif

#ifdef _WIN32
#pragma comment(lib, "Ws2_32.lib")
#endif

#include <math/mat4.h>
#include <utils/EntityManager.h>
#include <utils/Panic.h>
#include <utils/Systrace.h>
#ifdef __EMSCRIPTEN__
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#endif
#include <filament/Box.h>
#include <filament/Camera.h>
#include <filament/ColorGrading.h>
#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndexBuffer.h>
#include <filament/IndirectLight.h>
#include <filament/LightManager.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <map>

#include "Log.hpp"
#include "rendering/RenderManager.hpp"
#include "PluginAPI.hpp"

namespace thermion
{

  using namespace filament;
  using namespace filament::math;
  using namespace utils;

  using std::string;

  void RenderManager::removeSwapChain(SwapChain *swapChain)
  {
    std::lock_guard lock(mMutex);
    auto it = std::remove_if(mViewAttachments.begin(), mViewAttachments.end(),
                             [swapChain](const ViewAttachment &va)
                             { return va.swapChain == swapChain; });
    mViewAttachments.erase(it, mViewAttachments.end());
  }

  void RenderManager::setRenderable(SwapChain *swapChain, View **views, uint8_t numViews)
  {
    std::lock_guard lock(mMutex);

    // Find existing entry for this swapchain
    ViewAttachment *attachment = nullptr;
    for (auto &va : mViewAttachments)
    {
      if (va.swapChain == swapChain)
      {
        attachment = &va;
        break;
      }
    }

    // Create new entry if not found
    if (!attachment)
    {
      mViewAttachments.push_back(ViewAttachment{});
      attachment = &mViewAttachments.back();
      attachment->swapChain = swapChain;
    }

    // Update views
    for (int i = 0; i < numViewAttachments; i++)
    {
      if(i < numViews) {
        attachment->views[i] = views[i];
        if(!views[i]) {
          LOG_ERROR("View attachment at %d is nullptr, this is not expected", i);  
        }
      } else { 
        attachment->views[i] = nullptr;
      }
    }
    TRACE("Set %d view attachments for swapchain", numViews);
  }

  bool RenderManager::render(uint64_t frameTimeInNanos)
  {
    auto startTime = std::chrono::high_resolution_clock::now();

    std::lock_guard lock(mMutex);

    for (auto animationManager : mAnimationManagers)
    {
      animationManager->update(frameTimeInNanos);
    }

    thermion::plugin::UpdatePlugins(frameTimeInNanos);

    auto durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
    TRACE("Updated animations in %.3f ms", durationNs);

    bool rendered = false;
    int swapChainIndex = 0;
    int skippedCount = 0;

    // Render each swapchain
    for (auto &attachment : mViewAttachments)
    {
      if (!attachment.swapChain)
      {
        Log("No swapchain, ignoring");
        continue;
      }

      auto beforeBegin = std::chrono::high_resolution_clock::now();
      bool beginFrame = mRenderer->beginFrame(attachment.swapChain, frameTimeInNanos);
      auto afterBegin = std::chrono::high_resolution_clock::now();
      float beginMs = std::chrono::duration_cast<std::chrono::nanoseconds>(afterBegin - beforeBegin).count() / 1e6f;

      if (beginFrame)
      {
        durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
        TRACE("Beginning frame for swapchain %d (%.3f ms since last endFrame())", swapChainIndex, durationNs);

        int numRendered = 0;
        for (int i = 0; i < numViewAttachments; i++)
        {
          if (!attachment.views[i]) {
            break;
          }
          numRendered++;
          mRenderer->render(attachment.views[i]);
        }

        auto beforeEnd = std::chrono::high_resolution_clock::now();
        mRenderer->endFrame();
        mLastRender = std::chrono::high_resolution_clock::now();
        float endFrameMs = std::chrono::duration_cast<std::chrono::nanoseconds>(mLastRender - beforeEnd).count() / 1e6f;

        TRACE("%d views rendered for swapchain %d", numRendered, swapChainIndex);
        if (numRendered > 0) {
          rendered = true;
        }

        // Log if endFrame took a long time (GPU stall / sync)
        if (endFrameMs > 5.0f) {
          fprintf(stderr, "[RENDER] endFrame() took %.1fms (GPU stall?)\n", endFrameMs);
        }
      }
      else
      {
        skippedCount++;
        durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
        TRACE("Skipping frame for swapchain %d (%.3f ms since last endFrame())", swapChainIndex, durationNs);
        fprintf(stderr, "[RENDER] beginFrame() REJECTED sc=%d (%.1fms since last, beginFrame took %.1fms)\n",
                swapChainIndex, durationNs, beginMs);
      }
      swapChainIndex++;
    }

    #ifdef __EMSCRIPTEN__
        mEngine->execute();
    #endif

    auto endTime = std::chrono::high_resolution_clock::now();
    durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    float durationMs = durationNs / 1e6f;

    TRACE("Total render() time for %d swapchains: %.3f ms", swapChainIndex, durationMs);

    static int renderCount = 0;
    static int totalSkips = 0;
    static float maxRenderMs = 0;
    static float sumRenderMs = 0;
    renderCount++;
    totalSkips += skippedCount;
    if (durationMs > maxRenderMs) maxRenderMs = durationMs;
    sumRenderMs += durationMs;

    if (renderCount <= 3 || renderCount % 120 == 0) {
      float avgMs = sumRenderMs / (renderCount <= 3 ? renderCount : 120);
      fprintf(stderr, "[RENDER] #%d %.1fms (avg=%.1fms max=%.1fms) skips=%d rendered=%d\n",
              renderCount, durationMs, avgMs, maxRenderMs, totalSkips, rendered);
      if (renderCount > 3) {
        maxRenderMs = 0;
        sumRenderMs = 0;
        totalSkips = 0;
      }
    }
    return rendered;
  }

  void RenderManager::addAnimationManager(AnimationManager *animationManager)
  {
    std::lock_guard<std::mutex> lock(mMutex);
    mAnimationManagers.push_back(animationManager);
  }

  void RenderManager::removeAnimationManager(AnimationManager *animationManager)
  {
    std::lock_guard<std::mutex> lock(mMutex);
    auto it = std::find(mAnimationManagers.begin(), mAnimationManagers.end(), animationManager);
    if (it != mAnimationManagers.end())
    {
      mAnimationManagers.erase(it);
    }
  }

  RenderManager::~RenderManager() {}

} // namespace thermion