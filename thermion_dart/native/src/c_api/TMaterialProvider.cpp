#include <filament/MaterialInstance.h>
#include <gltfio/MaterialProvider.h>
#include <math/mat4.h>
#include <math/vec4.h>
#include <math/vec2.h>

#include "Log.hpp"
#include "c_api/TMaterialProvider.h"
#include "c_api/TMaterialInstance.h"

#ifdef __cplusplus
namespace thermion
{
    using namespace filament;
    extern "C"
    {
#endif

        EMSCRIPTEN_KEEPALIVE TMaterialInstance *MaterialProvider_createMaterialInstance(TMaterialProvider *tMaterialProvider, TMaterialKey *materialConfig)
        {
            gltfio::MaterialKey config;
            gltfio::UvMap uvMap;
            memset(&config, 0, sizeof(gltfio::MaterialKey));

            // Set and log each field
            config.unlit = materialConfig->unlit;
            config.doubleSided = materialConfig->doubleSided;
            config.useSpecularGlossiness = materialConfig->useSpecularGlossiness;
            config.alphaMode = static_cast<filament::gltfio::AlphaMode>(materialConfig->alphaMode);
            config.hasBaseColorTexture = materialConfig->hasBaseColorTexture;
            config.hasClearCoat = materialConfig->hasClearCoat;
            config.hasClearCoatNormalTexture = materialConfig->hasClearCoatNormalTexture;
            config.hasClearCoatRoughnessTexture = materialConfig->hasClearCoatRoughnessTexture;
            config.hasEmissiveTexture = materialConfig->hasEmissiveTexture;
            config.hasIOR = materialConfig->hasIOR;
            config.hasMetallicRoughnessTexture = materialConfig->hasMetallicRoughnessTexture;
            config.hasNormalTexture = materialConfig->hasNormalTexture;
            config.hasOcclusionTexture = materialConfig->hasOcclusionTexture;
            config.hasSheen = materialConfig->hasSheen;
            config.hasSheenColorTexture = materialConfig->hasSheenColorTexture;
            config.hasSheenRoughnessTexture = materialConfig->hasSheenRoughnessTexture;
            config.hasTextureTransforms = materialConfig->hasTextureTransforms;
            config.hasTransmission = materialConfig->hasTransmission;
            config.hasTransmissionTexture = materialConfig->hasTransmissionTexture;
            config.hasVolume = materialConfig->hasVolume;
            config.hasVolumeThicknessTexture = materialConfig->hasVolumeThicknessTexture;
            config.baseColorUV = materialConfig->baseColorUV;
            config.hasVertexColors = materialConfig->hasVertexColors;

            auto *materialProvider = reinterpret_cast<gltfio::MaterialProvider *>(tMaterialProvider);
            auto materialInstance = materialProvider->createMaterialInstance(&config, &uvMap);
            return reinterpret_cast<TMaterialInstance *>(materialInstance);
        }
#ifdef __cplusplus
    }
}
#endif
