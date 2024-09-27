#ifdef _WIN32
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "opengl32.lib")
#endif

#include "ResourceBuffer.hpp"
#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"
#include "ThreadPool.hpp"

#include <thread>
#include <functional>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

using namespace thermion_filament;

extern "C"
{
    EMSCRIPTEN_KEEPALIVE void Gizmo_pick(TGizmo *tGizmo, TView *tView, int x, int y, void (*callback)(EntityId entityId, int x, int y))
    {
        auto *gizmo = reinterpret_cast<Gizmo*>(tGizmo);
        auto *view = reinterpret_cast<View*>(tView);
        gizmo->pick(view, x, y, callback);
    }
}