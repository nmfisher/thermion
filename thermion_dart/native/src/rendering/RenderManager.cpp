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

    // Render each swapchain
    for (auto &attachment : mViewAttachments)
    {
      if (!attachment.swapChain)
      {
        Log("No swapchain, ignoring");
        continue;
      }

      bool beginFrame = mRenderer->beginFrame(attachment.swapChain, frameTimeInNanos);
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

        mLastRender = std::chrono::high_resolution_clock::now();
        mRenderer->endFrame();

        TRACE("%d views rendered for swapchain %d", numRendered, swapChainIndex);
        if (numRendered > 0) {
          rendered = true;
        }
      }
      else
      {
        durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
        TRACE("Skipping frame for swapchain %d (%.3f ms since last endFrame())", swapChainIndex, durationNs);
      }
      swapChainIndex++;
    }

    #ifdef __EMSCRIPTEN__
        mEngine->execute();
    #endif

    #ifdef __linux__
    // Flush Filament's backend command queue and wait for completion.
    // This ensures the FEngine backend thread is idle and all GPU commands
    // have been submitted before we return. Without this, calling Blit()
    // from another thread would race with the backend thread on the shared
    // VkQueue (Vulkan requires external synchronization of VkQueue access).
    if (rendered) {
      mEngine->flushAndWait();
    }
    #endif

    auto endTime = std::chrono::high_resolution_clock::now();
    durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    float durationMs = durationNs / 1e6f;

    TRACE("Total render() time for %d swapchains: %.3f ms", swapChainIndex, durationMs);
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