#pragma once

#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <vector>
#include <utility>

#include <filament/RenderTarget.h>
#include <filament/Renderer.h>
#include <filament/SwapChain.h>
#include <filament/Texture.h>
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
#include "rendering/FrameRateGate.hpp"

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
        struct CaptureViewRequest
        {
            View *view = nullptr;
            RenderTarget *renderTarget = nullptr;
            uint32_t width = 0;
            uint32_t height = 0;
            backend::PixelDataFormat format = backend::PixelDataFormat::RGBA;
            backend::PixelDataType type = backend::PixelDataType::UBYTE;
        };

        struct CaptureResult
        {
            std::vector<std::vector<uint8_t>> buffers;
        };

        struct CapturePumpState
        {
            std::atomic<bool> alive{true};
            std::atomic<uint32_t> pendingReadbacks{0};
        };
        RenderManager(Engine *engine, Renderer *renderer) : mEngine(engine), mRenderer(renderer), mLastRender(std::chrono::high_resolution_clock::now())
        {
        }
        ~RenderManager();

        /// Synchronously render every attached swapchain's views in one pass.
        /// Used by the native path, where Dart awaits a queued task that
        /// invokes this directly.
        bool render(
            uint64_t frameTimeInNanos);

        /// Atomically run beginFrame -> render -> readPixels -> endFrame on the
        /// provided swapchain while holding mMutex. Returns false without invoking
        /// onComplete if validation or beginFrame fails. When true is returned,
        /// native owns the readback buffers until Filament completes all callbacks
        /// and then invokes onComplete with the resulting CaptureResult.
        bool capture(
            SwapChain *swapChain,
            uint64_t frameTimeInNanos,
            bool render,
            const std::vector<CaptureViewRequest> &views,
            std::function<void(std::unique_ptr<CaptureResult>)> onComplete);

        /// Web: pause/resume rendering. When paused, tick() skips animation
        /// updates and swapchain rendering but still drains the Filament
        /// backend command buffer (mEngine->execute()) so any state changes
        /// queued before pause complete cleanly and don't burst on resume.
        /// Takes effect on a subsequent tick; does not wait for an in-flight
        /// frame or its callbacks to finish.
        void setPaused(bool paused);

        /// Limit web drawing independently for each engine; zero is unlimited.
        void setTargetFps(int fps);

        /// Main-thread mode: submit commands and deliver upload releases
        /// without drawing an intermediate frame.
        void flushCommands();

        /// Registers [materialInstance] to temporarily override every
        /// non-skybox renderable primitive in [view]'s scene while [view]
        /// renders, restoring original materials immediately afterward.
        /// Pass nullptr to clear any registered override for [view].
        void setMaterialOverride(View *view, MaterialInstance *materialInstance);

        /// Renders [view] using this manager's renderer, applying any
        /// material override registered for [view].
        void renderView(View *view, bool standalone = false);

#ifdef __EMSCRIPTEN__
        // Called on the engine's thread when the manager is attached/detached.
        // Main-thread web mode renders explicitly and does not start a loop.
        void startFrameLoop();
        void stopFrameLoop();
#endif

        /// Web worker mode: called by this manager's browser animation callback.
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
#ifdef __EMSCRIPTEN__
        static void onCapturePump(void *manager);
        void runCapturePump();
        void scheduleCapturePump(double delayMs);
        void stopCapturePump();
        // Accessed only on the engine's thread.
        long mCapturePumpTimer = -1;
#endif
#if defined(__EMSCRIPTEN__) && !defined(THERMION_WEB_MAIN_THREAD)
        static bool onAnimationFrame(double timestamp, void* manager);
        static void onFrameTimeout(void* manager);
        void requestNextFrame();
        // Accessed only on the engine's thread. Destruction cancels this request.
        int mAnimationFrameRequest = -1;
        bool mFrameLoopRunning = false;
        bool mFrameLoopUsesTimeout = false;
        double mNextFrameTimeMs = 0;
#endif
        std::shared_ptr<CapturePumpState> mCapturePumpState = std::make_shared<CapturePumpState>();
        std::atomic<int> mTargetFps{0};
        // Only tick() accesses the FPS gate. Pause requests set this flag.
        std::atomic<bool> mResetFrameRateGate{false};
        FrameRateGate mFrameRateGate;
        struct ViewSlot
        {
            View *view = nullptr;
            MaterialInstance *materialOverride = nullptr;
        };

        struct ViewAttachment
        {
            SwapChain *swapChain = nullptr;
            std::vector<ViewSlot> views;
        };

        struct SavedMaterial
        {
            RenderableManager::Instance instance;
            size_t primitiveIndex;
            MaterialInstance *original;
        };

        // Factored out of render() so tick() can invoke them piecewise.
        // All assume mMutex is held by the caller.
        void updateAnimationsAndPlugins(uint64_t frameTimeInNanos);
        bool renderSwapChainAt(size_t index, uint64_t frameTimeInNanos);
        MaterialInstance *findMaterialOverrideLocked(const View *view) const;
        void renderViewWithMaterialOverrideLocked(View *view, MaterialInstance *materialOverride, bool standalone);

        std::mutex mMutex;
        Engine *mEngine = nullptr;
        Renderer *mRenderer = nullptr;
        std::vector<AnimationManager *> mAnimationManagers;
        std::vector<ViewAttachment> mViewAttachments;
        std::vector<std::pair<View *, MaterialInstance *>> mMaterialOverrides;
        std::vector<SavedMaterial> mSavedMaterials;
        std::chrono::high_resolution_clock::time_point mLastRender;

        // Web: when true, tick() short-circuits animations + swapchain render.
        // mEngine->execute() still runs so the backend command buffer keeps
        // draining (matches native "scheduler keeps ticking" pause semantics).
        // This gates rendering only. The command queue keeps draining, so
        // FFI state changes
        // (setTransform, addEntity, etc.) continue to apply while paused.
        // Main-thread controls must not take mMutex: tick() can hold it while
        // a Filament upload callback waits for that same main thread.
        std::atomic<bool> mRenderPaused{false};
    };

}
