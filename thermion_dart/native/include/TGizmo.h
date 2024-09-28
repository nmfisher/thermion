#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include "ThermionDartApi.h"
#include "TGizmo.h"

typedef void (*GizmoPickCallback)(EntityId entityId, uint32_t x, uint32_t y, TView* view);

EMSCRIPTEN_KEEPALIVE TGizmo* Gizmo_new(TEngine *tEngine, TView *tView, TScene *tScene);
EMSCRIPTEN_KEEPALIVE void Gizmo_pick(TGizmo *tGizmo, uint32_t x, uint32_t y, GizmoPickCallback callback);
EMSCRIPTEN_KEEPALIVE void Gizmo_setVisibility(TGizmo *tGizmo, bool visible);

#ifdef __cplusplus
}
#endif
