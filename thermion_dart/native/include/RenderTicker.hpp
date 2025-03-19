#pragma once

#include <chrono>
#include <mutex>
#include <vector>
#include <utility> // for std::pair

#include <filament/Renderer.h>
#include <filament/SwapChain.h>
#include <filament/View.h>
#include <filament/Viewport.h>

#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/Scene.h>
#include <filament/TransformManager.h>
#include <filament/VertexBuffer.h>

#include "scene/AnimationManager.hpp"

namespace thermion
{

    typedef std::chrono::time_point time_point_t;

    using namespace std::chrono;

    class RenderTicker
    {

    public:
        RenderTicker(filament::Renderer *renderer) : mRenderer(renderer) { }
        ~RenderTicker();
        
        void render(
            uint64_t frameTimeInNanos
        );
        void setRenderable(filament::SwapChain *swapChain, filament::View **view, uint8_t numViews);

        void addAnimationManager(AnimationManager* animationManager);
        void removeAnimationManager(AnimationManager* animationManager);


    private:
        std::mutex mMutex;
        filament::Renderer *mRenderer = nullptr;
        std::vector<AnimationManager*> mAnimationManagers;
        std::vector<std::pair<filament::SwapChain*, std::vector<filament::View*>>> mRenderable;
    };

}