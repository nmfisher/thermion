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

    // Despite the name, RenderManager is responsible for coordinating 
    // the entire pipeline, not just rendering.
    // The process is as follows:
    // 1) updating animations
    // 2) instructing plugins to perform any updates before rendering
    // 3) render all views/swapchains  
    class RenderManager
    {

    public:
        static const uint8_t numViewAttachments = 8;

        RenderManager(Engine *engine, Renderer *renderer) : mEngine(engine), mRenderer(renderer), mLastRender(std::chrono::high_resolution_clock::now())
        {
        }
        ~RenderManager();

        /// Synchronously render every attached swapchain's views in one pass.
        /// Used by the native path, where Dart awaits a queued task that
        /// invokes this directly.
        bool render(
            uint64_t frameTimeInNanos);

        /// Flip the "render wanted" flag. Used on web — the actual work is
        /// driven from RenderThread::iter() on each rAF via tick().
        void requestRender();

        /// Web: pause/resume rendering. When paused, tick() skips animation
        /// updates and swapchain rendering but still drains the Filament
        /// backend command buffer (mEngine->execute()) so any state changes
        /// queued before pause complete cleanly and don't burst on resume.
        void setPaused(bool paused);

        /// Web path: called once per rAF from RenderThread::iter().
        /// Renders all attached swapchains synchronously (in practice there
        /// is only one on web — see ARCHITECTURE.md), then calls
        /// mEngine->execute() to drain the Filament WebGL backend command
        /// buffer. Returns true if any swapchain produced a visible frame.
        bool tick(uint64_t frameTimeInNanos);

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
            SwapChain *swapChain = nullptr;
            View *views[numViewAttachments];
        };

        // Factored out of render() so tick() can invoke them piecewise.
        // Both assume mMutex is held by the caller.
        void updateAnimationsAndPlugins(uint64_t frameTimeInNanos);
        bool renderSwapChainAt(size_t index, uint64_t frameTimeInNanos);

        std::mutex mMutex;
        Engine *mEngine = nullptr;
        Renderer *mRenderer = nullptr;
        std::vector<AnimationManager *> mAnimationManagers;
        std::vector<ViewAttachment> mViewAttachments;
        std::chrono::high_resolution_clock::time_point mLastRender;

        // Web: tick() checks this flag and renders if set, then clears it.
        // Set by Dart via RenderManager_requestRender() on each main-thread
        // rAF. Rejection retries (beginFrame failing) keep the flag set so
        // RenderThread's 12ms iter-loop can retry in the same rAF.
        bool mRenderRequested = false;

        // Web: when true, tick() short-circuits animations + swapchain render.
        // mEngine->execute() still runs so the backend command buffer keeps
        // draining (matches native "scheduler keeps ticking" pause semantics).
        // Note: this gates *rendering only* — task queue drain in
        // RenderThread::iter() is outside this flag, so FFI state changes
        // (setTransform, addEntity, etc.) continue to apply while paused.
        bool mRenderPaused = false;
    };

}