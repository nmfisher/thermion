#if __APPLE__
#include "TargetConditionals.h"
#endif

#ifdef _WIN32
#pragma comment(lib, "Ws2_32.lib")
#endif

#include <filament/Camera.h>
#include <filament/SwapChain.h>
#include <backend/DriverEnums.h>
#include <backend/platforms/OpenGLPlatform.h>
#ifdef __EMSCRIPTEN__
#include <backend/platforms/PlatformWebGL.h>
#include <emscripten/emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>
#endif
#include <filament/Engine.h>

#include <filament/Options.h>
#include <filament/Renderer.h>
#include <filament/View.h>

#include <filament/RenderableManager.h>

#include <iostream>
#include <streambuf>
#include <sstream>
#include <istream>
#include <fstream>
#include <filesystem>
#include <mutex>
#include <iomanip>
#include <unordered_set>

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
  }

  void RenderTicker::render(uint64_t frameTimeInNanos)
  {
    std::lock_guard lock(mMutex);

    mSceneManager->update();

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


} // namespace thermion
