#include "rendering/EngineApiLock.hpp"
#include <vector>

#include <filament/MaterialInstance.h>
#include <filament/Material.h>

#include <math/mat4.h>
#include <math/vec4.h>
#include <math/vec2.h>

#include "Log.hpp"
#include "MathUtils.hpp"

#include "ThermionFeatures.h"
#include "c_api/TMaterialInstance.h"

// The Dart build hook compiles enabled materials on demand and places their
// generated resgen headers on the compiler include path.
#if IMAGE_ENABLED
#include "image.h"
#endif
#if GRID_ENABLED
#include "grid.h"
#endif
#if GIZMO_ENABLED
#include "gizmo_material.h"
#endif
#if TRANSLATION_AXIS_ENABLED
#include "translation_axis.h"
#endif
#if BONE_OVERLAY_ENABLED
#include "bone_overlay.h"
#endif
#if SILHOUETTE_ENABLED
#include "silhouette.h"
#endif
#if EDGE_OUTLINE_ENABLED
#include "edge_outline.h"
#endif
#if WIREFRAME_ENABLED
#include "wireframe.h"
#endif
#if NORMAL_COLOR_ENABLED
#include "normal_color.h"
#endif
#if SHARP_EDGE_ENABLED
#include "sharp_edge.h"
#endif
#if CAPTURE_UV_ENABLED
#include "capture_uv.h"
#endif
#if LINEAR_DEPTH_ENABLED
#include "linear_depth.h"
#endif
#if UNLIT_FIXED_SIZE_ENABLED
#include "unlit_fixed_size.h"
#endif
// features.gltf: false builds only (hook/build.dart): precompiled unlit
// material backing createUnlitMaterialInstance when no ubershader exists.
#if UNLIT_FALLBACK_ENABLED
#include "unlit_fallback.h"
#endif

namespace thermion {
static TMaterial* buildBuiltInMaterial(TEngine* tEngine, const uint8_t* data, size_t size) {
    THERMION_ENGINE_API_GUARD;
    auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
    auto* material = filament::Material::Builder().package(data, size).build(*engine);
    return reinterpret_cast<TMaterial*>(material);
}

// resgen names each slice <PREFIX>_<INPUT>_{DATA,SIZE}. Built-ins use the same name for both,
// except gizmo which uses prefix gizmo_material to avoid a Windows .obj collision with Gizmo.cpp.
#define RESGEN_FACTORY(name) \
    case BUILT_IN_##name: \
        return [](TEngine* engine) { \
            return buildBuiltInMaterial(engine, name##_##name##_DATA, name##_##name##_SIZE); \
        }

BuiltInMaterialFactory builtInMaterialFactory(TBuiltInMaterial id) {
    switch (id) {
#if IMAGE_ENABLED
        RESGEN_FACTORY(IMAGE);
#endif
#if GRID_ENABLED
        RESGEN_FACTORY(GRID);
#endif
#if GIZMO_ENABLED
        case BUILT_IN_GIZMO:
            return [](TEngine* engine) {
                return buildBuiltInMaterial(engine, GIZMO_MATERIAL_GIZMO_DATA, GIZMO_MATERIAL_GIZMO_SIZE);
            };
#endif
#if TRANSLATION_AXIS_ENABLED
        RESGEN_FACTORY(TRANSLATION_AXIS);
#endif
#if BONE_OVERLAY_ENABLED
        RESGEN_FACTORY(BONE_OVERLAY);
#endif
#if SILHOUETTE_ENABLED
        RESGEN_FACTORY(SILHOUETTE);
#endif
#if EDGE_OUTLINE_ENABLED
        RESGEN_FACTORY(EDGE_OUTLINE);
#endif
#if WIREFRAME_ENABLED
        RESGEN_FACTORY(WIREFRAME);
#endif
#if NORMAL_COLOR_ENABLED
        RESGEN_FACTORY(NORMAL_COLOR);
#endif
#if SHARP_EDGE_ENABLED
        RESGEN_FACTORY(SHARP_EDGE);
#endif
#if CAPTURE_UV_ENABLED
        RESGEN_FACTORY(CAPTURE_UV);
#endif
#if LINEAR_DEPTH_ENABLED
        RESGEN_FACTORY(LINEAR_DEPTH);
#endif
#if UNLIT_FIXED_SIZE_ENABLED
        RESGEN_FACTORY(UNLIT_FIXED_SIZE);
#endif
#if UNLIT_FALLBACK_ENABLED
        RESGEN_FACTORY(UNLIT_FALLBACK);
#endif
        default: return nullptr;
    }
}
#undef RESGEN_FACTORY
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
#if IMAGE_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createImageMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_IMAGE)(tEngine);
        }
#endif

#if GRID_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createGridMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_GRID)(tEngine);
        }
#endif

#if GIZMO_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createGizmoMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_GIZMO)(tEngine);
        }
#endif

#if SILHOUETTE_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createSilhouetteMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_SILHOUETTE)(tEngine);
        }
#endif

#if EDGE_OUTLINE_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createEdgeOutlineMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_EDGE_OUTLINE)(tEngine);
        }
#endif

#if WIREFRAME_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createWireframeMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_WIREFRAME)(tEngine);
        }
#endif

#if TRANSLATION_AXIS_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createTranslationAxisMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_TRANSLATION_AXIS)(tEngine);
        }
#endif

#if BONE_OVERLAY_ENABLED
        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createBoneOverlayMaterial(TEngine *tEngine) {
            return builtInMaterialFactory(BUILT_IN_BONE_OVERLAY)(tEngine);
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

        EMSCRIPTEN_KEEPALIVE bool Material_compile(
            TMaterial *tMaterial,
            TCompilerPriorityQueue priority,
            uint32_t variants,
            void (*onComplete)(void *),
            void *userData)
        {
            THERMION_ENGINE_API_GUARD;
            if (!tMaterial)
            {
                ERROR("Material_compile: material is null");
                return false;
            }
            auto *material = reinterpret_cast<filament::Material *>(tMaterial);
            // Filament invokes the callback (on the engine's thread, after the
            // driver has linked every requested variant, or when the engine is
            // destroyed) and ignores the Material* it passes, which may be
            // dangling in the engine-destruction case.
            material->compile(
                static_cast<filament::Material::CompilerPriorityQueue>(priority),
                static_cast<filament::UserVariantFilterMask>(variants),
                nullptr,
                [onComplete, userData](filament::Material *) { onComplete(userData); });
            return true;
        }
#ifdef __cplusplus
    }
}
#endif
