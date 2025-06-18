#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE void Skybox_setColor(TSkybox* tSkybox, double r, double g, double b, double a);

#ifdef __cplusplus
}
#endif

