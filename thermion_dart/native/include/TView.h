#ifndef _FLUTTER_FILAMENT_API_H
#define _FLUTTER_FILAMENT_API_H

#ifdef _WIN32
#ifdef IS_DLL
#define EMSCRIPTEN_KEEPALIVE __declspec(dllimport)
#else
#define EMSCRIPTEN_KEEPALIVE __declspec(dllexport)
#endif
#else
#ifndef EMSCRIPTEN_KEEPALIVE
#define EMSCRIPTEN_KEEPALIVE __attribute__((visibility("default")))
#endif
#endif

// we copy the LLVM <stdbool.h> here rather than including,
// because on Windows it's difficult to pin the exact location which confuses dart ffigen

#ifndef __STDBOOL_H
#define __STDBOOL_H

#define __bool_true_false_are_defined 1

#if defined(__STDC_VERSION__) && __STDC_VERSION__ > 201710L
/* FIXME: We should be issuing a deprecation warning here, but cannot yet due
 * to system headers which include this header file unconditionally.
 */
#elif !defined(__cplusplus)
#define bool _Bool
#define true 1
#define false 0
#elif defined(__GNUC__) && !defined(__STRICT_ANSI__)
/* Define _Bool as a GNU extension. */
#define _Bool bool
#if defined(__cplusplus) && __cplusplus < 201103L
/* For C++98, define bool, false, true as a GNU extension. */
#define bool bool
#define false false
#define true true
#endif
#endif

#endif /* __STDBOOL_H */

#if defined(__APPLE__) || defined(__EMSCRIPTEN__)
#include <stddef.h>
#endif

#include "APIBoundaryTypes.h"
#include "ResourceBuffer.hpp"

#ifdef __cplusplus
extern "C"
{
#endif

// View
EMSCRIPTEN_KEEPALIVE void View_updateViewport(TView *view, uint32_t width, uint32_t height);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView *view, TRenderTarget *renderTarget);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView *view, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_updateViewport(TView* tView, uint32_t width, uint32_t height);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView* tView, TRenderTarget* tRenderTarget);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setPostProcessing(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowType(TView* tView, int shadowType);
EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptions(TView* tView, float penumbraScale, float penumbraRatioScale);
EMSCRIPTEN_KEEPALIVE void View_setBloom(TView* tView, float strength);
EMSCRIPTEN_KEEPALIVE void View_setToneMapping(TView* tView, TEngine* tEngine, int toneMapping);
EMSCRIPTEN_KEEPALIVE void View_setAntiAliasing(TView *tView, bool msaa, bool fxaa, bool taa);
EMSCRIPTEN_KEEPALIVE void View_setLayerEnabled(TView *tView, int layer, bool visible);
EMSCRIPTEN_KEEPALIVE void View_setCamera(TView *tView, TCamera *tCamera);
EMSCRIPTEN_KEEPALIVE TCamera* View_getCamera(TView *tView);


#ifdef __cplusplus
}
#endif
#endif
