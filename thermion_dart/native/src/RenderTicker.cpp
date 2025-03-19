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

  void RenderTicker::setRenderable(SwapChain *swapChain, View **views, uint8_t numViews) {
    std::lock_guard lock(mMutex);

    // Find if this swapChain already exists in our collection
    auto it = std::find_if(mRenderable.begin(), mRenderable.end(),
      [swapChain](const auto& pair) { return pair.first == swapChain; });

    // Prepare the vector of views
    std::vector<View*> swapChainViews;
    for(int i = 0; i < numViews; i++) {
      swapChainViews.push_back(views[i]);
    }
    
    if (it != mRenderable.end()) {
      // Update existing entry
      it->second = swapChainViews;
    } else {
      // Add new entry
      mRenderable.emplace_back(swapChain, swapChainViews);
    }
  }

  void RenderTicker::render(uint64_t frameTimeInNanos)
  {
    std::lock_guard lock(mMutex);

    for (auto animationManager : mAnimationManagers) {
      animationManager->update(frameTimeInNanos * 1e-9);
    }

    for (const auto& [swapChain, views] : mRenderable)
    {
      if (!views.empty())
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