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

        EMSCRIPTEN_KEEPALIVE void IndirectLight_setRotation(TIndirectLight *tIndirectLight, double3x3 rotation)
        {
            auto *indirectLight = reinterpret_cast<filament::IndirectLight *>(tIndirectLight);
            const filament::math::mat3f fRotation {
                filament::math::float3 { rotation.col1.x, rotation.col1.y, rotation.col1.z },
                filament::math::float3 { rotation.col2.x, rotation.col2.y, rotation.col2.z },
                filament::math::float3 { rotation.col3.x, rotation.col3.y, rotation.col3.z },
            };
            indirectLight->setRotation(fRotation);
        }

#ifdef __cplusplus
    }
}
#endif
