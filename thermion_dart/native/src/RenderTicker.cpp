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
#include "RenderTicker.hpp"

namespace thermion
{

  using namespace filament;
  using namespace filament::math;
  using namespace utils;

  using std::string;

  void RenderTicker::removeSwapChain(SwapChain *swapChain)
  {
    std::lock_guard lock(mMutex);
    auto erased = std::remove_if(mRenderable.begin(),
                                 mRenderable.end(),
                                 [=](ViewAttachment attachment)
                                 { return attachment.first == swapChain; });
    mRenderable.erase(erased,
                      mRenderable.end());
  }

  void RenderTicker::setRenderable(SwapChain *swapChain, View **views, uint8_t numViews)
  {
    std::lock_guard lock(mMutex);

    auto it = std::find_if(mRenderable.begin(), mRenderable.end(),
                           [swapChain](const auto &pair)
                           { return pair.first == swapChain; });

    std::vector<View *> swapChainViews;
    for (int i = 0; i < numViews; i++)
    {
      swapChainViews.push_back(views[i]);
    }

    if (it != mRenderable.end())
    {
      it->second = swapChainViews;
    }
    else
    {
      mRenderable.emplace_back(swapChain, swapChainViews);
    }
    TRACE("Set %d views as renderable", numViews);
  }

  bool RenderTicker::render(uint64_t frameTimeInNanos)
  {
    auto startTime = std::chrono::high_resolution_clock::now();

    std::lock_guard lock(mMutex);

    for (auto animationManager : mAnimationManagers)
    {
      animationManager->update(frameTimeInNanos);
    }

    auto durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now() - mLastRender).count() / 1e6f;
    TRACE("Updated animations in %.3f ms", durationNs);

    int swapChainIndex = 0;
    bool rendered = false;

    for (const auto &[swapChain, views] : mRenderable)
    {

      int numRendered = 0;

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

        if (mOverlayComponentManager)
        {
          mOverlayComponentManager->update();
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
    }
#ifdef __EMSCRIPTEN__
    mEngine->execute();
#endif
    auto endTime = std::chrono::high_resolution_clock::now();
    durationNs = std::chrono::duration_cast<std::chrono::nanoseconds>(endTime - startTime).count();
    float durationMs = durationNs / 1e6f;

    TRACE("Total render() time: %.3f ms", durationMs);
    return rendered;
  }

  void RenderTicker::addAnimationManager(AnimationManager *animationManager)
  {
    std::lock_guard<std::mutex> lock(mMutex);
    mAnimationManagers.push_back(animationManager);
  }

  void RenderTicker::removeAnimationManager(AnimationManager *animationManager)
  {
    std::lock_guard<std::mutex> lock(mMutex);
    auto it = std::find(mAnimationManagers.begin(), mAnimationManagers.end(), animationManager);
    if (it != mAnimationManagers.end())
    {
      mAnimationManagers.erase(it);
    }
  }

  RenderTicker::~RenderTicker() {}

} // namespace thermion