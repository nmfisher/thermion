#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include "c_api/TScene.h"

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndirectLight.h>
#include <filament/Material.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>

#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>

#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
#endif

        EMSCRIPTEN_KEEPALIVE void IndirectLight_setRotation(TIndirectLight *tIndirectLight, double *rotation)
        {
            auto *indirectLight = reinterpret_cast<filament::IndirectLight *>(tIndirectLight);
            const filament::math::mat3f fRotation {
                filament::math::float3 { static_cast<float>(rotation[0]), static_cast<float>(rotation[1]), static_cast<float>(rotation[2]) },
                filament::math::float3 { static_cast<float>(rotation[3]), static_cast<float>(rotation[4]), static_cast<float>(rotation[5]) },
                filament::math::float3 { static_cast<float>(rotation[6]), static_cast<float>(rotation[7]), static_cast<float>(rotation[8]) },  
            };
            indirectLight->setRotation(fRotation);
        }

#ifdef __cplusplus
    }
}
#endif
