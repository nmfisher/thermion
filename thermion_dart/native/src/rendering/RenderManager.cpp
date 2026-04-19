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

  void RenderManager::updateAnimationsAndPlugins(uint64_t frameTimeInNanos)
  {
    for (auto animationManager : mAnimationManagers)
    {
      animationManager->update(frameTimeInNanos);
    }
    thermion::plugin::UpdatePlugins(frameTimeInNanos);
  }

  bool RenderManager::renderSwapChainAt(size_t index, uint64_t frameTimeInNanos)
  {
    if (index >= mViewAttachments.size()) return false;
    auto &attachment = mViewAttachments[index];
    if (!attachment.swapChain)
    {
      Log("No swapchain, ignoring");
      return false;
    }

    auto beforeBegin = std::chrono::high_resolution_clock::now();
    bool beginFrame = mRenderer->beginFrame(attachment.swapChain, frameTimeInNanos);
    auto afterBegin = std::chrono::high_resolution_clock::now();
    float beginMs = std::chrono::duration_cast<std::chrono::nanoseconds>(afterBegin - beforeBegin).count() / 1e6f;

    if (!beginFrame)
    {
      float sinceLastMs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                              std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
      TRACE("Skipping frame for swapchain %zu (%.3f ms since last endFrame())", index, sinceLastMs);
      (void)beginMs;
      return false;
    }

    float sinceLastMs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                            std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
    TRACE("Beginning frame for swapchain %zu (%.3f ms since last endFrame())", index, sinceLastMs);

    int numRendered = 0;
    for (int i = 0; i < numViewAttachments; i++)
    {
      if (!attachment.views[i]) break;
      numRendered++;
      mRenderer->render(attachment.views[i]);
    }

    auto beforeEnd = std::chrono::high_resolution_clock::now();
    mRenderer->endFrame();
    mLastRender = std::chrono::high_resolution_clock::now();
    float endFrameMs = std::chrono::duration_cast<std::chrono::nanoseconds>(mLastRender - beforeEnd).count() / 1e6f;

    TRACE("%d views rendered for swapchain %zu", numRendered, index);

    if (endFrameMs > 5.0f) {
      fprintf(stderr, "[RENDER] endFrame() took %.1fms (GPU stall?)\n", endFrameMs);
    }

    return numRendered > 0;
  }

  bool RenderManager::render(uint64_t frameTimeInNanos)
  {
    auto startTime = std::chrono::high_resolution_clock::now();

    std::lock_guard lock(mMutex);

    updateAnimationsAndPlugins(frameTimeInNanos);

    auto durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
    TRACE("Updated animations in %.3f ms", durationNs);

    bool rendered = false;
    int skippedCount = 0;
    for (size_t i = 0; i < mViewAttachments.size(); i++)
    {
      if (renderSwapChainAt(i, frameTimeInNanos)) {
        rendered = true;
      } else if (mViewAttachments[i].swapChain) {
        skippedCount++;
      }
    }

    #ifdef __EMSCRIPTEN__
        mEngine->execute();
    #endif

    auto endTime = std::chrono::high_resolution_clock::now();
    durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    float durationMs = durationNs / 1e6f;

    TRACE("Total render() time for %zu swapchains: %.3f ms", mViewAttachments.size(), durationMs);

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

  void RenderManager::requestRender()
  {
    std::lock_guard lock(mMutex);
    mRenderRequested = true;
  }

  void RenderManager::setPaused(bool paused)
  {
    std::lock_guard lock(mMutex);
    mPaused = paused;
  }

  bool RenderManager::tick(uint64_t frameTimeInNanos)
  {
    std::lock_guard<std::mutex> lock(mMutex);

    // Render unconditionally on every worker rAF. The mRenderRequested flag
    // is kept in the API for symmetry with the native path but is not
    // gating on web: Dart's main-thread _tick and this worker's mainLoop
    // are independent 60Hz rAFs that aren't phase-locked. Gating on the flag
    // drops ~5-10 fps whenever the worker rAF fires before Dart has had a
    // chance to set it.
    (void)mRenderRequested;

    // Match pre-refactor RenderTicker semantics: render all swapchains
    // synchronously and ALWAYS call mEngine->execute() — even if every
    // beginFrame rejected or we're paused. Filament's WebGL backend queues
    // commands in an internal buffer that needs to be drained every rAF,
    // independent of whether a visible frame was produced. Skipping
    // execute() stalls the backend and causes a burst on resume.
    bool anyRendered = false;
    if (!mPaused) {
      updateAnimationsAndPlugins(frameTimeInNanos);

      for (size_t i = 0; i < mViewAttachments.size(); i++)
      {
        if (!mViewAttachments[i].swapChain) continue;
        if (renderSwapChainAt(i, frameTimeInNanos)) {
          anyRendered = true;
        }
      }
    }

#ifdef __EMSCRIPTEN__
    mEngine->execute();
#endif

    if (anyRendered) {
      mRenderRequested = false;
    }

    return anyRendered;
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