#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE double4x4 TransformManager_getLocalTransform(TTransformManager *tTransformManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE double4x4 TransformManager_getWorldTransform(TTransformManager *tTransformManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void TransformManager_setTransform(TTransformManager *tTransformManager, EntityId entityId, double4x4 transform);
	EMSCRIPTEN_KEEPALIVE bool TransformManager_transformToUnitCube(TTransformManager *tTransformManager, EntityId entityId, Aabb3 boundingBox);
	EMSCRIPTEN_KEEPALIVE void TransformManager_setParent(TTransformManager *tTransformManager, EntityId child, EntityId parent, bool preserveScaling);
	EMSCRIPTEN_KEEPALIVE EntityId TransformManager_getParent(TTransformManager *tTransformManager, EntityId child);
	EMSCRIPTEN_KEEPALIVE EntityId TransformManager_getAncestor(TTransformManager *tTransformManager, EntityId childEntityId);
	EMSCRIPTEN_KEEPALIVE void TransformManager_createComponent(TTransformManager *tTransformManager, EntityId entity);

	
#ifdef __cplusplus
}
#endif

