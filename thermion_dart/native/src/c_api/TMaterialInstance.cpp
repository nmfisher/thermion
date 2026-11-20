#include "rendering/EngineApiLock.hpp"
#include <vector>

#include <filament/MaterialInstance.h>
#include <filament/Material.h>

#include <math/mat4.h>
#include <math/vec4.h>
#include <math/vec2.h>

#include "Log.hpp"
#include "MathUtils.hpp"

#include "material/BuiltInMaterialPackage.hpp"
#include "c_api/TMaterialInstance.h"

namespace thermion {
TMaterial* buildBuiltInMaterial(TEngine* tEngine, BuiltInMaterialPackage package) {
    if (!package.data) return nullptr;
    THERMION_ENGINE_API_GUARD;
    auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
    auto* material = filament::Material::Builder().package(package.data, package.size).build(*engine);
    if (!material) return nullptr;
#ifdef NORMAL_COLOR_ENABLED
    if (package.id == BUILT_IN_NORMAL_COLOR) {
        material->setDefaultParameter("opacity", 1.0f);
    }
#endif
#ifdef SHARP_EDGE_ENABLED
    if (package.id == BUILT_IN_SHARP_EDGE) {
        material->setDefaultParameter("edgeColor", filament::math::float4{1, 1, 1, 1});
        material->setDefaultParameter("baseColor", filament::math::float4{0.1f, 0.1f, 0.1f, 1});
        material->setDefaultParameter("edgeWidth", 1.0f);
    }
#endif
    return reinterpret_cast<TMaterial*>(material);
}
} // namespace thermion

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif

        EMSCRIPTEN_KEEPALIVE TMaterialInstance *Material_createInstance(TMaterial *tMaterial)
        {
            THERMION_ENGINE_API_GUARD;
            auto *material = reinterpret_cast<filament::Material *>(tMaterial);
            auto *instance = material->createInstance();
            return reinterpret_cast<TMaterialInstance *>(instance);
        }

        EMSCRIPTEN_KEEPALIVE TFeatureLevel Material_getFeatureLevel(TMaterial *tMaterial) {
            THERMION_ENGINE_API_GUARD;
            auto *material = reinterpret_cast<filament::Material *>(tMaterial);
            auto featureLevel = material->getFeatureLevel();
             switch(featureLevel) {
                case filament::backend::FeatureLevel::FEATURE_LEVEL_0:
                    return FEATURE_LEVEL_0;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_1:
                    return FEATURE_LEVEL_1;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_2:
                    return FEATURE_LEVEL_2;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_3:
                    return FEATURE_LEVEL_3;
            }
        }

        // Compatibility exports for existing native callers.
#ifdef IMAGE_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createImageMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_IMAGE));
        }
#endif

#ifdef GRID_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createGridMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_GRID));
        }
#endif

#ifdef GIZMO_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createGizmoMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_GIZMO));
        }
#endif

#ifdef SILHOUETTE_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createSilhouetteMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_SILHOUETTE));
        }
#endif

#ifdef EDGE_OUTLINE_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createEdgeOutlineMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_EDGE_OUTLINE));
        }
#endif

#ifdef WIREFRAME_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createWireframeMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_WIREFRAME));
        }
#endif

#ifdef TRANSLATION_AXIS_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createTranslationAxisMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_TRANSLATION_AXIS));
        }
#endif

#ifdef BONE_OVERLAY_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createBoneOverlayMaterial(TEngine *tEngine) {
            return buildBuiltInMaterial(tEngine, builtInMaterialPackage(BUILT_IN_BONE_OVERLAY));
        }
#endif

        EMSCRIPTEN_KEEPALIVE bool Material_hasParameter(TMaterial *tMaterial, const char *propertyName) {
            THERMION_ENGINE_API_GUARD;
            auto *material = reinterpret_cast<filament::Material *>(tMaterial);
            return material->hasParameter(propertyName);
        }

        EMSCRIPTEN_KEEPALIVE bool MaterialInstance_isStencilWriteEnabled(TMaterialInstance *tMaterialInstance)
        {
            THERMION_ENGINE_API_GUARD;
            return reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance)->isStencilWriteEnabled();
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDoubleSided(TMaterialInstance *materialInstance, bool enabled)
        {
            THERMION_ENGINE_API_GUARD;
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setDoubleSided(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance *materialInstance, bool enabled)
        {
            THERMION_ENGINE_API_GUARD;
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setDepthWrite(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance *materialInstance, bool enabled)
        {
            THERMION_ENGINE_API_GUARD;
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setDepthCulling(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat(TMaterialInstance *tMaterialInstance, const char *propertyName, double value)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto fValue = static_cast<float>(value);
            materialInstance->setParameter(propertyName, fValue);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance *materialInstance, const char *propertyName, double x, double y)
        {
            THERMION_ENGINE_API_GUARD;
            filament::math::float2 data{static_cast<float>(x), static_cast<float>(y)};
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat3(TMaterialInstance *materialInstance, const char *propertyName, double x, double y, double z)
        {
            THERMION_ENGINE_API_GUARD;
            filament::math::float3 data{static_cast<float>(x), static_cast<float>(y), static_cast<float>(z) };
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat3Array(TMaterialInstance *tMaterialInstance, const char *propertyName, double* raw, uint32_t length) {
            THERMION_ENGINE_API_GUARD;
            TRACE("Setting property %s to array from raw length %d", propertyName, length);

            std::vector<filament::math::float3> data;

            for(int i = 0; i < length; i+=3) {
                // TRACE("Vector %f %f %f", static_cast<float>(raw[i]), static_cast<float>(raw[i+1]), static_cast<float>(raw[i+2]));
                data.push_back(filament::math::float3 { static_cast<float>(raw[i]), static_cast<float>(raw[i+1]), static_cast<float>(raw[i+2]) });
            }
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            materialInstance->setParameter(propertyName, data.data(), data.size());
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat4(TMaterialInstance *tMaterialInstance, const char *propertyName, double x, double y, double z, double w)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            filament::math::float4 data{static_cast<float>(x), static_cast<float>(y), static_cast<float>(z), static_cast<float>(w)};
            materialInstance->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterInt(TMaterialInstance *tMaterialInstance, const char *propertyName, int value)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            materialInstance->setParameter(propertyName, value);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterBool(TMaterialInstance *materialInstance, const char *propertyName, bool value)
        {
            THERMION_ENGINE_API_GUARD;
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, value);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTexture(TMaterialInstance *tMaterialInstance, const char *propertyName, TTexture* tTexture, TTextureSampler* tSampler) {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto texture = reinterpret_cast<::filament::Texture*>(tTexture);
            auto sampler = reinterpret_cast<::filament::TextureSampler*>(tSampler);
            materialInstance->setParameter(propertyName, texture, *sampler);
        }


        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterMat3(TMaterialInstance *tMaterialInstance, const char *propertyName, double *matrix) {
            THERMION_ENGINE_API_GUARD;
            auto *mi = reinterpret_cast<filament::MaterialInstance *>(tMaterialInstance);
            mi->setParameter(propertyName, convert_double_to_mat3f(matrix));
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterMat4(TMaterialInstance *tMaterialInstance, const char *propertyName, double *matrix) {
            THERMION_ENGINE_API_GUARD;
            auto *mi = reinterpret_cast<filament::MaterialInstance *>(tMaterialInstance);
            mi->setParameter(propertyName, convert_double_to_mat4f(matrix));
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthFunc(TMaterialInstance *tMaterialInstance, TSamplerCompareFunc tDepthFunc)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto depthFunc = static_cast<filament::MaterialInstance::DepthFunc>(tDepthFunc);
            materialInstance->setDepthFunc(depthFunc);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpStencilFail(TMaterialInstance *tMaterialInstance,
                                                                           TStencilOperation tOp, TStencilFace tFace)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto op = static_cast<filament::MaterialInstance::StencilOperation>(tOp);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilOpStencilFail(op, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpDepthFail(TMaterialInstance *tMaterialInstance,
                                                                         TStencilOperation tOp, TStencilFace tFace)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto op = static_cast<filament::MaterialInstance::StencilOperation>(tOp);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilOpDepthFail(op, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpDepthStencilPass(TMaterialInstance *tMaterialInstance,
                                                                                TStencilOperation tOp, TStencilFace tFace)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto op = static_cast<filament::MaterialInstance::StencilOperation>(tOp);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilOpDepthStencilPass(op, face);
        }

        filament::MaterialInstance::StencilFace toStencilFace(TStencilFace tface) {
            switch(tface) {
                case STENCIL_FACE_FRONT: return filament::MaterialInstance::StencilFace::FRONT;
                case STENCIL_FACE_BACK: return filament::MaterialInstance::StencilFace::BACK;
                case STENCIL_FACE_FRONT_AND_BACK: return filament::MaterialInstance::StencilFace::FRONT_AND_BACK;
                default:
                    ERROR("Invalid TStencilFace value: %d", static_cast<int>(tface));
                    return filament::MaterialInstance::StencilFace::FRONT_AND_BACK;
            }
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilCompareFunction(TMaterialInstance *tMaterialInstance,
                                                                             TSamplerCompareFunc tFunc, TStencilFace tFace)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto func = static_cast<filament::MaterialInstance::StencilCompareFunc>(tFunc);
            auto face = toStencilFace(tFace);

            materialInstance->setStencilCompareFunction(
                func,
                face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilReferenceValue(TMaterialInstance *tMaterialInstance,
                                                                            uint8_t value, TStencilFace tFace)
        {
            THERMION_ENGINE_API_GUARD;
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilReferenceValue(value, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilWrite(TMaterialInstance *materialInstance, bool enabled)
        {
            THERMION_ENGINE_API_GUARD;
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setStencilWrite(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setCullingMode(TMaterialInstance *materialInstance, TCullingMode culling)
        {
            THERMION_ENGINE_API_GUARD;
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            auto cullingMode = static_cast<filament::MaterialInstance::CullingMode>(culling);
            instance->setCullingMode(cullingMode);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilReadMask(
            TMaterialInstance *materialInstance,
            uint8_t mask)
        {
            THERMION_ENGINE_API_GUARD;
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            instance->setStencilReadMask(mask);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilWriteMask(
            TMaterialInstance *materialInstance,
            uint8_t mask)
        {
            THERMION_ENGINE_API_GUARD;
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            instance->setStencilWriteMask(mask);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setTransparencyMode(
            TMaterialInstance *materialInstance,
            TTransparencyMode transparencyMode)
        {
            THERMION_ENGINE_API_GUARD;
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            instance->setTransparencyMode((filament::TransparencyMode)transparencyMode);
        }

        EMSCRIPTEN_KEEPALIVE TTransparencyMode MaterialInstance_getTransparencyMode(
            TMaterialInstance *tMaterialInstance)
        {
            THERMION_ENGINE_API_GUARD;
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto transparencyMode = instance->getTransparencyMode();
            return static_cast<TTransparencyMode>(transparencyMode);
        }

        EMSCRIPTEN_KEEPALIVE TBlendingMode Material_getBlendingMode(TMaterial *tMaterial)
        {
            THERMION_ENGINE_API_GUARD;
            auto *material = reinterpret_cast<filament::Material *>(tMaterial);
            auto blendingMode = material->getBlendingMode();
            return static_cast<TBlendingMode>(blendingMode);
        }
#ifdef __cplusplus
    }
}
#endif
