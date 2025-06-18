#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include "c_api/TSkybox.h"

#include <filament/math/mat4.h>
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
        

#ifdef __cplusplus
    }
}
#endif
