#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE void Skybox_setColor(TSkybox* tSkybox, double r, double g, double b, double a);

///
/// Sets bits in a visibility mask (see filament::Skybox::setLayerMask).
///
EMSCRIPTEN_KEEPALIVE void Skybox_setLayerMask(TSkybox* tSkybox, uint8_t select, uint8_t values);

///
/// Returns the visibility mask bits.
///
EMSCRIPTEN_KEEPALIVE uint8_t Skybox_getLayerMask(TSkybox* tSkybox);

///
/// Returns the skybox intensity in lux.
///
EMSCRIPTEN_KEEPALIVE float Skybox_getIntensity(TSkybox* tSkybox);

///
/// Returns the environment texture, or nullptr for a color-only skybox.
///
EMSCRIPTEN_KEEPALIVE TTexture* Skybox_getTexture(TSkybox* tSkybox);

#ifdef __cplusplus
}
#endif

