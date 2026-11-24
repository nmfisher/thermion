#include "rendering/EngineApiLock.hpp"
#include "Log.hpp"

#include <utils/Entity.h>

#include "c_api/APIExport.h"
#include "scene/AnimationManager.hpp"

using namespace thermion;

extern "C"
{

#include "c_api/TAnimationManager.h"

    EMSCRIPTEN_KEEPALIVE TAnimationManager *AnimationManager_create(TEngine *tEngine) {
        THERMION_ENGINE_API_GUARD;
        auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
        auto animationManager = new AnimationManager(engine);
        return reinterpret_cast<TAnimationManager *>(animationManager);
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_destroy(TAnimationManager *tAnimationManager) {
        THERMION_ENGINE_API_GUARD;
        // glTF clip playback tickables are non-owning; their owner must call
        // GltfAnimationManager_destroy (TGltfAnimationManager.h) first.
        delete reinterpret_cast<AnimationManager *>(tAnimationManager);
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_update(TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos) {
        THERMION_ENGINE_API_GUARD;
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->update(frameTimeInNanos);
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_addBoneAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);

        // Gate on the skin interface, not the asset type: any SceneAsset with
        // a skin target (an instance for glTF owners) can carry a bone
        // animation component.
        auto *skinTarget = sceneAsset->getSkinTarget();
        if (!skinTarget || skinTarget->getSkinCount() == 0) {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);

        return animationManager->addBoneAnimationComponent(sceneAsset);
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeBoneAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        // No asset-type gate: removal simply no-ops when the skin target has
        // no bone animation component (or no skin target exists at all).
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->removeBoneAnimationComponent(sceneAsset);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_addMorphAnimationComponent(TAnimationManager *tAnimationManager, EntityId entity)
    {
        THERMION_ENGINE_API_GUARD;
        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->addMorphAnimationComponent(utils::Entity::import(entity));
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_removeMorphAnimationComponent(TAnimationManager *tAnimationManager, EntityId entity)
    {
        THERMION_ENGINE_API_GUARD;
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
        THERMION_ENGINE_API_GUARD;
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
        THERMION_ENGINE_API_GUARD;
        auto entity = utils::Entity::import(entityId);
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        animationManager->setMorphTargetWeights(entity, morphData, numWeights);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_clearMorphAnimation(TAnimationManager *tAnimationManager, EntityId entityId)
    {
        THERMION_ENGINE_API_GUARD;
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto entity = utils::Entity::import(entityId);
        animationManager->clearMorphAnimationBuffer(entity);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPose(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto *skinTarget = sceneAsset->getSkinTarget();
        if (!skinTarget || skinTarget->getSkinCount() == 0) {
            Log("Error - asset has no skin, cannot reset to rest pose");
            return;
        }

        animationManager->resetToRestPose(sceneAsset);
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
        float maxDelta,
        bool loop)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        // Gate on skinTarget + skin/bone bounds instead of the asset type so
        // non-glTF SceneAsset implementations work through the same virtual
        // skin interface.
        auto *skinTarget = sceneAsset->getSkinTarget();
        if (!skinTarget || skinIndex < 0 || (size_t)skinIndex >= skinTarget->getSkinCount() ||
            boneIndex < 0 || (size_t)boneIndex >= skinTarget->getBoneCount(skinIndex)) {
            Log("ERROR: invalid skin/bone index for bone animation.");
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        if (!animationManager->addBoneAnimationComponent(sceneAsset)) {
            return false;
        }
        return animationManager->addBoneAnimation(sceneAsset, skinIndex, boneIndex, frameData, numFrames, frameLengthInMs, fadeOutInSecs, fadeInInSecs, maxDelta, loop);

    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getRestLocalTransforms(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        int skinIndex,
        float *const out,
        int numBones)
    {
        THERMION_ENGINE_API_GUARD;
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        // Owner assets resolve to their skin target (first instance for glTF
        // owners); gate on skin bounds, not asset type.
        asset = asset->getSkinTarget();
        if (asset && skinIndex >= 0 && (size_t)skinIndex < asset->getSkinCount())
        {
            const auto transforms = animationManager->getBoneRestTranforms(asset, skinIndex);
            auto numTransforms = transforms.size();
            if (numTransforms != numBones)
            {
                Log("Error - %zu bone transforms available but you only specified %d.", numTransforms, numBones);
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
        THERMION_ENGINE_API_GUARD;
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        asset = asset->getSkinTarget();
        if (asset && skinIndex >= 0 && (size_t)skinIndex < asset->getSkinCount() &&
            boneIndex >= 0 && (size_t)boneIndex < asset->getBoneCount(skinIndex) &&
            asset->getInverseBindMatrices(skinIndex) != nullptr)
        {
            auto transform = animationManager->getInverseBindMatrix(asset, skinIndex, boneIndex);
            for (int colNum = 0; colNum < 4; colNum++)
            {
                for (int rowNum = 0; rowNum < 4; rowNum++)
                {
                    out[(colNum * 4) + rowNum] = transform[colNum][rowNum];
                }
            }
        } else {
            LOG_ERROR("AnimationManager_getInverseBindMatrix requires an asset with a skin and valid skin/bone indices");
        }
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_updateBoneMatrices(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        ((AnimationManager *)tAnimationManager)->updateBoneMatrices(asset);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getMorphTargetNameCount(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        EntityId childEntity)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        // getMorphTargetNames is a virtual on SceneAsset; asset types without
        // morph target metadata return an empty list, so no type gate needed.
        auto names = sceneAsset->getMorphTargetNames(utils::Entity::import(childEntity));
        return (int)names.size();
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getMorphTargetName(
        TAnimationManager *tAnimationManager,
        TSceneAsset *sceneAsset,
        EntityId childEntity,
        char *const outPtr,
        int index)
    {
        THERMION_ENGINE_API_GUARD;
        auto asset = reinterpret_cast<SceneAsset *>(sceneAsset);
        auto names = asset->getMorphTargetNames(utils::Entity::import(childEntity));
        std::string name = names[index];
        strcpy(outPtr, name.c_str());
    }
}