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

	// Shadow options struct (C-compatible version of filament::LightManager::ShadowOptions)
	struct TShadowOptions {
		uint32_t mapSize;
		uint8_t shadowCascades;
		float cascadeSplitPositions[3];
		float constantBias;
		float normalBias;
		float shadowFar;
		float shadowNearHint;
		float shadowFarHint;
		bool stable;
		bool lispsm;
		float polygonOffsetConstant;
		float polygonOffsetSlope;
		bool screenSpaceContactShadows;
		uint8_t stepCount;
		float maxShadowDistance;
		bool vsmElvsm;
		float vsmBlurWidth;
		float shadowBulbRadius;
		float penumbraScale;
		float penumbraRatioScale;
		float maxPenumbraRatio;
		float maxSearchRadius;
		float transformX;
		float transformY;
		float transformZ;
		float transformW;
	};
	typedef struct TShadowOptions TShadowOptions;

	// Entity and light management
	EMSCRIPTEN_KEEPALIVE int LightManager_createLight(TEngine *tEngine, TLightManager *tLightManager, TLightType tLightTtype);
	EMSCRIPTEN_KEEPALIVE void LightManager_destroyLight(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE bool LightManager_hasComponent(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE int LightManager_getType(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE bool LightManager_isDirectional(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE bool LightManager_isPointLight(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE bool LightManager_isSpotLight(TLightManager *tLightManager, EntityId entity);

	// Position and direction
	EMSCRIPTEN_KEEPALIVE void LightManager_setPosition(TLightManager *tLightManager, EntityId light, double x, double y, double z);
	EMSCRIPTEN_KEEPALIVE double3 LightManager_getPosition(TLightManager *tLightManager, EntityId light);
	EMSCRIPTEN_KEEPALIVE void LightManager_setDirection(TLightManager *tLightManager, EntityId light, double x, double y, double z);
	EMSCRIPTEN_KEEPALIVE double3 LightManager_getDirection(TLightManager *tLightManager, EntityId light);

	// Color and intensity
	EMSCRIPTEN_KEEPALIVE void LightManager_setColor(TLightManager *tLightManager, EntityId entity, double r, double g, double b);
	EMSCRIPTEN_KEEPALIVE void LightManager_setColorTemperature(TLightManager *tLightManager, EntityId entity, double colorTemperature);
	EMSCRIPTEN_KEEPALIVE double3 LightManager_getColor(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setIntensity(TLightManager *tLightManager, EntityId entity, double intensity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setIntensityCandela(TLightManager *tLightManager, EntityId entity, double intensity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setIntensityWatts(TLightManager *tLightManager, EntityId entity, double watts, double efficiency);
	EMSCRIPTEN_KEEPALIVE float LightManager_getIntensity(TLightManager *tLightManager, EntityId entity);

	// Falloff
	EMSCRIPTEN_KEEPALIVE void LightManager_setFalloff(TLightManager *tLightManager, EntityId entity, double falloff);
	EMSCRIPTEN_KEEPALIVE float LightManager_getFalloff(TLightManager *tLightManager, EntityId entity);

	// Spot light cone
	EMSCRIPTEN_KEEPALIVE void LightManager_setSpotLightCone(TLightManager *tLightManager, EntityId entity, double inner, double outer);
	EMSCRIPTEN_KEEPALIVE float LightManager_getSpotLightOuterCone(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE float LightManager_getSpotLightInnerCone(TLightManager *tLightManager, EntityId entity);

	// Sun-specific methods
	EMSCRIPTEN_KEEPALIVE void LightManager_setSunAngularRadius(TLightManager *tLightManager, EntityId entity, float angularRadius);
	EMSCRIPTEN_KEEPALIVE float LightManager_getSunAngularRadius(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setSunHaloSize(TLightManager *tLightManager, EntityId entity, float haloSize);
	EMSCRIPTEN_KEEPALIVE float LightManager_getSunHaloSize(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setSunHaloFalloff(TLightManager *tLightManager, EntityId entity, float haloFalloff);
	EMSCRIPTEN_KEEPALIVE float LightManager_getSunHaloFalloff(TLightManager *tLightManager, EntityId entity);

	// Shadow options
	EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCaster(TLightManager *tLightManager, EntityId entity, bool enabled);
	EMSCRIPTEN_KEEPALIVE bool LightManager_isShadowCaster(TLightManager *tLightManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void LightManager_setShadowOptions(TLightManager *tLightManager, EntityId entity, TShadowOptions options);
	EMSCRIPTEN_KEEPALIVE TShadowOptions LightManager_getShadowOptions(TLightManager *tLightManager, EntityId entity);

	// Light channels
	EMSCRIPTEN_KEEPALIVE void LightManager_setLightChannel(TLightManager *tLightManager, EntityId entity, unsigned int channel, bool enable);
	EMSCRIPTEN_KEEPALIVE bool LightManager_getLightChannel(TLightManager *tLightManager, EntityId entity, unsigned int channel);

	// Shadow cascades utilities
	EMSCRIPTEN_KEEPALIVE void LightManager_computeUniformSplits(float* splitPositions, uint8_t cascades);
	EMSCRIPTEN_KEEPALIVE void LightManager_computeLogSplits(float* splitPositions, uint8_t cascades, float near, float far);
	EMSCRIPTEN_KEEPALIVE void LightManager_computePracticalSplits(float* splitPositions, uint8_t cascades, float near, float far, float lambda);

	// Color temperature conversion utilities
	EMSCRIPTEN_KEEPALIVE double LightManager_rgbToColorTemperature(double r, double g, double b);

#ifdef __cplusplus
}
#endif
