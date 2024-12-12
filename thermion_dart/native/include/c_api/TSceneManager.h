#pragma once

#include "APIBoundaryTypes.h"
#include "ResourceBuffer.hpp"
#include "MathUtils.hpp"
#include "TCamera.h"
#include "TMaterialInstance.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TGizmo *SceneManager_createGizmo(TSceneManager *tSceneManager, TView *tView, TScene *tScene, TGizmoType tGizmoType);
	EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_createGeometry(
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
		TMaterialInstance **materialInstances,
		int materialInstanceCount,
		bool keepData);
	EMSCRIPTEN_KEEPALIVE TMaterialProvider *SceneManager_getUbershaderMaterialProvider(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE TMaterialProvider *SceneManager_getUnlitMaterialProvider(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitMaterialInstance(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitFixedSizeMaterialInstance(TSceneManager *sceneManager);

	EMSCRIPTEN_KEEPALIVE void SceneManager_queueTransformUpdates(TSceneManager *sceneManager, EntityId *entities, const double *const transforms, int numEntities);
	EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_findCameraByName(TSceneManager *tSceneManager, EntityId entity, const char *name);
	EMSCRIPTEN_KEEPALIVE void SceneManager_setVisibilityLayer(TSceneManager *tSceneManager, EntityId entity, int layer);
	EMSCRIPTEN_KEEPALIVE TScene *SceneManager_getScene(TSceneManager *tSceneManager);


	EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_createCamera(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE void SceneManager_destroyCamera(TSceneManager *sceneManager, TCamera *camera);
	EMSCRIPTEN_KEEPALIVE size_t SceneManager_getCameraCount(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE TCamera *SceneManager_getCameraAt(TSceneManager *sceneManager, size_t index);
	EMSCRIPTEN_KEEPALIVE void SceneManager_destroyMaterialInstance(TSceneManager *sceneManager, TMaterialInstance *instance);
	
	EMSCRIPTEN_KEEPALIVE Aabb3 SceneManager_getRenderableBoundingBox(TSceneManager *tSceneManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE int SceneManager_addToScene(TSceneManager *tSceneManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE int SceneManager_removeFromScene(TSceneManager *tSceneManager, EntityId entity);

	EMSCRIPTEN_KEEPALIVE void SceneManager_transformToUnitCube(TSceneManager *sceneManager, EntityId asset);
	EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_loadGlbFromBuffer(TSceneManager *tSceneManager, const uint8_t *const, size_t length, bool keepData, int priority, int layer, bool loadResourcesAsync);
	EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_loadGlb(TSceneManager *sceneManager, const char *assetPath, int numInstances, bool keepData);
	EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_loadGltf(TSceneManager *sceneManager, const char *assetPath, const char *relativePath, bool keepData);
	

	EMSCRIPTEN_KEEPALIVE TAnimationManager *SceneManager_getAnimationManager(TSceneManager *tSceneManager);
	EMSCRIPTEN_KEEPALIVE void *SceneManager_destroyAll(TSceneManager *tSceneManager);
	EMSCRIPTEN_KEEPALIVE void *SceneManager_destroyAsset(TSceneManager *tSceneManager, TSceneAsset *sceneAsset);
	EMSCRIPTEN_KEEPALIVE TNameComponentManager *SceneManager_getNameComponentManager(TSceneManager *tSceneManager);

	EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneManager_createGrid(TSceneManager *tSceneManager);
	EMSCRIPTEN_KEEPALIVE bool SceneManager_isGridEntity(TSceneManager *tSceneManager, EntityId entityId);


#ifdef __cplusplus
}
#endif
