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

#include "Log.hpp"
#include "RenderTicker.hpp"

namespace thermion
{

  using namespace filament;
  using namespace filament::math;
  using namespace utils;

  using std::string;

  void RenderTicker::setRenderable(SwapChain *swapChain, View **views, uint8_t numViews) {
    std::lock_guard lock(mMutex);

    auto it = std::find_if(mRenderable.begin(), mRenderable.end(),
      [swapChain](const auto& pair) { return pair.first == swapChain; });

    std::vector<View*> swapChainViews;
    for(int i = 0; i < numViews; i++) {
      swapChainViews.push_back(views[i]);
    }
    
    if (it != mRenderable.end()) {
      it->second = swapChainViews;
    } else {
      mRenderable.emplace_back(swapChain, swapChainViews);
    }
    TRACE("Set %d views as renderable", numViews);
  }

  bool RenderTicker::render(uint64_t frameTimeInNanos)
  {
    auto startTime = std::chrono::high_resolution_clock::now();
    
    std::lock_guard lock(mMutex);

    for (auto animationManager : mAnimationManagers) {
      animationManager->update(frameTimeInNanos);
    }

    auto durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
    TRACE("Updated animations in %.3f ms", durationNs);
    
    int numRendered = 0;
    
    #ifdef ENABLE_TRACING
    TRACE("%d swapchains", mRenderable.size());
    #endif
    
    for (const auto& [swapChain, views] : mRenderable)
    {
      if (!views.empty())
      {
        TRACE("Rendering %d views", views.size());

        bool beginFrame = mRenderer->beginFrame(swapChain, frameTimeInNanos);
        if (beginFrame)
        {
          numRendered++;        
          durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
          TRACE("Beginning frame (%.3f ms since last endFrame())", durationNs);
          for (auto view : views)
          {
            mRenderer->render(view);
          }
          mLastRender = std::chrono::high_resolution_clock::now();          
          mRenderer->endFrame();
        } else {
          durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
          TRACE("Skipping frame (%.3f ms since last endFrame())", durationNs);
        }

    #ifdef ENABLE_TRACING
      } else {
        TRACE("No views for swapchain");
      }
      TRACE("%d swapchains rendered", numRendered);
    #else
    }
      #endif
    }
    #ifdef __EMSCRIPTEN__
    mEngine->execute();
    #endif
    auto endTime = std::chrono::high_resolution_clock::now();
    durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    float durationMs = durationNs / 1e6f;

    TRACE("Total render() time: %.3f ms", durationMs);
    return numRendered > 0;
  }

  void RenderTicker::addAnimationManager(AnimationManager* animationManager) {
    std::lock_guard<std::mutex> lock(mMutex);
    mAnimationManagers.push_back(animationManager);
  }

  void RenderTicker::removeAnimationManager(AnimationManager* animationManager) {
    std::lock_guard<std::mutex> lock(mMutex);
    auto it = std::find(mAnimationManagers.begin(), mAnimationManagers.end(), animationManager);
    if (it != mAnimationManagers.end()) {
      mAnimationManagers.erase(it);
    }
  }

  RenderTicker::~RenderTicker() {}

} // namespace thermion