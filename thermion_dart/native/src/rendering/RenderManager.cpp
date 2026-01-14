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

#include <chrono>
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
      for (int i = 0; i < numViewAttachments; i++)
    {
        mViewAttachment.views[i] = nullptr;
    }
    mViewAttachment.swapChain = nullptr;
  }

  void RenderManager::setRenderable(SwapChain *swapChain, View **views, uint8_t numViews)
  {
    std::lock_guard lock(mMutex);

    mViewAttachment.swapChain = swapChain;
    
    for (int i = 0; i < numViewAttachments; i++)
    {
      if(i < numViews) {
        mViewAttachment.views[i] = views[i];
      } else {
        mViewAttachment.views[i] = nullptr;
      }
    }
    TRACE("Set %d view attachments", numViews);
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

    int swapChainIndex = 0;
    bool rendered = false;
    
    int numRendered = 0;

    if(!mViewAttachment.swapChain) {
      return false;
    }
    bool beginFrame = mRenderer->beginFrame(mViewAttachment.swapChain, frameTimeInNanos);
    if (beginFrame)
    {

      durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;

      TRACE("Beginning frame (%.3f ms since last endFrame())", durationNs);
      for (int i = 0; i < numViewAttachments; i++)
      {
        if(!mViewAttachment.views[i]) {
          break;
        }
        numRendered++;
        mRenderer->render(mViewAttachment.views[i]);
      }

      mLastRender = std::chrono::high_resolution_clock::now();
      mRenderer->endFrame();
    }
    else
    {
      durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
      TRACE("Skipping frame (%.3f ms since last endFrame())", durationNs);
    }
    TRACE("%d views rendered for swapchain %d", numRendered, swapChainIndex);
    swapChainIndex++;
    if (numRendered > 0)
    {
      rendered = true;
    }
    
#ifdef __EMSCRIPTEN__
    mEngine->execute();
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