#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include <gltfio/FilamentAsset.h>

#include "c_api/TSceneAsset.h"
#include "scene/SceneAsset.hpp"
#include "scene/GltfSceneAsset.hpp"
#include "scene/GeometrySceneAssetBuilder.hpp"

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
#ifdef __cplusplus
}
#endif

