#include <filament/MaterialInstance.h>
#include <math/mat4.h>
#include <math/vec4.h>
#include <math/vec2.h>

#include "Log.hpp"
#include "TMaterialInstance.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance *materialInstance, bool enabled)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setDepthWrite(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance *materialInstance, bool enabled)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setDepthCulling(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat4(TMaterialInstance *tMaterialInstance, const char *propertyName, double x, double y, double z, double w)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            filament::math::float4 data{static_cast<float>(x), static_cast<float>(y), static_cast<float>(z), static_cast<float>(w)};
            materialInstance->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance *materialInstance, const char *propertyName, double x, double y)
        {
            filament::math::float2 data{static_cast<float>(x), static_cast<float>(y)};
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat(TMaterialInstance *materialInstance, const char *propertyName, double value)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, static_cast<float>(value));
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterInt(TMaterialInstance *materialInstance, const char *propertyName, int value)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, value);
        }
#ifdef __cplusplus
    }
}
#endif
