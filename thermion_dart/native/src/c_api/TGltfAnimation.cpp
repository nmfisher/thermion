// glTF-only embedded clip playback C API. The core AnimationManager
// (TAnimationManager.cpp) has no gltfio dependency; the clip playback
// functions below drive a GltfAnimationComponentManager owned by this
// translation unit and added to the AnimationManager via addTickable(),
// so clips are ticked by the same AnimationManager_update() frame hook.

#include "rendering/EngineApiLock.hpp"
#include "Log.hpp"

#include <memory>
#include <mutex>
#include <unordered_map>

#include <utils/Entity.h>

#include "c_api/APIExport.h"
#include "scene/AnimationManager.hpp"
#include "scene/GltfSceneAssetInstance.hpp"
#include "components/GltfAnimationComponentManager.hpp"

using namespace thermion;

extern "C"
{

#include "c_api/TAnimationManager.h"

    // One clip playback system per AnimationManager, owned here (not by the
    // AnimationManager, which only holds a non-owning tickable pointer).
    // Created lazily on first clip use; removed via removeTickable() and
    // destroyed when the AnimationManager is destroyed (wrapper below).
    // The map has its own mutex because web worker builds compile
    // THERMION_ENGINE_API_GUARD to nothing.
    static std::mutex gGltfSystemsMutex;
    static std::unordered_map<AnimationManager *, std::unique_ptr<GltfAnimationComponentManager>> gGltfSystems;

    // Returns the glTF clip playback system for this AnimationManager,
    // creating it and adding it as a tickable on first use.
    static GltfAnimationComponentManager *getOrCreateGltfSystem(AnimationManager *animationManager)
    {
        std::lock_guard lock(gGltfSystemsMutex);
        auto &system = gGltfSystems[animationManager];
        if (!system)
        {
            auto *engine = animationManager->getEngine();
            system = std::make_unique<GltfAnimationComponentManager>(
                utils::EntityManager::get(),
                engine->getTransformManager(),
                engine->getRenderableManager());
            animationManager->addTickable(system.get());
        }
        return system.get();
    }

    // Returns the existing clip playback system, or nullptr. Teardown and
    // query paths must never lazily allocate a frame-ticked component
    // manager just to remove/stop nothing.
    static GltfAnimationComponentManager *findGltfSystem(AnimationManager *animationManager)
    {
        std::lock_guard lock(gGltfSystemsMutex);
        auto it = gGltfSystems.find(animationManager);
        return it == gGltfSystems.end() ? nullptr : it->second.get();
    }

    // The core AnimationManager_create stays in TAnimationManager.cpp
    // (100% core). This glTF-only translation unit owns the destroy export
    // so the tickable it added is removed and freed before the manager
    // itself dies; the frame tick can never see a dangling pointer.
    EMSCRIPTEN_KEEPALIVE void AnimationManager_destroy(TAnimationManager *tAnimationManager)
    {
        THERMION_ENGINE_API_GUARD;
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        std::unique_ptr<GltfAnimationComponentManager> system;
        {
            std::lock_guard lock(gGltfSystemsMutex);
            auto it = gGltfSystems.find(animationManager);
            if (it != gGltfSystems.end())
            {
                system = std::move(it->second);
                gGltfSystems.erase(it);
            }
        }
        if (system)
        {
            animationManager->removeTickable(system.get());
        }
        delete animationManager;
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
        getOrCreateGltfSystem(animationManager)->addAnimationComponent(instance->getInstance());
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
        // Teardown path (called on every glTF asset destroy): no system
        // means no components to remove.
        auto *system = findGltfSystem(animationManager);
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
        auto *system = getOrCreateGltfSystem(animationManager);
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
        // If no clip system exists, nothing can be playing; do not allocate one.
        auto *system = findGltfSystem(animationManager);
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