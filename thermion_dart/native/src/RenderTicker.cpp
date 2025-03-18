

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
#include <emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <filament/webgl/WebEngine.h>
#include <sys/types.h>
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

namespace thermion
{

  using namespace filament;
  using namespace filament::math;
  using namespace utils;
  using namespace std::chrono;

  using std::string;

  static constexpr filament::math::float4 sFullScreenTriangleVertices[3] = {
      {-1.0f, -1.0f, 1.0f, 1.0f},
      {3.0f, -1.0f, 1.0f, 1.0f},
      {-1.0f, 3.0f, 1.0f, 1.0f}};

  static const uint16_t sFullScreenTriangleIndices[3] = {0, 1, 2};

  void RenderTicker::setRenderable(SwapChain *swapChain, View **views, uint8_t numViews) {
  {

    std::lock_guard lock(mMutex);

    auto swapChainViews = mRenderable[swapChain];

    swapChainViews.clear();
    for(int i = 0; i < numViews; i++) {
      swapChainViews.push_back(views[i]);
    }
    
    mRenderable[swapChain] = swapChainViews;
    
      // Keep track of the swapchains, so we can iterate them in the render method.
    bool found = false;
    for (auto existingSwapChain : mSwapChains) {
        if (existingSwapChain == swapChain) {
            found = true;
            break;
        }
    }
    if (!found) {
        mSwapChains.push_back(swapChain);
    }
  }
}

  void RenderTicker::render(uint64_t frameTimeInNanos)
  {
    std::lock_guard lock(mMutex);

    // Update all animation managers
    for (auto animationManager : mAnimationManagers) {
        if (animationManager) {  // Check for nullptr just in case
            animationManager->update(frameTimeInNanos * 1e-9);
        }
    }


    for (auto swapChain : mSwapChains)
    {
      auto views = mRenderable[swapChain];
      if (views.size() > 0)
      {
        bool beginFrame = mRenderer->beginFrame(swapChain, frameTimeInNanos);
        if (beginFrame)
        {
          for (auto view : views)
          {
            mRenderer->render(view);
          }
        }
        mRenderer->endFrame();
      }
    }
#ifdef __EMSCRIPTEN__
    _engine->execute();
#endif
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