#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TGltfResourceLoader *GltfResourceLoader_create(TEngine *tEngine, const char *relativeResourcePath);
EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroy(TEngine *tEngine, TGltfResourceLoader *tGltfResourceLoader);
EMSCRIPTEN_KEEPALIVE bool GltfResourceLoader_asyncBeginLoad(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset);
EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoad(TGltfResourceLoader *tGltfResourceLoader);
EMSCRIPTEN_KEEPALIVE float GltfResourceLoader_asyncGetLoadProgress(TGltfResourceLoader *tGltfResourceLoader);
EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceData(TGltfResourceLoader *tGltfResourceLoader, const char *uri, uint8_t *data, size_t length);
EMSCRIPTEN_KEEPALIVE bool GltfResourceLoader_loadResources(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset);


#ifdef __cplusplus
}
#endif

