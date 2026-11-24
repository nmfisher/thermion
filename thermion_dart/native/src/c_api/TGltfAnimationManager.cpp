// glTF-only embedded clip playback C API, keyed on a dedicated
// TGltfAnimationManager handle (TGltfAnimationManager.h). The core
// AnimationManager (TAnimationManager.cpp/.h) has no gltfio dependency and
// no glTF surface; GltfAnimationManager_create adds this handle's
// GltfAnimationComponentManager to the core manager via addTickable(), so
// clips are ticked by the same AnimationManager_update() frame hook, and
// GltfAnimationManager_destroy removes it again.

#include "rendering/EngineApiLock.hpp"
#include "Log.hpp"
#include "ThermionFeatures.h"

#include <utils/Entity.h>

#include "c_api/APIExport.h"
#include "scene/AnimationManager.hpp"

#if THERMION_ENABLE_GLTF
#include "scene/GltfSceneAssetInstance.hpp"
#include "components/GltfAnimationComponentManager.hpp"
#endif

using namespace thermion;

#if THERMION_ENABLE_GLTF

namespace thermion
{
    // The TGltfAnimationManager handle: one clip playback system plus the
    // core AnimationManager it ticks through. The component manager has its
    // own internal mutex serializing direct FFI calls against update().
    struct GltfAnimationManager
    {
        AnimationManager *animationManager;
        GltfAnimationComponentManager componentManager;

        GltfAnimationManager(AnimationManager *am) : animationManager(am),
                                                     componentManager(
                                                         utils::EntityManager::get(),
                                                         am->getEngine()->getTransformManager(),
                                                         am->getEngine()->getRenderableManager())
        {
        }
    };
}

#endif // THERMION_ENABLE_GLTF

extern "C"
{

#include "c_api/TGltfAnimationManager.h"

#if THERMION_ENABLE_GLTF

    EMSCRIPTEN_KEEPALIVE TGltfAnimationManager *GltfAnimationManager_create(TAnimationManager *tAnimationManager)
    {
        THERMION_ENGINE_API_GUARD;
        auto *animationManager = reinterpret_cast<AnimationManager *>(tAnimationManager);
        auto *gltfAnimationManager = new GltfAnimationManager(animationManager);
        animationManager->addTickable(&gltfAnimationManager->componentManager);
        return reinterpret_cast<TGltfAnimationManager *>(gltfAnimationManager);
    }

    EMSCRIPTEN_KEEPALIVE void GltfAnimationManager_destroy(TGltfAnimationManager *tGltfAnimationManager)
    {
        THERMION_ENGINE_API_GUARD;
        auto *gltfAnimationManager = reinterpret_cast<GltfAnimationManager *>(tGltfAnimationManager);
        // Remove from the frame tick before freeing, so update() can never
        // see a dangling tickable. Must run before AnimationManager_destroy.
        gltfAnimationManager->animationManager->removeTickable(&gltfAnimationManager->componentManager);
        delete gltfAnimationManager;
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

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_addGltfAnimationComponent(TGltfAnimationManager *tGltfAnimationManager, TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return false;
        }

        auto *gltfAnimationManager = reinterpret_cast<GltfAnimationManager *>(tGltfAnimationManager);
        gltfAnimationManager->componentManager.addAnimationComponent(instance->getInstance());
        TRACE("Added glTF animation component");
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeGltfAnimationComponent(TGltfAnimationManager *tGltfAnimationManager, TSceneAsset *tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        auto instance = getGltfInstance(sceneAsset);
        if (!instance)
        {
            return false;
        }

        auto *gltfAnimationManager = reinterpret_cast<GltfAnimationManager *>(tGltfAnimationManager);
        gltfAnimationManager->componentManager.removeAnimationComponent(instance->getInstance());
        TRACE("Removed glTF animation component");
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_playGltfAnimation(
        TGltfAnimationManager *tGltfAnimationManager,
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

        auto *gltfAnimationManager = reinterpret_cast<GltfAnimationManager *>(tGltfAnimationManager);
        auto &system = gltfAnimationManager->componentManager;
        system.addAnimationComponent(instance->getInstance());

        if (index < 0)
        {
            Log("ERROR: glTF animation index must be greater than zero.");
            return true;
        }

        system.addGltfAnimation(instance->getInstance(), index, loop, reverse, replaceActive, crossfade, startOffset, speed);

        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_stopGltfAnimation(
        TGltfAnimationManager *tGltfAnimationManager,
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

        auto *gltfAnimationManager = reinterpret_cast<GltfAnimationManager *>(tGltfAnimationManager);
        // Stopping a clip on an asset that never played one is a no-op
        // inside removeGltfAnimation (missing component check).
        gltfAnimationManager->componentManager.removeGltfAnimation(instance->getInstance(), index);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_setGltfAnimationTime(
        TGltfAnimationManager *tGltfAnimationManager,
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

        auto *gltfAnimationManager = reinterpret_cast<GltfAnimationManager *>(tGltfAnimationManager);
        gltfAnimationManager->componentManager.setGltfAnimationTime(instance->getInstance(), animationIndex, timeInSeconds);
        return true;
    }

    EMSCRIPTEN_KEEPALIVE float AnimationManager_getGltfAnimationDuration(
        TGltfAnimationManager *tGltfAnimationManager,
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

        auto *gltfAnimationManager = reinterpret_cast<GltfAnimationManager *>(tGltfAnimationManager);
        return gltfAnimationManager->componentManager.getGltfAnimationDuration(instance->getInstance(), animationIndex);
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getGltfAnimationCount(
        TGltfAnimationManager *tGltfAnimationManager,
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

        // Read-only animator query.
        return (int)instance->getInstance()->getAnimator()->getAnimationCount();
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getGltfAnimationName(
        TGltfAnimationManager *tGltfAnimationManager,
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

        // Read-only animator query.
        auto *animator = instance->getInstance()->getAnimator();
        if (index < 0 || (size_t)index >= animator->getAnimationCount())
        {
            strcpy(outPtr, "FILAMENT_ERROR_NOT_FOUND");
            return;
        }
        strcpy(outPtr, animator->getAnimationName(index));
    }

#else // !THERMION_ENABLE_GLTF
// Stub contract: the whole file is glTF-only clip playback, so every symbol
// keeps its signature
// and no gltfio symbol is referenced. create returns null (FFIFilamentApp's
// Dart guards turn glTF requests into UnsupportedError before any of this is
// reached); destroy tolerates the null handle; the clip entry points report
// the same "wrong asset type" result the real implementation returns for a
// non-glTF asset: booleans false, counts -1, durations -1, names
// FILAMENT_ERROR_NOT_FOUND, out-parameters untouched.

    EMSCRIPTEN_KEEPALIVE TGltfAnimationManager *GltfAnimationManager_create(TAnimationManager *tAnimationManager)
    {
        Log("GltfAnimationManager_create: glTF support is disabled in this build (features.gltf: false)");
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE void GltfAnimationManager_destroy(TGltfAnimationManager *tGltfAnimationManager)
    {
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_addGltfAnimationComponent(TGltfAnimationManager *tGltfAnimationManager, TSceneAsset *tSceneAsset)
    {
        return false;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeGltfAnimationComponent(TGltfAnimationManager *tGltfAnimationManager, TSceneAsset *tSceneAsset)
    {
        return false;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_playGltfAnimation(
        TGltfAnimationManager *tGltfAnimationManager,
        TSceneAsset *tSceneAsset,
        int index,
        bool loop,
        bool reverse,
        bool replaceActive,
        float crossfade,
        float startOffset,
        float speed)
    {
        return false;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_stopGltfAnimation(
        TGltfAnimationManager *tGltfAnimationManager,
        TSceneAsset *tSceneAsset,
        int index)
    {
        return false;
    }

    EMSCRIPTEN_KEEPALIVE bool AnimationManager_setGltfAnimationTime(
        TGltfAnimationManager *tGltfAnimationManager,
        TSceneAsset *tSceneAsset,
        int animationIndex,
        float timeInSeconds)
    {
        return false;
    }

    EMSCRIPTEN_KEEPALIVE float AnimationManager_getGltfAnimationDuration(
        TGltfAnimationManager *tGltfAnimationManager,
        TSceneAsset *tSceneAsset,
        int animationIndex)
    {
        return -1.0;
    }

    EMSCRIPTEN_KEEPALIVE int AnimationManager_getGltfAnimationCount(
        TGltfAnimationManager *tGltfAnimationManager,
        TSceneAsset *tSceneAsset)
    {
        return -1;
    }

    EMSCRIPTEN_KEEPALIVE void AnimationManager_getGltfAnimationName(
        TGltfAnimationManager *tGltfAnimationManager,
        TSceneAsset *tSceneAsset,
        char *const outPtr,
        int index)
    {
        if (outPtr) {
            strcpy(outPtr, "FILAMENT_ERROR_NOT_FOUND");
        }
    }

#endif // THERMION_ENABLE_GLTF
}
