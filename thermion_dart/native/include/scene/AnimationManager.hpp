#pragma once

#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
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
    // (GltfAnimationComponentManager, see TGltfAnimation.cpp) registered via
    // registerAnimationSystem() and ticked by update().
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

        /// Register an optional animation system (e.g. glTF clip playback) to
        /// be ticked by update(). The AnimationManager takes ownership and
        /// destroys the system on unregister/destruction. Registering a name
        /// that is already registered is a no-op.
        /// @param name identifier used by findAnimationSystem (e.g. "gltf")
        /// @param system
        void registerAnimationSystem(const std::string &name, TickableAnimationSystem *system);

        /// @param name
        void unregisterAnimationSystem(const std::string &name);

        /// Returns the registered system for [name], or nullptr.
        /// @param name
        TickableAnimationSystem *findAnimationSystem(const std::string &name);

        /// Locks the manager's mutex for callers that must hold it across a
        /// system lookup plus operations on the returned system (e.g. glTF
        /// clip playback in TGltfAnimation.cpp). update() holds the same
        /// mutex while ticking, so this serializes direct FFI calls against
        /// the frame tick (RenderManager::tick does not take the engine API
        /// lock on web worker builds). While holding this lock, only the
        /// *Locked methods below may be called on this manager; the public
        /// methods take the same non-recursive mutex themselves.
        std::unique_lock<std::mutex> lock() { return std::unique_lock<std::mutex>(mMutex); }

        /// Like findAnimationSystem, but the caller must hold lock().
        TickableAnimationSystem *findAnimationSystemLocked(const std::string &name);

        /// Returns the registered system for [name], creating and registering
        /// it via [factory] on first use. Lookup and registration happen
        /// under one hold of the manager mutex, so two concurrent callers can
        /// never both create a system (the duplicate-name branch of
        /// registerAnimationSystem would delete the loser's system while the
        /// caller still used the pointer). The caller must hold lock(); the
        /// factory runs under the mutex and must not call back into this
        /// manager's public methods.
        TickableAnimationSystem *getOrCreateAnimationSystemLocked(
            const std::string &name,
            const std::function<TickableAnimationSystem *()> &factory);

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
        // Owned optional animation systems (e.g. glTF clip playback),
        // ticked before the core component managers so runtime morph/bone
        // animations apply on top of (and can blend with) the clip pose.
        std::vector<std::pair<std::string, std::unique_ptr<TickableAnimationSystem>>> mAnimationSystems;
        uint64_t mLastUpdateTime;
    };
}
