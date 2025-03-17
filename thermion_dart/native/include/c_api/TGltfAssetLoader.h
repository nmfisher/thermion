#ifndef _T_GLTF_ASSET_LOADER_H
#define _T_GLTF_ASSET_LOADER_H

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"
#include "TTexture.h"
#include "ResourceBuffer.hpp"
#include "MathUtils.hpp"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TGltfAssetLoader *GltfAssetLoader_create(TEngine *tEngine, TMaterialProvider *tMaterialProvider);
EMSCRIPTEN_KEEPALIVE TGltfResourceLoader *GltfResourceLoader_create(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE TFilamentAsset *GltfAssetLoader_load(
    TGltfAssetLoader *tAssetLoader,
    TGltfResourceLoader *tResourceLoader,
    uint8_t *data,
    size_t length,
    uint8_t numInstances
);

#ifdef __cplusplus
}
#endif

#endif