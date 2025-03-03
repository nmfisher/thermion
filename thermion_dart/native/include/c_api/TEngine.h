#ifndef _T_ENGINE_H
#define _T_ENGINE_H

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"

#include "ResourceBuffer.hpp"
#include "MathUtils.hpp"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine* tEngine, EntityId entityId);
EMSCRIPTEN_KEEPALIVE TTransformManager *Engine_getTransformManager(TEngine *engine);
EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *engine);
EMSCRIPTEN_KEEPALIVE TLightManager *Engine_getLightManager(TEngine *engine);
EMSCRIPTEN_KEEPALIVE TEntityManager *Engine_getEntityManager(TEngine *engine);

EMSCRIPTEN_KEEPALIVE TMaterial *Engine_buildMaterial(TEngine *tEngine, const uint8_t* materialData, size_t length);
EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterial(TEngine *tEngine, TMaterial *tMaterial);

#ifdef __cplusplus
}
#endif

#endif