#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif
    EMSCRIPTEN_KEEPALIVE uint32_t FilamentAsset_getEntityCount(
        TFilamentAsset *filamentAsset
    );
    EMSCRIPTEN_KEEPALIVE void FilamentAsset_getEntities(
        TFilamentAsset *filamentAsset,
        EntityId* out
    );

    EMSCRIPTEN_KEEPALIVE EntityId FilamentAsset_getWireframe(
        TFilamentAsset *filamentAsset
    );

    EMSCRIPTEN_KEEPALIVE const void* FilamentAsset_getSourceAsset(
        TFilamentAsset *filamentAsset
    );

#ifdef __cplusplus
}
#endif

