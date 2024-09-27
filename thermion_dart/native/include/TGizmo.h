#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

#include "ThermionDartApi.h"

EMSCRIPTEN_KEEPALIVE void Gizmo_pick(TGizmo *tGizmo, TView *tView, int x, int y, void (*callback)(EntityId entityId, int x, int y));

#ifdef __cplusplus
}
#endif
#endif
