#pragma once

#include <utils/Entity.h>

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

    
#ifdef __cplusplus
}
#endif

