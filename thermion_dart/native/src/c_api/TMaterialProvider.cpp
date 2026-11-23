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
#include "material/UnlitFallbackProvider.hpp"

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
        // Stub contract (docs/feature-optout-proposal.md §5.4). There is no
        // ubershader provider in this build, so explicit ubershader requests
        // (createUbershaderMaterialInstance / createUbershaderMaterial on the
        // Dart side) get null; Dart turns that into UnsupportedError.
        //
        // The unlit variant is different: it is the material procedural code
        // requests through createUnlitMaterialInstance() (bounding-box
        // helpers, TextureProjection, explicit materials for createGeometry).
        // GltfAssetLoader_create's stub handed Dart an UnlitFallbackProvider
        // carrying the engine, so this context-free entry point (no Engine
        // parameter) can build the precompiled UNLIT_FALLBACK package on first
        // use and return an instance from it. The Material is cached on the
        // provider, which GltfAssetLoader_destroy tears down (§5.6).
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

            auto *provider = reinterpret_cast<UnlitFallbackProvider *>(tMaterialProvider);
            if (!unlit || !provider || !provider->engine) {
                Log("MaterialProvider_createMaterialInstance: glTF support is disabled in this build (features.gltf: false)");
                return nullptr;
            }
            if (!provider->unlitMaterial) {
                const auto factory = builtInMaterialFactory(BUILT_IN_UNLIT_FALLBACK);
                provider->unlitMaterial = factory
                    ? reinterpret_cast<filament::Material *>(factory(reinterpret_cast<TEngine *>(provider->engine)))
                    : nullptr;
            }
            if (!provider->unlitMaterial) {
                Log("MaterialProvider_createMaterialInstance: the precompiled unlit fallback material is not compiled into this build (features.gltf: false without UNLIT_FALLBACK_ENABLED)");
                return nullptr;
            }
            auto *instance = provider->unlitMaterial->createInstance();
            // Same default as the gltfio ubershader's unlit variant
            // (UbershaderProvider starts baseColorFactor at opaque white).
            // A .mat uniform parameter is zero-initialised, so an instance
            // handed out untouched would otherwise render transparent black
            // instead of white (unlit_fallback.mat).
            instance->setParameter("baseColorFactor", filament::math::float4{1.0f, 1.0f, 1.0f, 1.0f});
            return reinterpret_cast<TMaterialInstance *>(instance);
        }
#endif // THERMION_ENABLE_GLTF

#ifdef __cplusplus
    }
}
#endif
