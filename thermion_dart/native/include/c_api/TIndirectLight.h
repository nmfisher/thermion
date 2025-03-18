#pragma once

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

EMSCRIPTEN_KEEPALIVE void IndirectLight_setRotation(TIndirectLight *tIndirectLight, double *rotation);

#ifdef __cplusplus
}
#endif
