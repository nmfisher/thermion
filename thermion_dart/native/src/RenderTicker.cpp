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

#include "Log.hpp"

#include "RenderTicker.hpp"

#include <chrono> 

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

  void RenderTicker::render(uint64_t frameTimeInNanos)
  {
    auto startTime = std::chrono::high_resolution_clock::now();

    std::lock_guard lock(mMutex);

    for (auto animationManager : mAnimationManagers) {
      animationManager->update(frameTimeInNanos);
      TRACE("Updated AnimationManager");
    }
    
    #ifdef ENABLE_TRACING
    int numRendered = 0;
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
          for (auto view : views)
          {
            mRenderer->render(view);
          }
        } else {
          Log("Skipping frame");
        }
        mRenderer->endFrame();
    #ifdef ENABLE_TRACING
        numRendered++;
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
    auto durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    float durationMs = durationNs / 1e6f;

    TRACE("Total render() time: %.3f ms", durationMs);
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