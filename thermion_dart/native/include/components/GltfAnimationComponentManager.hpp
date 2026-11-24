#pragma once

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <filament/TransformManager.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <gltfio/Animator.h>
#include <gltfio/math.h>

#include <utils/SingleInstanceComponentManager.h>

#include <mutex>

#include "Log.hpp"
#include "scene/GltfSceneAssetInstance.hpp"
#include "scene/AnimationComponentBase.hpp"
#include "scene/TickableAnimationSystem.hpp"

template class std::vector<float>;
namespace thermion
{
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using namespace std::chrono;

    /// @brief
    /// The status of an animation embedded in a glTF object.
    /// @param index refers to the index of the animation in the animations property of the underlying object.
    ///
    struct GltfAnimation : AnimationComponentBase
    {
        int8_t index = -1;
    };


    /// @brief 
    ///
    ///
    struct GltfAnimationComponent
    {
        filament::gltfio::FilamentInstance * target;
        // the index of the last active glTF animation,
        // used to cross-fade
        GltfAnimation fadeOutAnimation;
        
        // the time (in seconds) to fade out the last animation
        float fadeOutDuration = 0.0f;

        std::vector<GltfAnimation> animations;
    };

    class GltfAnimationComponentManager : public utils::SingleInstanceComponentManager<GltfAnimationComponent>,
                                          public TickableAnimationSystem {
        public:
            GltfAnimationComponentManager(
                utils::EntityManager &em,
                filament::TransformManager &transformManager,
                filament::RenderableManager &renderableManager) :
                    utils::SingleInstanceComponentManager<GltfAnimationComponent>(em, "GltfAnimationComponentManager"),
                    mTransformManager(transformManager), mRenderableManager(renderableManager) {};
            ~GltfAnimationComponentManager() = default;
            // All public methods take mMutex internally, so direct FFI calls
            // serialize against the frame tick (update()) without relying on
            // the AnimationManager's mutex or the engine API lock (which
            // compiles to nothing on web worker builds).
            void addAnimationComponent(FilamentInstance *target);
            void removeAnimationComponent(FilamentInstance *target);

            bool addGltfAnimation(FilamentInstance *target, int index, bool loop, bool reverse, bool replaceActive, float crossfade, float startOffset, float speed = 1.0f);
            void removeGltfAnimation(FilamentInstance *target, int index);
            void setGltfAnimationTime(FilamentInstance *target, int animationIndex, float timeInSeconds);
            float getGltfAnimationDuration(FilamentInstance *target, int animationIndex);
            void update(uint64_t frameTimeInNanos) override;

        private:
            std::mutex mMutex;
            filament::TransformManager &mTransformManager;
            filament::RenderableManager &mRenderableManager;
            uint64_t mLastUpdateTime;

    };
}
