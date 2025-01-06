#include <filament/LightManager.h>
#include <utils/Entity.h>

#include "c_api/APIExport.h"
#include "Log.hpp"
#include "c_api/TLightManager.h"

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

EMSCRIPTEN_KEEPALIVE int LightManager_createLight(TLightManager *tLightManager, EntityId entity, int type) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
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
    return false;
    // auto result = builder.build(*lm->getEngine(), utils::Entity::import(entity));
    // return result == filament::LightManager::Result::Success ? 0 : -1;
}

EMSCRIPTEN_KEEPALIVE void LightManager_destroyLight(TLightManager *tLightManager, EntityId entity) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    lm->destroy(utils::Entity::import(entity));
}

EMSCRIPTEN_KEEPALIVE void LightManager_setColor(TLightManager *tLightManager, EntityId entity, double r, double g, double b) {
    auto* lm = reinterpret_cast<filament::LightManager*>(tLightManager);
    auto instance = lm->getInstance(utils::Entity::import(entity));
    if (instance.isValid()) {
        lm->setColor(instance, {static_cast<float>(r), static_cast<float>(g), static_cast<float>(b)});
    }
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

} // extern "C"
