#include <filament/View.h>
#include <filament/Engine.h>
#include <filament/Scene.h>

#include "c_api/TGizmo.h"
#include "scene/Gizmo.hpp"
#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
#endif

        EMSCRIPTEN_KEEPALIVE void Gizmo_pick(TGizmo *tGizmo, uint32_t x, uint32_t y, GizmoPickCallback callback)
        {
            auto *gizmo = reinterpret_cast<Gizmo *>(tGizmo);
            gizmo->pick(x, y, reinterpret_cast<Gizmo::GizmoPickCallback>(callback));
        }

        EMSCRIPTEN_KEEPALIVE void Gizmo_highlight(TGizmo *tGizmo, TGizmoAxis tAxis)
        {
            auto *gizmo = reinterpret_cast<Gizmo *>(tGizmo);
            auto axis = static_cast<Gizmo::Axis>(tAxis);
            gizmo->highlight(axis);
        }

        EMSCRIPTEN_KEEPALIVE void Gizmo_unhighlight(TGizmo *tGizmo)
        {
            auto *gizmo = reinterpret_cast<Gizmo *>(tGizmo);
            gizmo->unhighlight(Gizmo::Axis::X);
            gizmo->unhighlight(Gizmo::Axis::Y);
            gizmo->unhighlight(Gizmo::Axis::Z);
        }

#ifdef __cplusplus
    }
}
#endif
