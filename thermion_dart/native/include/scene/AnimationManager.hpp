#pragma once

#include <memory>
#include <mutex>
#include <vector>

#include <filament/Engine.h>
#include <filament/Scene.h>

#include "c_api/APIBoundaryTypes.h"

#include "scene/AnimationComponentBase.hpp"
#include "scene/TickableAnimationSystem.hpp"
#include "scene/SceneAsset.hpp"

namespace thermion
{

    using namespace filament;
    using namespace utils;

    // Assets can be animated by:
    // 1) creating a buffer containing the weights for the asset's morph target(s)
    //    at successive frames; or
    // 2) creating a similar buffer containing the transforms for the asset's bones
    //    at successive frames.
    //
    // Both work on any SceneAsset / utils::Entity through the gltfio-free
    // SceneAsset skin interface, so they stay core code with no gltfio dependency.
    //
    // Embedded glTF clip playback is handled by an optional animation system
    // (GltfAnimationComponentManager, see TGltfAnimationManager.cpp) added via
    // addTickable() and ticked by update().
    //
    // AnimationManager maintains two component managers (one for each type of
    // runtime animation listed above). Calling update() with the number of
    // nanoseconds elapsed since the last call, calls the same on each component
    // manager and registered system, which will then update the asset's
    // animatable properties to match the target frame time.

    class MorphAnimationComponentManager;
    class BoneAnimationComponentManager;
    class AnimationManager
    {

        public:

        AnimationManager(Engine *engine);
        ~AnimationManager();

        ///
        /// @param frameTimeInNanos 
        void update(uint64_t frameTimeInNanos);

        /// Add an optional animation system (e.g. glTF clip playback) to be
        /// ticked by update(), before the core morph/bone managers. The
        /// caller keeps ownership and must call removeTickable() before
        /// destroying the system (the glTF animation manager does this on
        /// its own create/destroy). Adding the same system twice is a no-op.
        /// @param system
        void addTickable(TickableAnimationSystem *system);

        /// Stop ticking [system]. Does not destroy it; the caller owns it.
        /// Removing a system that was never added is a no-op.
        /// @param system
        void removeTickable(TickableAnimationSystem *system);

        /// The engine this manager was created with (used by optional
        /// animation systems to obtain Filament interfaces).
        Engine *getEngine() { return mEngine; }

        /// @param sceneAsset
        /// @param morphData
        /// @param morphIndices
        /// @param numMorphTargets
        /// @param numFrames
        /// @param frameLengthInMs
        /// @return
        bool setMorphAnimationBuffer(
            utils::Entity entity,
            const float *const morphData,
            const uint32_t *const morphIndices,
            int numMorphTargets,
            int numFrames,
            float frameLengthInMs);

        
        /// @param entityId
        void clearMorphAnimationBuffer(
            utils::Entity entity);

        
        /// @param asset
        /// @param skinIndex
        /// @param boneIndex
        /// @return
        math::mat4f getInverseBindMatrix(SceneAsset *asset, int skinIndex, int boneIndex);

        /// Immediately start animating the bone at [boneIndex] under the parent instance [entity] at skin [skinIndex].
        /// @param entity the mesh entity to animate
        /// @param frameData frame data as quaternions
        /// @param numFrames the number of frames
        /// @param boneName the name of the bone to animate
        /// @param frameLengthInMs the length of each frame in ms
        /// @return true if the bone animation was successfully enqueued
        bool addBoneAnimation(
            SceneAsset *asset,
            int skinIndex,
            int boneIndex,
            const float *const frameData,
            int numFrames,
            float frameLengthInMs,
            float fadeOutInSecs,
            float fadeInInSecs,
            float maxDelta,
            bool loop = false);

        
        /// @param asset
        /// @param skinIndex
        /// @return
        std::vector<math::mat4f> getBoneRestTranforms(SceneAsset *asset, int skinIndex);

        
        /// @param asset
        void resetToRestPose(SceneAsset *asset);

        
        /// @param asset
        void updateBoneMatrices(SceneAsset *asset);

        
        /// @param instance
        /// @param weights
        /// @param count
        void setMorphTargetWeights(utils::Entity entity, const float *const weights, int count);

        
        /// @param asset
        /// @return
        bool addBoneAnimationComponent(SceneAsset *asset);

        
        /// @param asset
        void removeBoneAnimationComponent(SceneAsset *asset);

        
        /// @param asset
        /// @return
        bool addMorphAnimationComponent(utils::Entity entity);

        
        /// @param asset
        void removeMorphAnimationComponent(utils::Entity entity);
            

    private:
        Engine *mEngine = nullptr;
        std::mutex mMutex;
        std::unique_ptr<MorphAnimationComponentManager> mMorphAnimationComponentManager;
        std::unique_ptr<BoneAnimationComponentManager> mBoneAnimationComponentManager;
        // Non-owning optional animation systems (e.g. glTF clip playback),
        // ticked before the core component managers so runtime morph/bone
        // animations apply on top of (and can blend with) the clip pose.
        // Owners add/remove them via addTickable/removeTickable.
        std::vector<TickableAnimationSystem *> mTickables;
        uint64_t mLastUpdateTime;
    };
}
