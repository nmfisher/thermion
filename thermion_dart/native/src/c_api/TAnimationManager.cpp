#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include "Log.hpp"

#include <utils/Entity.h>

#include "c_api/APIExport.h"
#include "scene/AnimationManager.hpp"

using namespace thermion;

extern "C"
{

#include "c_api/TAnimationManager.h"

    EMSCRIPTEN_KEEPALIVE TAnimationManager *AnimationManager_create(TEngine *tEngine, TScene *tScene) {
        auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
        auto *scene = reinterpret_cast<filament::Scene *>(tScene);
        auto animationManager = new AnimationManager(engine, scene);
        return reinterpret_cast<TAnimationManager *>(animationManager);
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_update(TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos) {
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->update(frameTimeInNanos);
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_addGltfAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf || !sceneAsset->isInstance()) {
            return false;
        }
        
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);

        animationManager->addGltfAnimationComponent(reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset));
        return true;
    }
    EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeGltfAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf || !sceneAsset->isInstance()) {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->removeGltfAnimationComponent(reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset));
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_addBoneAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf || !sceneAsset->isInstance()) {
            return false;
        }
        
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);

        animationManager->addBoneAnimationComponent(reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset));
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeBoneAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf || !sceneAsset->isInstance()) {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->removeBoneAnimationComponent(reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset));
        return true;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_addMorphAnimationComponent(TAnimationManager *tAnimationManager, EntityId entity)
    {
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->addMorphAnimationComponent(utils::Entity::import(entity));
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_removeMorphAnimationComponent(TAnimationManager *tAnimationManager, EntityId entity)
    {
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->removeMorphAnimationComponent(utils::Entity::import(entity));
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
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto entity = utils::Entity::import(entityId);
        animationManager->clearMorphAnimationBuffer(entity);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPose(TAnimationManager *tAnimationManager, TSceneAsset *sceneAsset)
    {
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            animationManager->resetToRestPose(instance);
        }
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_addBoneAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int skinIndex,
        int boneIndex,
        const float *const frameData,
        int numFrames,
        float frameLengthInMs,
        float fadeOutInSecs,
        float fadeInInSecs,
        float maxDelta)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return false;
        }
        
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        GltfSceneAssetInstance *instance;

        if (sceneAsset->isInstance())
        {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset);
        } else {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset->getInstanceAt(0));
        }
        animationManager->addBoneAnimationComponent(instance);
        animationManager->addBoneAnimation(instance, skinIndex, boneIndex, frameData, numFrames, frameLengthInMs, fadeOutInSecs, fadeInInSecs, maxDelta);
        return true;
        
    }

    EMSCRIPTEN_KEEPALIVE EntityId AnimationManager_getBone(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int skinIndex,
        int boneIndex)
    {
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto entities = animationManager->getBoneEntities(reinterpret_cast<GltfSceneAssetInstance *>(asset), skinIndex);
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
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            const auto transforms = animationManager->getBoneRestTranforms(instance, skinIndex);
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
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            auto transform = animationManager->getInverseBindMatrix(instance, skinIndex, boneIndex);
            for (int colNum = 0; colNum < 4; colNum++)
            {
                for (int rowNum = 0; rowNum < 4; rowNum++)
                {
                    out[(colNum * 4) + rowNum] = transform[colNum][rowNum];
                }
            }
        }
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_playGltfAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int index,
        bool loop,
        bool reverse,
        bool replaceActive,
        float crossfade,
        float startOffset)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return false;
        }
        
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        GltfSceneAssetInstance *instance;

        if (sceneAsset->isInstance())
        {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset);
        } else {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset->getInstanceAt(0));
        }
        animationManager->addGltfAnimationComponent(instance);
        animationManager->playGltfAnimation(instance, index, loop, reverse, replaceActive, crossfade, startOffset);
        
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_stopGltfAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int index)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return false;
        }
        
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        GltfSceneAssetInstance *instance;

        if (sceneAsset->isInstance())
        {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset);
        } else {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset->getInstanceAt(0));
        }
        animationManager->stopGltfAnimation(instance, index);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationFrame(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int animationIndex,
        int frame)
    {
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && asset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset);
            animationManager->setGltfAnimationFrame(instance, animationIndex, frame);
        }
    }

    EMSCRIPTEN_KEEPALIVE float AnimationManager_getGltfAnimationDuration(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int animationIndex)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return false;
        }
        
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        GltfSceneAssetInstance *instance;

        if (sceneAsset->isInstance())
        {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset);
        } else {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset->getInstanceAt(0));
        }
        
        return animationManager->getGltfAnimationDuration(instance, animationIndex);
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getGltfAnimationCount(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset)
    {

        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return -1;
        }
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        GltfSceneAssetInstance *instance;
        if(sceneAsset->isInstance()) {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset);
        } else {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset->getInstanceAt(0));
        }
        auto names = animationManager->getGltfAnimationNames(instance);
        TRACE("Animation count : %d", names.size());
        return (int)names.size();
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getGltfAnimationName(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        char *const outPtr,
        int index)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            strcpy(outPtr, "FILAMENT_ERROR_NOT_FOUND");
            return;
        }
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        GltfSceneAssetInstance *instance;
        if(sceneAsset->isInstance()) {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset);
        } else {
            instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset->getInstanceAt(0));
        }
        auto names = animationManager->getGltfAnimationNames(instance);
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
        TSceneAsset *tSceneAsset,
        EntityId childEntity)
    {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return -1;
        }
        
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        GltfSceneAsset *gltfAsset;

        if (sceneAsset->isInstance())
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(sceneAsset);
            gltfAsset = reinterpret_cast<GltfSceneAsset *>(instance->getInstanceOwner());
        } else {
            gltfAsset = reinterpret_cast<GltfSceneAsset *>(sceneAsset);
        }

        auto names = animationManager->getMorphTargetNames(gltfAsset, childEntity);
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