#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

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
        
        EMSCRIPTEN_KEEPALIVE TMaterialInstance *MaterialProvider_createMaterialInstance(
            TMaterialProvider *tMaterialProvider, 
            bool doubleSided,
            bool unlit,
            bool hasVertexColors,
            bool hasBaseColorTexture,
            bool hasNormalTexture,
            bool hasOcclusionTexture,
            bool hasEmissiveTexture,
            bool useSpecularGlossiness,
            int alphaMode,
            bool enableDiagnostics,
            bool hasMetallicRoughnessTexture,
            uint8_t metallicRoughnessUV,
            bool hasSpecularGlossinessTexture,
            uint8_t specularGlossinessUV,
            uint8_t baseColorUV,
            bool hasClearCoatTexture,
            uint8_t clearCoatUV,
            bool hasClearCoatRoughnessTexture,
            uint8_t clearCoatRoughnessUV,
            bool hasClearCoatNormalTexture,
            uint8_t clearCoatNormalUV,
            bool hasClearCoat,
            bool hasTransmission,
            bool hasTextureTransforms,
            uint8_t emissiveUV,
            uint8_t aoUV,
            uint8_t normalUV,
            bool hasTransmissionTexture,
            uint8_t transmissionUV,
            bool hasSheenColorTexture,
            uint8_t sheenColorUV,
            bool hasSheenRoughnessTexture,
            uint8_t sheenRoughnessUV,
            bool hasVolumeThicknessTexture,
            uint8_t volumeThicknessUV ,
            bool hasSheen,
            bool hasIOR,
            bool hasVolume)
        {
            gltfio::MaterialKey config;
            gltfio::UvMap uvMap;
            memset(&config, 0, sizeof(gltfio::MaterialKey));

            // Set and log each field
            config.unlit = unlit;
            config.doubleSided = doubleSided;
            config.useSpecularGlossiness = useSpecularGlossiness;
            config.alphaMode = static_cast<filament::gltfio::AlphaMode>(alphaMode);
            config.hasBaseColorTexture = hasBaseColorTexture;
            config.hasClearCoat = hasClearCoat;
            config.hasClearCoatNormalTexture = hasClearCoatNormalTexture;
            config.hasClearCoatRoughnessTexture = hasClearCoatRoughnessTexture;
            config.hasEmissiveTexture = hasEmissiveTexture;
            config.hasIOR = hasIOR;
            config.hasMetallicRoughnessTexture = hasMetallicRoughnessTexture;
            config.hasNormalTexture = hasNormalTexture;
            config.hasOcclusionTexture = hasOcclusionTexture;
            config.hasSheen = hasSheen;
            config.hasSheenColorTexture = hasSheenColorTexture;
            config.hasSheenRoughnessTexture = hasSheenRoughnessTexture;
            config.hasTextureTransforms = hasTextureTransforms;
            config.hasTransmission = hasTransmission;
            config.hasTransmissionTexture = hasTransmissionTexture;
            config.hasVolume = hasVolume;
            config.hasVolumeThicknessTexture = hasVolumeThicknessTexture;
            config.baseColorUV = baseColorUV;
            config.hasVertexColors = hasVertexColors;

            auto *materialProvider = reinterpret_cast<gltfio::MaterialProvider *>(tMaterialProvider);
            auto materialInstance = materialProvider->createMaterialInstance(&config, &uvMap);
            return reinterpret_cast<TMaterialInstance *>(materialInstance);
        }

#ifdef __cplusplus
    }
}
#endif
