#pragma once

#include "APIBoundaryTypes.h"
#include "APIExport.h"
#include "TMaterialInstance.h"

#ifdef __cplusplus
extern "C"
{
#endif

	enum TLightType {
		LIGHT_TYPE_SUN,
		LIGHT_TYPE_DIRECTIONAL,
		LIGHT_TYPE_POINT,
		LIGHT_TYPE_FOCUSED_SPOT,
		LIGHT_TYPE_SPOT
	};
	typedef enum TLightType TLightType;

	EMSCRIPTEN_KEEPALIVE void LightManager_setPosition(TLightManager *tLightManager, EntityId light, double x, double y, double z);
	EMSCRIPTEN_KEEPALIVE void LightManager_setDirection(TLightManager *tLightManager, EntityId light, double x, double y, double z);
	EMSCRIPTEN_KEEPALIVE int LightManager_createLight(TEngine *tEngine, TLightManager *tLightManager, TLightType tLightTtype);
	EMSCRIPTEN_KEEPALIVE void LightManager_destroyLight(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setColor(TLightManager *tLightManager, EntityId entity, float colorTemperature);
	EMSCRIPTEN_KEEPALIVE void LightManager_setIntensity(TLightManager *tLightManager, EntityId entity, double intensity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setFalloff(TLightManager *tLightManager, EntityId entity, double falloff);
	EMSCRIPTEN_KEEPALIVE void LightManager_setSpotLightCone(TLightManager *tLightManager, EntityId entity, double inner, double outer);
	EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCaster(TLightManager *tLightManager, EntityId entity, bool enabled);

#ifdef __cplusplus
}
#endif
