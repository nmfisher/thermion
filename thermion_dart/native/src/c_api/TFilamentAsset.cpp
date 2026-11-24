#include "rendering/EngineApiLock.hpp"
#include "ThermionFeatures.h"

#if THERMION_ENABLE_GLTF
#include <gltfio/FilamentAsset.h>
#endif

#include "c_api/TSceneAsset.h"
#if THERMION_ENABLE_GLTF
#include "scene/SceneAsset.hpp"
#include "scene/GltfSceneAsset.hpp"
#endif

using namespace thermion;

#ifdef __cplusplus

extern "C"
{
#endif

#if THERMION_ENABLE_GLTF

EMSCRIPTEN_KEEPALIVE uint32_t FilamentAsset_getEntityCount(
    TFilamentAsset *tFilamentAsset
) {
    THERMION_ENGINE_API_GUARD;
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    return filamentAsset->getEntityCount();
}
EMSCRIPTEN_KEEPALIVE void FilamentAsset_getEntities(
    TFilamentAsset *tFilamentAsset,
    EntityId* out
) {
    THERMION_ENGINE_API_GUARD;
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    for(int i=0; i < filamentAsset->getEntityCount(); i++) {
        out[i] = utils::Entity::smuggle(filamentAsset->getEntities()[i]);
    }
}

EMSCRIPTEN_KEEPALIVE EntityId FilamentAsset_getWireframe(
    TFilamentAsset *tFilamentAsset
) {
    THERMION_ENGINE_API_GUARD;
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    return utils::Entity::smuggle(filamentAsset->getWireframe());
}

EMSCRIPTEN_KEEPALIVE const void* FilamentAsset_getSourceAsset(
    TFilamentAsset *tFilamentAsset
) {
    THERMION_ENGINE_API_GUARD;
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    return filamentAsset->getSourceAsset();
}

#else // !THERMION_ENABLE_GLTF
// Stub contract: counts return 0,
// getters return null, void functions are no-ops.

EMSCRIPTEN_KEEPALIVE uint32_t FilamentAsset_getEntityCount(
    TFilamentAsset *tFilamentAsset
) {
    return 0;
}
EMSCRIPTEN_KEEPALIVE void FilamentAsset_getEntities(
    TFilamentAsset *tFilamentAsset,
    EntityId* out
) {
}

EMSCRIPTEN_KEEPALIVE EntityId FilamentAsset_getWireframe(
    TFilamentAsset *tFilamentAsset
) {
    return 0;
}

EMSCRIPTEN_KEEPALIVE const void* FilamentAsset_getSourceAsset(
    TFilamentAsset *tFilamentAsset
) {
    return nullptr;
}

#endif // THERMION_ENABLE_GLTF

#ifdef __cplusplus
}
#endif
