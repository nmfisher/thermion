#include <filament/LightManager.h>

#include "c_api/APIExport.h"
#include "ResourceBuffer.hpp"
#include "FilamentViewer.hpp"
#include "Log.hpp"

using namespace thermion;

extern "C"
{

#include "c_api/TSceneManager.h"

	EMSCRIPTEN_KEEPALIVE TScene *SceneManager_getScene(TSceneManager *tSceneManager) {
        auto sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return reinterpret_cast<TScene*>(sceneManager->getScene());
    }


    EMSCRIPTEN_KEEPALIVE TMaterialProvider *SceneManager_getUnlitMaterialProvider(TSceneManager *tSceneManager) { 
        auto sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto provider = sceneManager->getUnlitMaterialProvider();
        return reinterpret_cast<TMaterialProvider*>(provider);
    }

    EMSCRIPTEN_KEEPALIVE TMaterialProvider *SceneManager_getUbershaderMaterialProvider(TSceneManager *tSceneManager) {
        auto sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto provider = sceneManager->getUbershaderMaterialProvider();
        return reinterpret_cast<TMaterialProvider*>(provider);
    }

    EMSCRIPTEN_KEEPALIVE TGizmo *SceneManager_createGizmo(TSceneManager *tSceneManager, TView *tView, TScene *tScene, TGizmoType tGizmoType)
    {
        auto sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *scene = reinterpret_cast<Scene *>(tScene);
        auto *view = reinterpret_cast<View *>(tView);
        auto gizmo = sceneManager->createGizmo(view, scene, static_cast<SceneManager::GizmoType>(tGizmoType));
        return reinterpret_cast<TGizmo *>(gizmo);
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_loadGlb(TSceneManager *tSceneManager, const char *assetPath, int numInstances, bool keepData)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *asset = sceneManager->loadGlb(assetPath, numInstances, keepData);
        return reinterpret_cast<TSceneAsset *>(asset);
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_loadGltf(TSceneManager *tSceneManager, 
                                                            const char *assetPath,
                                                            const char *relativeResourcePath,
                                                            bool keepData)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *asset = sceneManager->loadGltf(assetPath, relativeResourcePath, 1, keepData);
        return reinterpret_cast<TSceneAsset *>(asset);
    }


    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_loadGlbFromBuffer(TSceneManager *tSceneManager, const uint8_t *const data, size_t length, bool keepData, int priority, int layer, bool loadResourcesAsync)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *asset = sceneManager->loadGlbFromBuffer((const uint8_t *)data, length, 1, keepData, priority, layer, loadResourcesAsync);
        return reinterpret_cast<TSceneAsset *>(asset);
    }

    EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_getCameraByName(TSceneManager *tSceneManager, EntityId entityId, const char *name)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return nullptr;
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

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_createGeometry(
        TSceneManager *tSceneManager,
        float *vertices,
        int numVertices,
        float *normals,
        int numNormals,
        float *uvs,
        int numUvs,
        uint16_t *indices,
        int numIndices,
        int primitiveType,
        TMaterialInstance **tMaterialInstances,
        int materialInstanceCount,
        bool keepData)
    {
        auto sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto castedNumVertices = static_cast<uint32_t>(numVertices);
        auto castedNumNormals = static_cast<uint32_t>(numNormals);
        auto castedNumUvs = static_cast<uint32_t>(numUvs);
        auto castedNumIndices = static_cast<uint32_t>(numIndices);
        auto castedPrimitiveType = static_cast<filament::RenderableManager::PrimitiveType>(primitiveType);
        auto materialInstances = reinterpret_cast<MaterialInstance **>(tMaterialInstances);

        auto *asset = sceneManager->createGeometry(
            vertices,
            castedNumVertices,
            normals,
            castedNumNormals,
            uvs,
            castedNumUvs,
            indices,
            castedNumIndices,
            castedPrimitiveType,
            materialInstances,
            materialInstanceCount,
            keepData);
        return reinterpret_cast<TSceneAsset *>(asset);
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_destroyMaterialInstance(TSceneManager *sceneManager, TMaterialInstance *instance)
    {
        ((SceneManager *)sceneManager)->destroy(reinterpret_cast<MaterialInstance *>(instance));
    }


    EMSCRIPTEN_KEEPALIVE int SceneManager_removeFromScene(TSceneManager *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->removeFromScene(entityId);
    }

    EMSCRIPTEN_KEEPALIVE int SceneManager_addToScene(TSceneManager *sceneManager, EntityId entityId)
    {
        return ((SceneManager *)sceneManager)->addToScene(entityId);
    }

    EMSCRIPTEN_KEEPALIVE void SceneManager_transformToUnitCube(TSceneManager *sceneManager, EntityId entityId)
    {
        ((SceneManager *)sceneManager)->transformToUnitCube(entityId);
    }

    EMSCRIPTEN_KEEPALIVE TAnimationManager *SceneManager_getAnimationManager(TSceneManager *tSceneManager)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *animationManager = sceneManager->getAnimationManager();
        return reinterpret_cast<TAnimationManager *>(animationManager);
    }

    EMSCRIPTEN_KEEPALIVE void *SceneManager_destroyAll(TSceneManager *tSceneManager)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        sceneManager->destroyAll();
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE void *SceneManager_destroyAsset(TSceneManager *tSceneManager, TSceneAsset *tSceneAsset)
    {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        sceneManager->destroy(sceneAsset);
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE TNameComponentManager *SceneManager_getNameComponentManager(TSceneManager *tSceneManager) { 
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return reinterpret_cast<TNameComponentManager*>(sceneManager->getNameComponentManager());
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_createGrid(TSceneManager *tSceneManager) {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        auto *grid = sceneManager->createGrid();
        return reinterpret_cast<TSceneAsset*>(grid);
    }

    EMSCRIPTEN_KEEPALIVE bool SceneManager_isGridEntity(TSceneManager *tSceneManager, EntityId entityId) {
        auto *sceneManager = reinterpret_cast<SceneManager *>(tSceneManager);
        return sceneManager->isGridEntity(utils::Entity::import(entityId));
    }

}