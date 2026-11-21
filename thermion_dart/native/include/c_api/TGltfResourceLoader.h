#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TGltfResourceLoader *GltfResourceLoader_create(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroy(TEngine *tEngine, TGltfResourceLoader *tGltfResourceLoader);
EMSCRIPTEN_KEEPALIVE bool GltfResourceLoader_asyncBeginLoad(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset);
EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoad(TGltfResourceLoader *tGltfResourceLoader);
EMSCRIPTEN_KEEPALIVE float GltfResourceLoader_asyncGetLoadProgress(TGltfResourceLoader *tGltfResourceLoader);
// Submits data without copying. Filament retains it after this call returns.
// onRelease(data, length, userData) is responsible for releasing its storage;
// keep the buffer and any callback context valid until that callback runs.
// The release callback may run on a native thread.
EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceData(
    TGltfResourceLoader *tGltfResourceLoader, const char *uri, uint8_t *data, size_t length,
    void (*onRelease)(void *buffer, size_t length, void *userData), void *userData);
EMSCRIPTEN_KEEPALIVE bool GltfResourceLoader_loadResources(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset);


#ifdef __cplusplus
}
#endif

