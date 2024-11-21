#pragma once

#include "APIBoundaryTypes.h"
#include "ResourceBuffer.hpp"
#include "ThermionDartAPIUtils.h"
#include "TCamera.h"
#include "TMaterialInstance.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TGizmo* SceneManager_createGizmo(TSceneManager *tSceneManager, TView *tView, TScene *tScene);
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
		bool keepData);
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitMaterialInstance(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitFixedSizeMaterialInstance(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE bool SceneManager_setTransform(TSceneManager *sceneManager, EntityId entityId, const double *const transform);
	EMSCRIPTEN_KEEPALIVE void SceneManager_queueTransformUpdates(TSceneManager *sceneManager, EntityId* entities, const double* const transforms, int numEntities);
	EMSCRIPTEN_KEEPALIVE TCamera* SceneManager_findCameraByName(TSceneManager* tSceneManager, EntityId entity, const char* name);
	EMSCRIPTEN_KEEPALIVE void SceneManager_setVisibilityLayer(TSceneManager *tSceneManager, EntityId entity, int layer);
	EMSCRIPTEN_KEEPALIVE TScene* SceneManager_getScene(TSceneManager *tSceneManager);
	EMSCRIPTEN_KEEPALIVE EntityId SceneManager_loadGlbFromBuffer(TSceneManager *sceneManager, const uint8_t *const, size_t length, bool keepData, int priority, int layer, bool loadResourcesAsync);
	EMSCRIPTEN_KEEPALIVE bool SceneManager_setMorphAnimation(
		TSceneManager *sceneManager,
		EntityId entity,
		const float *const morphData,
		const uint32_t *const morphIndices,
		int numMorphTargets,
		int numFrames,
		float frameLengthInMs);
	
	EMSCRIPTEN_KEEPALIVE TCamera* SceneManager_createCamera(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE void SceneManager_destroyCamera(TSceneManager *sceneManager, TCamera* camera);
	EMSCRIPTEN_KEEPALIVE size_t SceneManager_getCameraCount(TSceneManager *sceneManager);	
	EMSCRIPTEN_KEEPALIVE TCamera* SceneManager_getCameraAt(TSceneManager *sceneManager, size_t index);	
	EMSCRIPTEN_KEEPALIVE void SceneManager_destroyMaterialInstance(TSceneManager *sceneManager, TMaterialInstance *instance);

#ifdef __cplusplus
}
#endif

