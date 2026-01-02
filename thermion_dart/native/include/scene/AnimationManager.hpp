#pragma once

#include <mutex>
#include <vector>

#include <filament/Engine.h>
#include <filament/Scene.h>

#include "c_api/APIBoundaryTypes.h"

#include "scene/GltfSceneAssetInstance.hpp"
#include "scene/GltfSceneAsset.hpp"
#include "scene/SceneAsset.hpp"

namespace thermion
{

    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;

    // Assets can be animated by:
    // 1) playing an embedded gltf animation 
    // 2) creating a buffer containing the weights for the asset's morph target(s) 
    //    at successive frames; or
    // 3) creating a similar buffer containing the transforms for the asset's bones 
    //    at successive frames;
    //
    // (note that embedded gltf animations may target the asset's morph target weights or 
    // bone transforms; these are still handled separately from manually-created animations).
    //
    // AnimationManager maintains three component managers (one for each type of animation listed 
    // above). Calling update() with the number of nanoseconds elapsed since the last call, 
    // calls the same on each component manager, which will then update the asset's animatable properties 
    // to match the target frame time.
    
    class GltfAnimationComponentManager;
    class MorphAnimationComponentManager;
    class BoneAnimationComponentManager;
    class AnimationManager
    {
        
        public:
        
        // The base struct shared by all three animation types.
        // 
        struct AnimationComponentBase
        {
            // The frame time (in nanoseconds) when this animation started playing.
            uint64_t startTimeInNanos = 0;
            
            // Whether the animation should be played from its first frame, or at some later time.
            float startOffset;
            
            // Whether the animation should loop back to the start when it finishes.
            bool loop = false;
            
            // Whether the animation should be played backwards or forwards.
            bool reverse = false;
            
            // The duration of the animation in seconds.
            float durationInSecs = 0;
            
            // The speed at which this animation should be played.
            float speed = 1.0f;
        };
        AnimationManager(Engine *engine);
        ~AnimationManager();

        ///
        /// @param frameTimeInNanos 
        void update(uint64_t frameTimeInNanos);

        
        /// @param asset
        /// @param childEntity
        /// @return
        std::vector<std::string> getMorphTargetNames(GltfSceneAsset *asset, EntityId childEntity);

        
        /// @param instance
        /// @param skinIndex
        /// @return
        std::vector<Entity> getBoneEntities(GltfSceneAssetInstance *instance, int skinIndex);

        
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

        
        /// @param instance
        /// @param skinIndex
        /// @param boneIndex
        /// @return
        math::mat4f getInverseBindMatrix(GltfSceneAssetInstance *instance, int skinIndex, int boneIndex);

        /// Set the local transform for the bone at boneIndex/skinIndex in the given entity.
        /// @param entityId the parent entity
        /// @param entityName the name of the mesh under entityId for which the bone will be set.
        /// @param skinIndex the index of the joint skin. Currently only 0 is supported.
        /// @param boneName the name of the bone
        /// @param transform the 4x4 matrix representing the local transform for the bone
        /// @return true if the transform was successfully set, false otherwise
        bool setBoneTransform(GltfSceneAssetInstance *instance, int skinIndex, int boneIndex, math::mat4f transform);

        /// Immediately start animating the bone at [boneIndex] under the parent instance [entity] at skin [skinIndex].
        /// @param entity the mesh entity to animate
        /// @param frameData frame data as quaternions
        /// @param numFrames the number of frames
        /// @param boneName the name of the bone to animate
        /// @param frameLengthInMs the length of each frame in ms
        /// @return true if the bone animation was successfully enqueued
        bool addBoneAnimation(
            GltfSceneAssetInstance *instance,
            int skinIndex,
            int boneIndex,
            const float *const frameData,
            int numFrames,
            float frameLengthInMs,
            float fadeOutInSecs,
            float fadeInInSecs,
            float maxDelta);

        
        /// @param instance
        /// @param skinIndex
        /// @return
        std::vector<math::mat4f> getBoneRestTranforms(GltfSceneAssetInstance *instance, int skinIndex);

        
        /// @param instance
        void resetToRestPose(GltfSceneAssetInstance *instance);

        
        /// @param instance
        void updateBoneMatrices(GltfSceneAssetInstance *instance);

        
        /// @param instance
        /// @param animationIndex
        /// @param loop
        /// @param reverse
        /// @param replaceActive
        /// @param crossfade
        /// @param startOffset
        /// @param speed
        void playGltfAnimation(GltfSceneAssetInstance *instance, int animationIndex, bool loop, bool reverse, bool replaceActive, float crossfade = 0.3f, float startOffset = 0.0f, float speed = 1.0f);

        
        /// @param instance
        /// @param animationIndex
        void stopGltfAnimation(GltfSceneAssetInstance *instance, int animationIndex);

        
        /// @param instance
        /// @param weights
        /// @param count
        void setMorphTargetWeights(utils::Entity entity, const float *const weights, int count);

        
        /// @param instance
        /// @param animationIndex
        /// @param animationFrame
        void setGltfAnimationFrame(GltfSceneAssetInstance *instance, int animationIndex, int animationFrame);

        
        /// @param instance
        /// @return
        std::vector<std::string> getGltfAnimationNames(GltfSceneAssetInstance *instance);

        
        /// @param instance
        /// @param animationIndex
        /// @return
        float getGltfAnimationDuration(GltfSceneAssetInstance *instance, int animationIndex);

        
        /// @param instance
        /// @return
        bool addGltfAnimationComponent(GltfSceneAssetInstance *instance);

        
        /// @param instance
        void removeGltfAnimationComponent(GltfSceneAssetInstance *instance);

        
        /// @param instance
        /// @return
        bool addBoneAnimationComponent(GltfSceneAssetInstance *instance);

        
        /// @param instance
        void removeBoneAnimationComponent(GltfSceneAssetInstance *instance);

        
        /// @param asset
        /// @return
        bool addMorphAnimationComponent(utils::Entity entity);

        
        /// @param asset
        void removeMorphAnimationComponent(utils::Entity entity);

        /// Get the parent bone index for a given bone, or -1 if the bone is a root bone.
        /// @param instance the glTF asset instance
        /// @param skinIndex the skin index
        /// @param boneIndex the bone index
        /// @return the parent bone index, or -1 if root
        int getBoneParent(GltfSceneAssetInstance *instance, int skinIndex, int boneIndex);


    private:
        Engine *mEngine = nullptr;
        std::mutex mMutex;
        std::unique_ptr<GltfAnimationComponentManager> mGltfAnimationComponentManager = std::nullptr_t();
        std::unique_ptr<MorphAnimationComponentManager> mMorphAnimationComponentManager = std::nullptr_t();
        std::unique_ptr<BoneAnimationComponentManager> mBoneAnimationComponentManager = std::nullptr_t();
        uint64_t mLastUpdateTime;
    };
}
