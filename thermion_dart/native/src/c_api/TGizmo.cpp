#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include <filament/View.h>
#include <filament/Engine.h>
#include <filament/Scene.h>

#include "c_api/TGizmo.h"
#include "c_api/TSceneAsset.h"
#include "c_api/TGltfAssetLoader.h"
#include "scene/Gizmo.hpp"
#include "scene/GltfSceneAsset.hpp"
#include "resources/translation_gizmo_glb.h"
#include "resources/rotation_gizmo_glb.h"
#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
#endif

        EMSCRIPTEN_KEEPALIVE TGizmo *Gizmo_create(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            TGltfResourceLoader *tGltfResourceLoader,
            TNameComponentManager *tNameComponentManager,
            TView *tView,
            TMaterial *tMaterial,
            TGizmoType tGizmoType)
        {

            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *view = reinterpret_cast<View *>(tView);
            auto *material = reinterpret_cast<Material *>(tMaterial);
            auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
            const uint8_t *data;
            size_t size;
            switch (tGizmoType)
            {
            case GIZMO_TYPE_TRANSLATION:
            {
                TRACE("Building translation gizmo");
                data = TRANSLATION_GIZMO_GLB_TRANSLATION_GIZMO_DATA;
                size = TRANSLATION_GIZMO_GLB_TRANSLATION_GIZMO_SIZE;
                break;
            }
            case GIZMO_TYPE_ROTATION:
            {
                TRACE("Building rotation gizmo");
                data = ROTATION_GIZMO_GLB_ROTATION_GIZMO_DATA;
                size = ROTATION_GIZMO_GLB_ROTATION_GIZMO_SIZE;
                break;
            }
            }

            auto *tFilamentAsset = GltfAssetLoader_load(
                tEngine,
                tAssetLoader,
                data,
                size,
                3);
            auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset *>(tFilamentAsset);
            auto *sceneAsset = SceneAsset_createFromFilamentAsset(
                tEngine,
                tAssetLoader,
                tNameComponentManager,
                tFilamentAsset);

            auto *gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(sceneAsset);

            gltfResourceLoader->loadResources(filamentAsset);
            auto *gizmo = new Gizmo(
                gltfSceneAsset,
                engine,
                view,
                material);
            return reinterpret_cast<TGizmo *>(gizmo);
        }

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
