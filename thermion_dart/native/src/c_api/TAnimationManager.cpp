#include "Log.hpp"

#include "c_api/APIExport.h"
#include "scene/AnimationManager.hpp"

using namespace thermion;

extern "C"
{

#include "c_api/TAnimationManager.h"

    EMSCRIPTEN_KEEPALIVE void AnimationManager_addAnimationComponent(TAnimationManager *tAnimationManager, EntityId entityId)
    {
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->addAnimationComponent(entityId);
    }
    EMSCRIPTEN_KEEPALIVE void AnimationManager_removeAnimationComponent(TAnimationManager *tAnimationManager, EntityId entityId)
    {
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->removeAnimationComponent(entityId);
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_setMorphAnimation(
        TAnimationManager *tAnimationManager,
        EntityId entityId,
        const float *const morphData,
        const uint32_t *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {
        auto entity = utils::Entity::import(entityId);
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto result = animationManager->setMorphAnimationBuffer(entity, morphData, morphIndices, numMorphTargets, numFrames, frameLengthInMs);
        return result;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_setMorphTargetWeights(
        TAnimationManager *tAnimationManager,
        EntityId entityId,
        const float *const morphData,
        int numWeights)
    {
        auto entity = utils::Entity::import(entityId);
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->setMorphTargetWeights(entity, morphData, numWeights);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_clearMorphAnimation(TAnimationManager *tAnimationManager, EntityId entityId)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto entity = utils::Entity::import(entityId);
        animManager->clearMorphAnimationBuffer(entity);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPose(TAnimationManager *tAnimationManager, TSceneAsset *sceneAsset)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            animManager->resetToRestPose(instance);
        }
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_addBoneAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int skinIndex,
        int boneIndex,
        const float *const frameData,
        int numFrames,
        float frameLengthInMs,
        float fadeOutInSecs,
        float fadeInInSecs,
        float maxDelta)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            animManager->addBoneAnimation(reinterpret_cast<GltfSceneAssetInstance *>(asset), skinIndex, boneIndex, frameData, numFrames, frameLengthInMs,
                                          fadeOutInSecs, fadeInInSecs, maxDelta);
        }
    }

    EMSCRIPTEN_KEEPALIVE EntityId AnimationManager_getBone(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int skinIndex,
        int boneIndex)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto entities = animManager->getBoneEntities(reinterpret_cast<GltfSceneAssetInstance *>(asset), skinIndex);
            if (boneIndex < entities.size())
            {
                return utils::Entity::smuggle(entities[boneIndex]);
            }
        }

        return 0;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getRestLocalTransforms(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int skinIndex,
        float *const out,
        int numBones)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            const auto transforms = animManager->getBoneRestTranforms(instance, skinIndex);
            auto numTransforms = transforms.size();
            if (numTransforms != numBones)
            {
                Log("Error - %d bone transforms available but you only specified %d.", numTransforms, numBones);
                return;
            }
            for (int boneIndex = 0; boneIndex < numTransforms; boneIndex++)
            {
                const auto transform = transforms[boneIndex];
                for (int colNum = 0; colNum < 4; colNum++)
                {
                    for (int rowNum = 0; rowNum < 4; rowNum++)
                    {
                        out[(boneIndex * 16) + (colNum * 4) + rowNum] = transform[colNum][rowNum];
                    }
                }
            }
        }
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getInverseBindMatrix(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int skinIndex,
        int boneIndex,
        float *const out)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            auto transform = animManager->getInverseBindMatrix(instance, skinIndex, boneIndex);
            for (int colNum = 0; colNum < 4; colNum++)
            {
                for (int rowNum = 0; rowNum < 4; rowNum++)
                {
                    out[(colNum * 4) + rowNum] = transform[colNum][rowNum];
                }
            }
        }
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_playAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int index,
        bool loop,
        bool reverse,
        bool replaceActive,
        float crossfade,
        float startOffset)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);

            animManager->playGltfAnimation(instance, index, loop, reverse, replaceActive, crossfade, startOffset);
        }
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_stopAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int index)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);

            animManager->stopGltfAnimation(instance, index);
        }
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationFrame(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int animationIndex,
        int frame)
    {
        auto *animManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            animManager->setGltfAnimationFrame(instance, animationIndex, frame);
        }
    }

    EMSCRIPTEN_KEEPALIVE float AnimationManager_getAnimationDuration(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int animationIndex)
    {
        auto instance = ((GltfSceneAssetInstance *)sceneAsset);
        return ((AnimationManager *)tAnimationManager)->getGltfAnimationDuration(instance, animationIndex);
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getAnimationCount(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset)
    {
        auto instance = ((GltfSceneAssetInstance *)sceneAsset);
        auto names = ((AnimationManager *)tAnimationManager)->getGltfAnimationNames(instance);
        return (int)names.size();
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getAnimationName(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        char *const outPtr,
        int index)
    {
        auto instance = ((GltfSceneAssetInstance *)sceneAsset);
        auto names = ((AnimationManager *)tAnimationManager)->getGltfAnimationNames(instance);
        std::string name = names[index];
        strcpy(outPtr, name.c_str());
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getBoneCount(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int skinIndex)
    {
        auto instance = ((GltfSceneAssetInstance *)sceneAsset);
        auto entities = ((AnimationManager *)tAnimationManager)->getBoneEntities(instance, skinIndex);
        return (int)entities.size();
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getBoneNames(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        const char **out,
        int skinIndex)
    {
        auto instance = ((GltfSceneAssetInstance *)sceneAsset);
        auto entities = ((AnimationManager *)tAnimationManager)->getBoneEntities(instance, skinIndex);
        // Note: This needs implementation of a method to get bone names from entities
        // Current source doesn't show how bone names are retrieved
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_updateBoneMatrices(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset)
    {
        auto instance = ((GltfSceneAssetInstance *)sceneAsset);
        ((AnimationManager *)tAnimationManager)->updateBoneMatrices(instance);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getMorphTargetNameCount(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        EntityId childEntity)
    {
        auto asset = ((GltfSceneAsset *)sceneAsset);
        auto names = ((AnimationManager *)tAnimationManager)->getMorphTargetNames(asset, childEntity);
        return (int)names.size();
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getMorphTargetName(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        EntityId childEntity,
        char *const outPtr,
        int index)
    {
        auto asset = ((GltfSceneAsset *)sceneAsset);
        auto names = ((AnimationManager *)tAnimationManager)->getMorphTargetNames(asset, childEntity);
        std::string name = names[index];
        strcpy(outPtr, name.c_str());
    }
}