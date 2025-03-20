#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TGltfAssetLoader *GltfAssetLoader_create(TEngine *tEngine, TMaterialProvider *tMaterialProvider);

EMSCRIPTEN_KEEPALIVE TFilamentAsset *GltfAssetLoader_load(
    TEngine *tEngine,
    TGltfAssetLoader *tAssetLoader,
    uint8_t *data,
    size_t length,
    uint8_t numInstances
);
EMSCRIPTEN_KEEPALIVE TMaterialInstance *GltfAssetLoader_getMaterialInstance(TRenderableManager *tRenderableManager, TFilamentAsset *tAsset);
EMSCRIPTEN_KEEPALIVE TMaterialProvider *GltfAssetLoader_getMaterialProvider(TGltfAssetLoader *tAssetLoader);

#ifdef __cplusplus
}
#endif

