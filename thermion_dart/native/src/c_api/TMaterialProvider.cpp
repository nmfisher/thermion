#include "rendering/EngineApiLock.hpp"

#include "ThermionFeatures.h"

#include <cstring>

#include <filament/MaterialInstance.h>
#include <math/mat4.h>
#include <math/vec4.h>
#include <math/vec2.h>

#if THERMION_ENABLE_GLTF
#include <gltfio/MaterialProvider.h>
#endif

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

#if THERMION_ENABLE_GLTF
        
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
            THERMION_ENGINE_API_GUARD;
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
            config.enableDiagnostics = enableDiagnostics;
            config.metallicRoughnessUV = metallicRoughnessUV;
            config.specularGlossinessUV = specularGlossinessUV;
            config.hasClearCoatTexture = hasClearCoatTexture;
            config.clearCoatUV = clearCoatUV;
            config.clearCoatRoughnessUV = clearCoatRoughnessUV;
            config.clearCoatNormalUV = clearCoatNormalUV;
            config.emissiveUV = emissiveUV;
            config.aoUV = aoUV;
            config.normalUV = normalUV;
            config.transmissionUV = transmissionUV;
            config.sheenColorUV = sheenColorUV;
            config.sheenRoughnessUV = sheenRoughnessUV;
            config.volumeThicknessUV = volumeThicknessUV;

            auto *materialProvider = reinterpret_cast<gltfio::MaterialProvider *>(tMaterialProvider);
            auto materialInstance = materialProvider->createMaterialInstance(&config, &uvMap);
            return reinterpret_cast<TMaterialInstance *>(materialInstance);
        }

#else // !THERMION_ENABLE_GLTF
        // Stub contract. There is no ubershader provider in this build:
        // every request returns null. Dart guards explicit ubershader
        // requests (createUbershaderMaterialInstance / createUbershaderMaterial)
        // with UnsupportedError, and createUnlitMaterialInstance never
        // reaches this entry point — it builds the precompiled unlit
        // fallback through Material_createBuiltIn(BUILT_IN_UNLIT_FALLBACK)
        // on the Dart side.
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
            THERMION_ENGINE_API_GUARD;
            (void)doubleSided;
            (void)hasVertexColors;
            (void)hasBaseColorTexture;
            (void)hasNormalTexture;
            (void)hasOcclusionTexture;
            (void)hasEmissiveTexture;
            (void)useSpecularGlossiness;
            (void)alphaMode;
            (void)enableDiagnostics;
            (void)hasMetallicRoughnessTexture;
            (void)metallicRoughnessUV;
            (void)hasSpecularGlossinessTexture;
            (void)specularGlossinessUV;
            (void)baseColorUV;
            (void)hasClearCoatTexture;
            (void)clearCoatUV;
            (void)hasClearCoatRoughnessTexture;
            (void)clearCoatRoughnessUV;
            (void)hasClearCoatNormalTexture;
            (void)clearCoatNormalUV;
            (void)hasClearCoat;
            (void)hasTransmission;
            (void)hasTextureTransforms;
            (void)emissiveUV;
            (void)aoUV;
            (void)normalUV;
            (void)hasTransmissionTexture;
            (void)transmissionUV;
            (void)hasSheenColorTexture;
            (void)sheenColorUV;
            (void)hasSheenRoughnessTexture;
            (void)sheenRoughnessUV;
            (void)hasVolumeThicknessTexture;
            (void)volumeThicknessUV;
            (void)hasSheen;
            (void)hasIOR;
            (void)hasVolume;

            (void)tMaterialProvider;
            (void)unlit;
            Log("MaterialProvider_createMaterialInstance: glTF support is disabled in this build (features.gltf: false)");
            return nullptr;
        }
#endif // THERMION_ENABLE_GLTF

#ifdef __cplusplus
    }
}
#endif
