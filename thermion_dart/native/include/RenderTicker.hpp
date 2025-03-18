#pragma once

#include <filament/Engine.h>
#include <filament/Renderer.h>
#include <filament/View.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <fstream>
#include <iostream>
#include <string>
#include <chrono>

#include "scene/SceneManager.hpp"

namespace thermion
{

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;

    using namespace std::chrono;

    class RenderTicker
    {

    public:
        RenderTicker(filament::Renderer renderer, thermion::SceneManager sceneManager) : mRenderer(renderer), mSceneManager(sceneManager) { }
        ~RenderTicker();
        
        void render(
            uint64_t frameTimeInNanos
        );
        void setRenderable(SwapChain *swapChain, View **view, uint8_t numViews);

    private:
        std::mutex mMutex;
        Renderer *mRenderer = nullptr;
        SceneManager *mSceneManager = nullptr;
        std::vector<SwapChain*> mSwapChains;
        std::map<SwapChain*, std::vector<View*>> mRenderable;

    };


}
