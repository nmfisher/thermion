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
    // Native handles refer to constructed mat4 objects; no boundary copy.
    EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformNative(TTransformManager *manager, EntityId entity, TMat4 *matrix);
    // Buffers contain 16 column-major doubles, borrowed only during the call.
    // Missing transform components produce a zero matrix, matching the value getters.
    EMSCRIPTEN_KEEPALIVE void TransformManager_getLocalTransformInto(TTransformManager *manager, EntityId entity, double *out16);
    EMSCRIPTEN_KEEPALIVE void TransformManager_getWorldTransformInto(TTransformManager *manager, EntityId entity, double *out16);
    EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformFromBuffer(TTransformManager *manager, EntityId entity, const double *matrix16);
	EMSCRIPTEN_KEEPALIVE bool TransformManager_transformToUnitCube(TTransformManager *tTransformManager, EntityId entityId, Aabb3 boundingBox);
	EMSCRIPTEN_KEEPALIVE void TransformManager_setParent(TTransformManager *tTransformManager, EntityId child, EntityId parent, bool preserveScaling);
	EMSCRIPTEN_KEEPALIVE EntityId TransformManager_getParent(TTransformManager *tTransformManager, EntityId child);
	EMSCRIPTEN_KEEPALIVE EntityId TransformManager_getAncestor(TTransformManager *tTransformManager, EntityId childEntityId);
	EMSCRIPTEN_KEEPALIVE void TransformManager_createComponent(TTransformManager *tTransformManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void TransformManager_removeComponent(TTransformManager *tTransformManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE bool TransformManager_hasComponent(TTransformManager *tTransformManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE bool TransformManager_empty(TTransformManager *tTransformManager);
	EMSCRIPTEN_KEEPALIVE int TransformManager_getComponentCount(TTransformManager *tTransformManager);
	EMSCRIPTEN_KEEPALIVE int TransformManager_getChildCount(TTransformManager *tTransformManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void TransformManager_getChildren(TTransformManager *tTransformManager, EntityId entityId, EntityId *children, int count);
	EMSCRIPTEN_KEEPALIVE void TransformManager_openLocalTransformTransaction(TTransformManager *tTransformManager);
	EMSCRIPTEN_KEEPALIVE void TransformManager_commitLocalTransformTransaction(TTransformManager *tTransformManager);

	
#ifdef __cplusplus
}
#endif
