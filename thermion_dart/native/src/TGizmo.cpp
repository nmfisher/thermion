#include <filament/View.h>
#include <filament/Engine.h>
#include <filament/Scene.h>

#include "ThermionDartApi.h"
#include "TGizmo.h"
#include "Gizmo.hpp"
#include "Log.hpp"

#ifdef __cplusplus
namespace thermion {
extern "C"
{
using namespace filament;
#endif

    EMSCRIPTEN_KEEPALIVE void Gizmo_pick(TGizmo *tGizmo, uint32_t x, uint32_t y, GizmoPickCallback callback)
    {
        auto *gizmo = reinterpret_cast<Gizmo*>(tGizmo);
        gizmo->pick(x, y, reinterpret_cast<Gizmo::PickCallback>(callback));
    }

    EMSCRIPTEN_KEEPALIVE void Gizmo_setVisibility(TGizmo *tGizmo, bool visible) { 
        auto *gizmo = reinterpret_cast<Gizmo*>(tGizmo);
        gizmo->setVisibility(visible);
    }

#ifdef __cplusplus
}
}
#endif
