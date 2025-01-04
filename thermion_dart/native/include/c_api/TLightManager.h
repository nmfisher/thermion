#pragma once

#include "APIBoundaryTypes.h"
#include "APIExport.h"
#include "TMaterialInstance.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE void LightManager_setPosition(TLightManager *tLightManager, EntityId light, double x, double y, double z);
	EMSCRIPTEN_KEEPALIVE void LightManager_setDirection(TLightManager *tLightManager, EntityId light, double x, double y, double z);
	
#ifdef __cplusplus
}
#endif
