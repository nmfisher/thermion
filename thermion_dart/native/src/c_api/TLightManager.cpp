
#include <filament/LightManager.h>

#include <utils/Entity.h>

#include "c_api/APIExport.h"
#include "Log.hpp"

extern "C"
{

#include "c_api/TLightManager.h"

    EMSCRIPTEN_KEEPALIVE void  LightManager_setPosition(TLightManager *tLightManager, EntityId light, double x, double y, double z) {
        auto lightManager = reinterpret_cast<filament::LightManager*>(tLightManager);
        auto instance = lightManager->getInstance(utils::Entity::import(light));
        if(!instance.isValid()) {
            Log("Warning: invalid light instance");
            return;
        }
        lightManager->setPosition(instance, filament::math::float3 { x, y, z });
    }

	EMSCRIPTEN_KEEPALIVE void LightManager_setDirection(TLightManager *tLightManager, EntityId light, double x, double y, double z) {
        auto lightManager = reinterpret_cast<filament::LightManager*>(tLightManager);
        auto instance = lightManager->getInstance(utils::Entity::import(light));
        if(!instance.isValid()) {
            Log("Warning: invalid light instance");
            return;
        }
        lightManager->setPosition(instance, filament::math::float3 { x, y, z });
    }
}