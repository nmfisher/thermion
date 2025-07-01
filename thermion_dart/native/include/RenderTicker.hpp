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
#include "components/OverlayComponentManager.hpp"

namespace thermion
{



    class RenderTicker
    {

        using ViewAttachment = std::pair<filament::SwapChain*, std::vector<filament::View*>>;

    public:
        RenderTicker(
            filament::Engine *engine,
            filament::Renderer *renderer) : mEngine(engine), mRenderer(renderer) { }
        ~RenderTicker();
        
        /// @brief 
        /// @param frameTimeInNanos 
        bool render(
            uint64_t frameTimeInNanos
        );
        
        /// @brief 
        /// @param swapChain 
        /// @param view 
        /// @param numViews 
        void setRenderable(filament::SwapChain *swapChain, filament::View **view, uint8_t numViews);

        /// @brief 
        /// @param animationManager 
        void addAnimationManager(AnimationManager* animationManager);
        
        /// @brief 
        /// @param animationManager 
        void removeAnimationManager(AnimationManager* animationManager);

        /// @brief 
        /// @param overlayComponentManager 
        void addOverlayManager(OverlayComponentManager *overlayComponentManager) {
            mOverlayComponentManager = overlayComponentManager;
        }

    private:
        std::mutex mMutex;
        filament::Engine *mEngine = std::nullptr_t();
        filament::Renderer *mRenderer = std::nullptr_t();
        std::vector<AnimationManager*> mAnimationManagers;
        OverlayComponentManager *mOverlayComponentManager = std::nullptr_t();
        std::vector<ViewAttachment> mRenderable;
        std::chrono::high_resolution_clock::time_point mLastRender;

    };

}