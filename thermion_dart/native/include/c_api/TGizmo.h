#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include <stddef.h>

#include "APIBoundaryTypes.h"
#include "APIExport.h"
#include "TView.h"

enum TGizmoAxis { X, Y, Z };
enum TGizmoPickResultType { AxisX, AxisY, AxisZ, Parent, None };

typedef void (*GizmoPickCallback)(TGizmoPickResultType resultType, float x, float y, float z);

EMSCRIPTEN_KEEPALIVE TGizmo *Gizmo_create(TEngine *tEngine, TView *tView, TGizmoType tGizmoType);
EMSCRIPTEN_KEEPALIVE void Gizmo_pick(TGizmo *tGizmo, uint32_t x, uint32_t y, GizmoPickCallback callback);
EMSCRIPTEN_KEEPALIVE void Gizmo_highlight(TGizmo *tGizmo, TGizmoAxis axis);
EMSCRIPTEN_KEEPALIVE void Gizmo_unhighlight(TGizmo *tGizmo);

#ifdef __cplusplus
}
#endif
