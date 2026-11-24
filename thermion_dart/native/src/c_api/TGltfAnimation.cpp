// glTF-only embedded clip playback C API. The core AnimationManager
// (TAnimationManager.cpp) has no gltfio dependency; the clip playback
// functions below drive a GltfAnimationComponentManager registered into
// the AnimationManager as a TickableAnimationSystem, so clips are
// ticked by the same AnimationManager_update() frame hook.

#include "rendering/EngineApiLock.hpp"
#include "Log.hpp"

#include <utils/Entity.h>

#include "c_api/APIExport.h"
#include "scene/AnimationManager.hpp"
#include "scene/GltfSceneAssetInstance.hpp"
#include "components/GltfAnimationComponentManager.hpp"

using namespace thermion;

extern "C"
{

#include "c_api/TAnimationManager.h"

    // Returns the glTF clip playback system for this AnimationManager,
    // creating and registering it on first use. The system is owned by the
    // AnimationManager handle and destroyed with it. The caller must hold
    // animationManager->lock(): lookup + creation + registration run under
    // one mutex hold, so two concurrent callers can never both create a
    // system (registerAnimationSystem's duplicate-name branch would delete
    // the loser's system while this function still returned its pointer).
    static GltfAnimationComponentManager *getGltfAnimationSystemLocked(AnimationManager *animationManager)
    {
        return static_cast<GltfAnimationComponentManager *>(
            animationManager->getOrCreateAnimationSystemLocked("gltf", [animationManager]() -> TickableAnimationSystem *
            {
                auto *engine = animationManager->getEngine();
                return new GltfAnimationComponentManager(
                    utils::EntityManager::get(),
                    engine->getTransformManager(),
                    engine->getRenderableManager());
            }));
    }

    // Resolves the glTF instance the clip functions operate on (owner assets
    // delegate to their first instance), or nullptr for non-glTF assets.
    static GltfSceneAssetInstance *getGltfInstance(SceneAsset *sceneAsset)
    {
        if (sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf)
        {
            return nullptr;
        }
        if (sceneAsset->isInstance())
        {
            return static_cast<GltfSceneAssetInstance *>(sceneAsset);
        }
        return static_cast<GltfSceneAssetInstance *>(sceneAsset->getInstanceAt(0));
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_addGltfAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        // Hold the manager mutex across lookup + component mutation so
        // direct FFI calls serialize against AnimationManager::update()
        // (RenderManager::tick calls update() without the engine API lock).
        auto lock = animationManager->lock();
        getGltfAnimationSystemLocked(animationManager)->addAnimationComponent(instance->getInstance());
        TRACE("Added glTF animation component");
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeGltfAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto lock = animationManager->lock();
        // Teardown path (called on every glTF asset destroy): never lazily
        // allocate a frame-ticked component manager just to remove nothing.
        auto *system = static_cast<GltfAnimationComponentManager *>(animationManager->findAnimationSystemLocked("gltf"));
        if (!system)
        {
            return true;
        }
        system->removeAnimationComponent(instance->getInstance());
        TRACE("Removed glTF animation component");
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_playGltfAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int index,
        bool loop,
        bool reverse,
        bool replaceActive,
        float crossfade,
        float startOffset,
        float speed)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto lock = animationManager->lock();
        auto *system = getGltfAnimationSystemLocked(animationManager);
        system->addAnimationComponent(instance->getInstance());

        if (index < 0)
        {
            Log("ERROR: glTF animation index must be greater than zero.");
            return true;
        }

        system->addGltfAnimation(instance->getInstance(), index, loop, reverse, replaceActive, crossfade, startOffset, speed);

        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_stopGltfAnimation(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int index)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto lock = animationManager->lock();
        // If no clip system exists, nothing can be playing; do not allocate one.
        auto *system = static_cast<GltfAnimationComponentManager *>(animationManager->findAnimationSystemLocked("gltf"));
        if (!system)
        {
            return true;
        }
        system->removeGltfAnimation(instance->getInstance(), index);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_setGltfAnimationTime(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int animationIndex,
        float timeInSeconds)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return false;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto lock = animationManager->lock();
        // Pure animator access; no GltfAnimationComponentManager state is
        // involved, so no clip system needs to exist (or be allocated).
        auto *animator = instance->getInstance()->getAnimator();
        animator->applyAnimation(animationIndex, timeInSeconds);
        animator->updateBoneMatrices();
        return true;
    }

    EMSCRIPTEN_KEEPALIVE float AnimationManager_getGltfAnimationDuration(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        int animationIndex)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return -1.0;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto lock = animationManager->lock();
        // Read-only animator query; no clip system needed.
        return instance->getInstance()->getAnimator()->getAnimationDuration(animationIndex);
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getGltfAnimationCount(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            Log("Incorrect asset type, gltf expected");
            return -1;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto lock = animationManager->lock();
        // Read-only animator query; no clip system needed.
        return (int)instance->getInstance()->getAnimator()->getAnimationCount();
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getGltfAnimationName(
        TAnimationManager *tAnimationManager,
        TSceneAsset *tSceneAsset,
        char *const outPtr,
        int index)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            strcpy(outPtr, "FILAMENT_ERROR_NOT_FOUND");
            return;
        }

        auto animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto lock = animationManager->lock();
        // Read-only animator query; no clip system needed.
        auto *animator = instance->getInstance()->getAnimator();
        if (index < 0 || (size_t)index >= animator->getAnimationCount())
        {
            strcpy(outPtr, "FILAMENT_ERROR_NOT_FOUND");
            return;
        }
        strcpy(outPtr, animator->getAnimationName(index));
    }
}
