#include "filament/LightManager.h"
#include "ResourceBuffer.hpp"
#include "FilamentViewer.hpp"
#include "Log.hpp"
#include "APIExport.h"

using namespace thermion;

extern "C"
{

#include "TSceneManager.h"

    EMSCRIPTEN_KEEPALIVE TGizmo *SceneManager_createGizmo(TSceneManager *tSceneManager, TView *tView, TScene *tScene)
    {
        auto sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *scene = reinterpret_cast<Scene *>(tScene);
        auto *view = reinterpret_cast<View *>(tView);
        auto gizmo = sceneManager->createGizmo(view, scene);
        return reinterpret_cast<TGizmo *>(gizmo);
    }

    EMSCRIPTEN_KEEPALIVE EntityId SceneManager_loadGlbFromBuffer(TSceneManager *sceneManager, const uint8_t *const data, size_t length, bool keepData, int priority, int layer, bool loadResourcesAsync)
    {
        return ((SceneManager *)sceneManager)->loadGlbFromBuffer((const uint8_t *)data, length, 1, keepData, priority, layer, loadResourcesAsync);
    }

    EMSCRIPTEN_KEEPALIVE bool SceneManager_setMorphAnimation(
        TSceneManager *sceneManager,
        EntityId asset,
        const float *const morphData,
        const uint32_t *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {
        auto result = ((SceneManager *)sceneManager)->setMorphAnimationBuffer(asset, morphData, morphIndices, numMorphTargets, numFrames, frameLengthInMs);
        return result;
    }

    EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_getCameraByName(TSceneManager *tSceneManager, EntityId entityId, const char *name)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE bool SceneManager_setTransform(TSceneManager *sceneManager, EntityId entityId, const double *const transform)
    {
        auto matrix = math::mat4(
            transform[0], transform[1], transform[2],
            transform[3],
            transform[4],
            transform[5],
            transform[6],
            transform[7],
            transform[8],
            transform[9],
            transform[10],
            transform[11],
            transform[12],
            transform[13],
            transform[14],
            transform[15]);
        return ((SceneManager *)sceneManager)->setTransform(entityId, matrix);
    }

    EMSCRIPTEN_KEEPALIVE Aabb3 SceneManager_getRenderableBoundingBox(TSceneManager *tSceneManager, EntityId entity)
    {
        auto sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return sceneManager->getRenderableBoundingBox(entity);
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_setVisibilityLayer(TSceneManager *tSceneManager, EntityId entity, int layer)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        sceneManager->setVisibilityLayer(entity, layer);
    }

    EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitMaterialInstance(TSceneManager *sceneManager)
    {
        auto *instance = ((SceneManager *)sceneManager)->createUnlitMaterialInstance();
        return reinterpret_cast<TMaterialInstance *>(instance);
    }

    EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitFixedSizeMaterialInstance(TSceneManager *sceneManager)
    {
        auto *instance = ((SceneManager *)sceneManager)->createUnlitFixedSizeMaterialInstance();
        return reinterpret_cast<TMaterialInstance *>(instance);
    }

    EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_createCamera(TSceneManager *tSceneManager)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return reinterpret_cast<TCamera *>(sceneManager->createCamera());
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_destroyCamera(TSceneManager *tSceneManager, TCamera *tCamera)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *camera = reinterpret_cast<Camera *>(tCamera);
        sceneManager->destroyCamera(camera);
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneManager_getCameraCount(TSceneManager *tSceneManager)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return sceneManager->getCameraCount();
    }

    EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_getCameraAt(TSceneManager *tSceneManager, size_t index)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *camera = sceneManager->getCameraAt(index);
        return reinterpret_cast<TCamera *>(camera);
    }

    EMSCRIPTEN_KEEPALIVE EntityId SceneManager_createGeometry(
        TSceneManager *sceneManager,
        float *vertices,
        int numVertices,
        float *normals,
        int numNormals,
        float *uvs,
        int numUvs,
        uint16_t *indices,
        int numIndices,
        int primitiveType,
        TMaterialInstance *materialInstance,
        bool keepData)
    {
        return ((SceneManager *)sceneManager)->createGeometry(vertices, static_cast<uint32_t>(numVertices), normals, static_cast<uint32_t>(numNormals), uvs, static_cast<uint32_t>(numUvs), indices, static_cast<uint32_t>(numIndices), (filament::RenderableManager::PrimitiveType)primitiveType, reinterpret_cast<MaterialInstance *>(materialInstance), keepData);
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_destroyMaterialInstance(TSceneManager *sceneManager, TMaterialInstance *instance)
    {
        ((SceneManager *)sceneManager)->destroy(reinterpret_cast<MaterialInstance *>(instance));
    }

    
}