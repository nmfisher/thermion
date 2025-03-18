#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE void IndirectLight_setRotation(TIndirectLight *tIndirectLight, double *rotation);

#ifdef __cplusplus
}
#endif
