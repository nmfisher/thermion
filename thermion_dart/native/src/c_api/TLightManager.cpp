#include <filament/LightManager.h>

#include <utils/Entity.h>
#include <utils/EntityManager.h>

#include "c_api/APIExport.h"
#include "c_api/TLightManager.h"

#include "Log.hpp"

extern "C" {

EMSCRIPTEN_KEEPALIVE void LightManager_setPosition(TLightManager *tLightManager, EntityId light, double x, double y, double z) {
    auto lightManager = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lightManager->getInstance(utils::Entity::import(light));
    if (!instance.isValid()) {
        Log("Warning: invalid light instance");
        return;
    }
    lightManager->setPosition(instance, filament::math::float3 { static_cast<float>(x), static_cast<float>(y), static_cast<float>(z) });
}

EMSCRIPTEN_KEEPALIVE void LightManager_setDirection(TLightManager *tLightManager, EntityId light, double x, double y, double z) {
    auto lightManager = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lightManager->getInstance(utils::Entity::import(light));
    if (!instance.isValid()) {
        Log("Warning: invalid light instance");
        return;
    }
    lightManager->setDirection(instance, filament::math::float3 { static_cast<float>(x), static_cast<float>(y), static_cast<float>(z) });
}

EMSCRIPTEN_KEEPALIVE int LightManager_createLight(TEngine *tEngine, TLightManager *tLightManager, TLightType type) {
    auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
    auto *lightManager = reinterpret_cast<filament::LightManager*>(tLightManager);
    filament::LightManager::Type lightType;
    
    switch (type) {
        case 0: lightType = filament::LightManager::Type::SUN; break;
        case 1: lightType = filament::LightManager::Type::DIRECTIONAL; break;
        case 2: lightType = filament::LightManager::Type::POINT; break;
        case 3: lightType = filament::LightManager::Type::FOCUSED_SPOT; break;
        case 4: lightType = filament::LightManager::Type::SPOT; break;
        default: return -1;
    }

    filament::LightManager::Builder builder(lightType);
    auto &em = utils::EntityManager::get();
    auto entity = em.create();
    auto result = builder.build(*engine, entity);
    if(result != filament::LightManager::Builder::Result::Success) { 
        Log("Failed to create light");
    }
    return utils::Entity::smuggle(entity);
}

EMSCRIPTEN_KEEPALIVE void LightManager_destroyLight(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    lm->destroy(utils::Entity::import(entity));
}

EMSCRIPTEN_KEEPALIVE void LightManager_setColor(TLightManager *tLightManager, EntityId entity, double r, double g, double b) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto color = filament::LinearColor{static_cast<float>(r), static_cast<float>(g), static_cast<float>(b)};

    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        ERROR("Light instance invalid");
        return;
    }
    lm->setColor(instance, color);
    Log("Set light color to %f %f %f (RGB)", color.r, color.g, color.b);
}

EMSCRIPTEN_KEEPALIVE void LightManager_setColorTemperature(TLightManager *tLightManager, EntityId entity, double colorTemperature) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto color = filament::Color::cct(colorTemperature);

    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        ERROR("Light instance invalid");
        return;
    }
    lm->setColor(instance, color);
    Log("Set light color to %f %f %f (%fK)", color.r, color.g, color.b, colorTemperature);
}


EMSCRIPTEN_KEEPALIVE void LightManager_setIntensity(TLightManager *tLightManager, EntityId entity, double intensity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setIntensity(instance, static_cast<float>(intensity));
    }
}

EMSCRIPTEN_KEEPALIVE void LightManager_setFalloff(TLightManager *tLightManager, EntityId entity, double falloff) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setFalloff(instance, static_cast<float>(falloff));
    }
}

EMSCRIPTEN_KEEPALIVE void LightManager_setSpotLightCone(TLightManager *tLightManager, EntityId entity, double inner, double outer) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setSpotLightCone(instance, static_cast<float>(inner), static_cast<float>(outer));
    }
}

EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCaster(TLightManager *tLightManager, EntityId entity, bool enabled) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setShadowCaster(instance, enabled);
    }
}

// Entity and light management
EMSCRIPTEN_KEEPALIVE bool LightManager_hasComponent(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    return lm->hasComponent(utils::Entity::import(entity));
}

EMSCRIPTEN_KEEPALIVE int LightManager_getType(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        return -1;
    }
    return static_cast<int>(lm->getType(instance));
}

EMSCRIPTEN_KEEPALIVE bool LightManager_isDirectional(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        return false;
    }
    return lm->isDirectional(instance);
}

EMSCRIPTEN_KEEPALIVE bool LightManager_isPointLight(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        return false;
    }
    return lm->isPointLight(instance);
}

EMSCRIPTEN_KEEPALIVE bool LightManager_isSpotLight(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        return false;
    }
    return lm->isSpotLight(instance);
}

// Position and direction getters
EMSCRIPTEN_KEEPALIVE double3 LightManager_getPosition(TLightManager *tLightManager, EntityId light) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(light));
    if (instance.isValid()) {
        const auto& pos = lm->getPosition(instance);
        return double3 { static_cast<double>(pos.x), static_cast<double>(pos.y), static_cast<double>(pos.z) };
    }
    return double3 { 0.0, 0.0, 0.0 };
}

EMSCRIPTEN_KEEPALIVE double3 LightManager_getDirection(TLightManager *tLightManager, EntityId light) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(light));
    if (instance.isValid()) {
        const auto& dir = lm->getDirection(instance);
        return double3 { static_cast<double>(dir.x), static_cast<double>(dir.y), static_cast<double>(dir.z) };
    }
    return double3 { 0.0, 0.0, 0.0 };
}

// Color getter
EMSCRIPTEN_KEEPALIVE double3 LightManager_getColor(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        const auto& color = lm->getColor(instance);
        return double3 { static_cast<double>(color.r), static_cast<double>(color.g), static_cast<double>(color.b) };
    }
    return double3 { 0.0, 0.0, 0.0 };
}

// Intensity variants
EMSCRIPTEN_KEEPALIVE void LightManager_setIntensityCandela(TLightManager *tLightManager, EntityId entity, double intensity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setIntensityCandela(instance, static_cast<float>(intensity));
    }
}

EMSCRIPTEN_KEEPALIVE void LightManager_setIntensityWatts(TLightManager *tLightManager, EntityId entity, double watts, double efficiency) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setIntensity(instance, static_cast<float>(watts), static_cast<float>(efficiency));
    }
}

EMSCRIPTEN_KEEPALIVE float LightManager_getIntensity(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getIntensity(instance);
    }
    return 0.0f;
}

// Falloff getter
EMSCRIPTEN_KEEPALIVE float LightManager_getFalloff(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getFalloff(instance);
    }
    return 0.0f;
}

// Spot light cone getters
EMSCRIPTEN_KEEPALIVE float LightManager_getSpotLightOuterCone(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getSpotLightOuterCone(instance);
    }
    return 0.0f;
}

EMSCRIPTEN_KEEPALIVE float LightManager_getSpotLightInnerCone(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getSpotLightInnerCone(instance);
    }
    return 0.0f;
}

// Sun-specific methods
EMSCRIPTEN_KEEPALIVE void LightManager_setSunAngularRadius(TLightManager *tLightManager, EntityId entity, float angularRadius) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setSunAngularRadius(instance, angularRadius);
    }
}

EMSCRIPTEN_KEEPALIVE float LightManager_getSunAngularRadius(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getSunAngularRadius(instance);
    }
    return 0.0f;
}

EMSCRIPTEN_KEEPALIVE void LightManager_setSunHaloSize(TLightManager *tLightManager, EntityId entity, float haloSize) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setSunHaloSize(instance, haloSize);
    }
}

EMSCRIPTEN_KEEPALIVE float LightManager_getSunHaloSize(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getSunHaloSize(instance);
    }
    return 0.0f;
}

EMSCRIPTEN_KEEPALIVE void LightManager_setSunHaloFalloff(TLightManager *tLightManager, EntityId entity, float haloFalloff) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setSunHaloFalloff(instance, haloFalloff);
    }
}

EMSCRIPTEN_KEEPALIVE float LightManager_getSunHaloFalloff(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getSunHaloFalloff(instance);
    }
    return 0.0f;
}

// Shadow caster getter
EMSCRIPTEN_KEEPALIVE bool LightManager_isShadowCaster(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->isShadowCaster(instance);
    }
    return false;
}

// Shadow options
EMSCRIPTEN_KEEPALIVE void LightManager_setShadowOptions(TLightManager *tLightManager, EntityId entity, TShadowOptions options) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        return;
    }

    filament::LightManager::ShadowOptions shadowOpts;
    shadowOpts.mapSize = options.mapSize;
    shadowOpts.shadowCascades = options.shadowCascades;
    shadowOpts.cascadeSplitPositions[0] = options.cascadeSplitPositions[0];
    shadowOpts.cascadeSplitPositions[1] = options.cascadeSplitPositions[1];
    shadowOpts.cascadeSplitPositions[2] = options.cascadeSplitPositions[2];
    shadowOpts.constantBias = options.constantBias;
    shadowOpts.normalBias = options.normalBias;
    shadowOpts.shadowFar = options.shadowFar;
    shadowOpts.shadowNearHint = options.shadowNearHint;
    shadowOpts.shadowFarHint = options.shadowFarHint;
    shadowOpts.stable = options.stable;
    shadowOpts.lispsm = options.lispsm;
    shadowOpts.polygonOffsetConstant = options.polygonOffsetConstant;
    shadowOpts.polygonOffsetSlope = options.polygonOffsetSlope;
    shadowOpts.screenSpaceContactShadows = options.screenSpaceContactShadows;
    shadowOpts.stepCount = options.stepCount;
    shadowOpts.maxShadowDistance = options.maxShadowDistance;
    shadowOpts.vsm.elvsm = options.vsmElvsm;
    shadowOpts.vsm.blurWidth = options.vsmBlurWidth;
    shadowOpts.shadowBulbRadius = options.shadowBulbRadius;
    shadowOpts.penumbraScale = options.penumbraScale;
    shadowOpts.penumbraRatioScale = options.penumbraRatioScale;
    shadowOpts.maxPenumbraRatio = options.maxPenumbraRatio;
    shadowOpts.maxSearchRadius = options.maxSearchRadius;
    shadowOpts.transform = filament::math::quatf{
        options.transformW,
        options.transformX,
        options.transformY,
        options.transformZ
    };

    lm->setShadowOptions(instance, shadowOpts);
}

EMSCRIPTEN_KEEPALIVE TShadowOptions LightManager_getShadowOptions(TLightManager *tLightManager, EntityId entity) {
    TShadowOptions outOptions = {};

    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (!instance.isValid()) {
        return outOptions;
    }

    const auto& shadowOpts = lm->getShadowOptions(instance);
    outOptions.mapSize = shadowOpts.mapSize;
    outOptions.shadowCascades = shadowOpts.shadowCascades;
    outOptions.cascadeSplitPositions[0] = shadowOpts.cascadeSplitPositions[0];
    outOptions.cascadeSplitPositions[1] = shadowOpts.cascadeSplitPositions[1];
    outOptions.cascadeSplitPositions[2] = shadowOpts.cascadeSplitPositions[2];
    outOptions.constantBias = shadowOpts.constantBias;
    outOptions.normalBias = shadowOpts.normalBias;
    outOptions.shadowFar = shadowOpts.shadowFar;
    outOptions.shadowNearHint = shadowOpts.shadowNearHint;
    outOptions.shadowFarHint = shadowOpts.shadowFarHint;
    outOptions.stable = shadowOpts.stable;
    outOptions.lispsm = shadowOpts.lispsm;
    outOptions.polygonOffsetConstant = shadowOpts.polygonOffsetConstant;
    outOptions.polygonOffsetSlope = shadowOpts.polygonOffsetSlope;
    outOptions.screenSpaceContactShadows = shadowOpts.screenSpaceContactShadows;
    outOptions.stepCount = shadowOpts.stepCount;
    outOptions.maxShadowDistance = shadowOpts.maxShadowDistance;
    outOptions.vsmElvsm = shadowOpts.vsm.elvsm;
    outOptions.vsmBlurWidth = shadowOpts.vsm.blurWidth;
    outOptions.shadowBulbRadius = shadowOpts.shadowBulbRadius;
    outOptions.penumbraScale = shadowOpts.penumbraScale;
    outOptions.penumbraRatioScale = shadowOpts.penumbraRatioScale;
    outOptions.maxPenumbraRatio = shadowOpts.maxPenumbraRatio;
    outOptions.maxSearchRadius = shadowOpts.maxSearchRadius;
    outOptions.transformW = shadowOpts.transform.w;
    outOptions.transformX = shadowOpts.transform.x;
    outOptions.transformY = shadowOpts.transform.y;
    outOptions.transformZ = shadowOpts.transform.z;

    return outOptions;
}

// Light channels
EMSCRIPTEN_KEEPALIVE void LightManager_setLightChannel(TLightManager *tLightManager, EntityId entity, unsigned int channel, bool enable) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setLightChannel(instance, channel, enable);
    }
}

EMSCRIPTEN_KEEPALIVE bool LightManager_getLightChannel(TLightManager *tLightManager, EntityId entity, unsigned int channel) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        return lm->getLightChannel(instance, channel);
    }
    return false;
}

// Shadow cascades utilities
EMSCRIPTEN_KEEPALIVE void LightManager_computeUniformSplits(float* splitPositions, uint8_t cascades) {
    filament::LightManager::ShadowCascades::computeUniformSplits(splitPositions, cascades);
}

EMSCRIPTEN_KEEPALIVE void LightManager_computeLogSplits(float* splitPositions, uint8_t cascades, float near, float far) {
    filament::LightManager::ShadowCascades::computeLogSplits(splitPositions, cascades, near, far);
}

EMSCRIPTEN_KEEPALIVE void LightManager_computePracticalSplits(float* splitPositions, uint8_t cascades, float near, float far, float lambda) {
    filament::LightManager::ShadowCascades::computePracticalSplits(splitPositions, cascades, near, far, lambda);
}

// Color temperature conversion utility
EMSCRIPTEN_KEEPALIVE double3 LightManager_colorTemperatureToRgb(double colorTemperature) {
    auto color = filament::Color::cct(colorTemperature);
    return double3 { static_cast<double>(color.r), static_cast<double>(color.g), static_cast<double>(color.b) };
}


} // extern "C"
