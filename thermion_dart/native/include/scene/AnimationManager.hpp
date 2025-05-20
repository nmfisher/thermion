#pragma once

#include <mutex>
#include <vector>

#include <filament/Engine.h>
#include <filament/Scene.h>

#include "c_api/APIBoundaryTypes.h"

#include "components/CollisionComponentManager.hpp"
#include "components/GltfAnimationComponentManager.hpp"
#include "components/MorphAnimationComponentManager.hpp"
#include "components/BoneAnimationComponentManager.hpp"
#include "scene/GltfSceneAssetInstance.hpp"
#include "scene/GltfSceneAsset.hpp"
#include "scene/SceneAsset.hpp"

namespace thermion
{

    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using std::string;
    using std::unique_ptr;
    using std::vector;

    /// @brief
    class AnimationManager
    {
    public:
        AnimationManager(
            Engine *engine,
            Scene *scene);
        ~AnimationManager() = default;

        /// @brief 
        ///
        /// @param frameTimeInNanos 
        void update(uint64_t frameTimeInNanos);

        /// @brief
        /// @param asset
        /// @param childEntity
        /// @return
        vector<string> getMorphTargetNames(GltfSceneAsset *asset, EntityId childEntity);

        /// @brief
        /// @param instance
        /// @param skinIndex
        /// @return
        vector<Entity> getBoneEntities(GltfSceneAssetInstance *instance, int skinIndex);

        /// @brief
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

        /// @brief
        /// @param entityId
        void clearMorphAnimationBuffer(
            utils::Entity entity);

        /// @brief
        /// @param instance
        /// @param skinIndex
        /// @param boneIndex
        /// @return
        math::mat4f getInverseBindMatrix(GltfSceneAssetInstance *instance, int skinIndex, int boneIndex);

        /// @brief Set the local transform for the bone at boneIndex/skinIndex in the given entity.
        /// @param entityId the parent entity
        /// @param entityName the name of the mesh under entityId for which the bone will be set.
        /// @param skinIndex the index of the joint skin. Currently only 0 is supported.
        /// @param boneName the name of the bone
        /// @param transform the 4x4 matrix representing the local transform for the bone
        /// @return true if the transform was successfully set, false otherwise
        bool setBoneTransform(GltfSceneAssetInstance *instance, int skinIndex, int boneIndex, math::mat4f transform);

        /// @brief Immediately start animating the bone at [boneIndex] under the parent instance [entity] at skin [skinIndex].
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

        /// @brief
        /// @param instance
        /// @param skinIndex
        /// @return
        std::vector<math::mat4f> getBoneRestTranforms(GltfSceneAssetInstance *instance, int skinIndex);

        /// @brief
        /// @param instance
        void resetToRestPose(GltfSceneAssetInstance *instance);

        /// @brief
        /// @param instance
        void updateBoneMatrices(GltfSceneAssetInstance *instance);

        /// @brief
        /// @param instance
        /// @param animationIndex
        /// @param loop
        /// @param reverse
        /// @param replaceActive
        /// @param crossfade
        /// @param startOffset
        void playGltfAnimation(GltfSceneAssetInstance *instance, int animationIndex, bool loop, bool reverse, bool replaceActive, float crossfade = 0.3f, float startOffset = 0.0f);

        /// @brief
        /// @param instance
        /// @param animationIndex
        void stopGltfAnimation(GltfSceneAssetInstance *instance, int animationIndex);

        /// @brief
        /// @param instance
        /// @param weights
        /// @param count
        void setMorphTargetWeights(utils::Entity entity, const float *const weights, int count);

        /// @brief
        /// @param instance
        /// @param animationIndex
        /// @param animationFrame
        void setGltfAnimationFrame(GltfSceneAssetInstance *instance, int animationIndex, int animationFrame);

        /// @brief
        /// @param instance
        /// @return
        vector<string> getGltfAnimationNames(GltfSceneAssetInstance *instance);

        /// @brief
        /// @param instance
        /// @param animationIndex
        /// @return
        float getGltfAnimationDuration(GltfSceneAssetInstance *instance, int animationIndex);

        /// @brief
        /// @param instance
        /// @return
        bool addGltfAnimationComponent(GltfSceneAssetInstance *instance);

        /// @brief
        /// @param instance
        void removeGltfAnimationComponent(GltfSceneAssetInstance *instance);

        /// @brief
        /// @param instance
        /// @return
        bool addBoneAnimationComponent(GltfSceneAssetInstance *instance);

        /// @brief
        /// @param instance
        void removeBoneAnimationComponent(GltfSceneAssetInstance *instance);

        /// @brief
        /// @param asset
        /// @return
        bool addMorphAnimationComponent(utils::Entity entity);

        /// @brief
        /// @param asset
        void removeMorphAnimationComponent(utils::Entity entity);
            

    private:
        Engine *_engine = nullptr;
        Scene *_scene = nullptr;
        std::mutex _mutex;
        std::unique_ptr<GltfAnimationComponentManager> _gltfAnimationComponentManager = std::nullptr_t();
        std::unique_ptr<MorphAnimationComponentManager> _morphAnimationComponentManager = std::nullptr_t();
        std::unique_ptr<BoneAnimationComponentManager> _boneAnimationComponentManager = std::nullptr_t();
    };
}
