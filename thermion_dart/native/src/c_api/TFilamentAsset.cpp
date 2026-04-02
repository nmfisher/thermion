#include <gltfio/FilamentAsset.h>

#include "c_api/TSceneAsset.h"
#include "scene/SceneAsset.hpp"
#include "scene/GltfSceneAsset.hpp"

using namespace thermion;

#ifdef __cplusplus

extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE uint32_t FilamentAsset_getEntityCount(
    TFilamentAsset *tFilamentAsset
) { 
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    return filamentAsset->getEntityCount();
}
EMSCRIPTEN_KEEPALIVE void FilamentAsset_getEntities(
    TFilamentAsset *tFilamentAsset,
    EntityId* out
) {
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    for(int i=0; i < filamentAsset->getEntityCount(); i++) {
        out[i] = utils::Entity::smuggle(filamentAsset->getEntities()[i]);
    }
}

EMSCRIPTEN_KEEPALIVE EntityId FilamentAsset_getWireframe(
    TFilamentAsset *tFilamentAsset
) {
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    return utils::Entity::smuggle(filamentAsset->getWireframe());
}

EMSCRIPTEN_KEEPALIVE const void* FilamentAsset_getSourceAsset(
    TFilamentAsset *tFilamentAsset
) {
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset*>(tFilamentAsset);
    return filamentAsset->getSourceAsset();
}

#ifdef __cplusplus
}
#endif

