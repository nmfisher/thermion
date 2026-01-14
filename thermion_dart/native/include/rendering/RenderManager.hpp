#pragma once

#include <chrono>
#include <mutex>
#include <vector>
#include <utility>

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
#include "PluginAPI.hpp"

namespace thermion
{

    using namespace filament;

    // A RenderManager coordinates the whole rendering pipeline:
    // 1) updating animations
    // 2) instructing plugins to perform any updates before rendering
    // 3) rendering all views/swapchains
    //   
    class RenderManager
    {

    public:
        static const uint8_t numViewAttachments = 8;

        RenderManager(Engine *engine, Renderer *renderer) : mEngine(engine), mRenderer(renderer)
        {
        }
        ~RenderManager();

        /// @brief
        /// @param frameTimeInNanos
        bool render(
            uint64_t frameTimeInNanos);

        /// @brief
        /// @param swapChain
        /// @param view
        /// @param numViews
        void setRenderable(SwapChain *swapChain, View **view, uint8_t numViews);

        /// @brief
        /// @param swapChain
        /// @param view
        /// @param numViews
        void removeSwapChain(SwapChain *swapChain);

        /// @brief
        /// @param animationManager
        void addAnimationManager(AnimationManager *animationManager);

        /// @brief
        /// @param animationManager
        void removeAnimationManager(AnimationManager *animationManager);

    private:
        struct ViewAttachment
        {
            SwapChain *swapChain;
            View *views[numViewAttachments];
        };

        std::mutex mMutex;
        Engine *mEngine = std::nullptr_t();
        Renderer *mRenderer = std::nullptr_t();
        std::vector<AnimationManager *> mAnimationManagers;
        ViewAttachment mViewAttachment;
        std::chrono::high_resolution_clock::time_point mLastRender;
    };

}