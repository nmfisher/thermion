 

#include "c_api/TSkybox.h"

#include <math/mat4.h>
#include <filament/Skybox.h>

#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
#endif

        EMSCRIPTEN_KEEPALIVE void Skybox_setColor(TSkybox *tSkybox, double r, double g, double b, double a)
        {
            auto *skybox = reinterpret_cast<filament::Skybox *>(tSkybox);
            skybox->setColor(filament::math::float4 { static_cast<float>(r), static_cast<float>(g), static_cast<float>(b), static_cast<float>(a) } );
        }

        EMSCRIPTEN_KEEPALIVE void Skybox_setLayerMask(TSkybox *tSkybox, uint8_t select, uint8_t values)
        {
            auto *skybox = reinterpret_cast<filament::Skybox *>(tSkybox);
            skybox->setLayerMask(select, values);
        }

        EMSCRIPTEN_KEEPALIVE uint8_t Skybox_getLayerMask(TSkybox *tSkybox)
        {
            auto *skybox = reinterpret_cast<filament::Skybox *>(tSkybox);
            return skybox->getLayerMask();
        }

        EMSCRIPTEN_KEEPALIVE float Skybox_getIntensity(TSkybox *tSkybox)
        {
            auto *skybox = reinterpret_cast<filament::Skybox *>(tSkybox);
            return skybox->getIntensity();
        }

        EMSCRIPTEN_KEEPALIVE TTexture *Skybox_getTexture(TSkybox *tSkybox)
        {
            auto *skybox = reinterpret_cast<filament::Skybox *>(tSkybox);
            return reinterpret_cast<TTexture *>(const_cast<filament::Texture *>(skybox->getTexture()));
        }

#ifdef __cplusplus
    }
}
#endif
