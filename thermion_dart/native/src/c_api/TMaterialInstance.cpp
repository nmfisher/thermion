#include <vector>

#include <filament/MaterialInstance.h>
#include <filament/Material.h>

#include <math/mat4.h>
#include <math/vec4.h>
#include <math/vec2.h>

#include "Log.hpp"
#include "MathUtils.hpp"
#include "material/image.h"
#include "material/grid.h"
#include "material/unlit_fixed_size.h"

#include "c_api/TMaterialInstance.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif

        EMSCRIPTEN_KEEPALIVE TMaterialInstance *Material_createInstance(TMaterial *tMaterial)
        {
            auto *material = reinterpret_cast<filament::Material *>(tMaterial);
            auto *instance = material->createInstance();
            return reinterpret_cast<TMaterialInstance *>(instance);
        }

        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createImageMaterial(TEngine *tEngine) {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *material = filament::Material::Builder()
            .package(IMAGE_IMAGE_DATA, IMAGE_IMAGE_SIZE)
            .build(*engine);
            
            return reinterpret_cast<TMaterial *>(material);
        }

        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createGridMaterial(TEngine *tEngine) {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *material = filament::Material::Builder()
                .package(GRID_GRID_DATA, GRID_GRID_SIZE)
                .build(*engine);
            return reinterpret_cast<TMaterial *>(material);
        }

        EMSCRIPTEN_KEEPALIVE TMaterial *Material_createGizmoMaterial(TEngine *tEngine) {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *material = filament::Material::Builder()
                .package(UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_DATA, UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_SIZE)
                .build(*engine);
            return reinterpret_cast<TMaterial *>(material);
        }

        EMSCRIPTEN_KEEPALIVE bool Material_hasParameter(TMaterial *tMaterial, const char *propertyName) {
            auto *material = reinterpret_cast<filament::Material *>(tMaterial);
            return material->hasParameter(propertyName);
        }

        EMSCRIPTEN_KEEPALIVE bool MaterialInstance_isStencilWriteEnabled(TMaterialInstance *tMaterialInstance)
        {
            return reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance)->isStencilWriteEnabled();
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance *materialInstance, bool enabled)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setDepthWrite(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance *materialInstance, bool enabled)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setDepthCulling(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat(TMaterialInstance *tMaterialInstance, const char *propertyName, double value)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto fValue = static_cast<float>(value);
            materialInstance->setParameter(propertyName, fValue);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance *materialInstance, const char *propertyName, double x, double y)
        {
            filament::math::float2 data{static_cast<float>(x), static_cast<float>(y)};
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat3(TMaterialInstance *materialInstance, const char *propertyName, double x, double y, double z)
        {
            filament::math::float3 data{static_cast<float>(x), static_cast<float>(y), static_cast<float>(z) };
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat3Array(TMaterialInstance *tMaterialInstance, const char *propertyName, double* raw, uint32_t length) {
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
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            filament::math::float4 data{static_cast<float>(x), static_cast<float>(y), static_cast<float>(z), static_cast<float>(w)};
            materialInstance->setParameter(propertyName, data);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterInt(TMaterialInstance *tMaterialInstance, const char *propertyName, int value)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            materialInstance->setParameter(propertyName, value);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterBool(TMaterialInstance *materialInstance, const char *propertyName, bool value)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setParameter(propertyName, value);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTexture(TMaterialInstance *tMaterialInstance, const char *propertyName, TTexture* tTexture, TTextureSampler* tSampler) {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto texture = reinterpret_cast<::filament::Texture*>(tTexture);
            auto sampler = reinterpret_cast<::filament::TextureSampler*>(tSampler);
            materialInstance->setParameter(propertyName, texture, *sampler);
        }


        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterMat4(TMaterialInstance *tMaterialInstance, const char *propertyName, double *matrix) {
            auto *mi = reinterpret_cast<filament::MaterialInstance *>(tMaterialInstance);
            mi->setParameter(propertyName, convert_double_to_mat4f(matrix));
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthFunc(TMaterialInstance *tMaterialInstance, TSamplerCompareFunc tDepthFunc)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto depthFunc = static_cast<filament::MaterialInstance::DepthFunc>(tDepthFunc);
            materialInstance->setDepthFunc(depthFunc);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpStencilFail(TMaterialInstance *tMaterialInstance,
                                                                           TStencilOperation tOp, TStencilFace tFace)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto op = static_cast<filament::MaterialInstance::StencilOperation>(tOp);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilOpStencilFail(op, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpDepthFail(TMaterialInstance *tMaterialInstance,
                                                                         TStencilOperation tOp, TStencilFace tFace)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto op = static_cast<filament::MaterialInstance::StencilOperation>(tOp);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilOpDepthFail(op, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilOpDepthStencilPass(TMaterialInstance *tMaterialInstance,
                                                                                TStencilOperation tOp, TStencilFace tFace)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto op = static_cast<filament::MaterialInstance::StencilOperation>(tOp);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilOpDepthStencilPass(op, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilCompareFunction(TMaterialInstance *tMaterialInstance,
                                                                             TSamplerCompareFunc tFunc, TStencilFace tFace)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto func = static_cast<filament::MaterialInstance::StencilCompareFunc>(tFunc);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilCompareFunction(func, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilReferenceValue(TMaterialInstance *tMaterialInstance,
                                                                            uint8_t value, TStencilFace tFace)
        {
            auto *materialInstance = reinterpret_cast<::filament::MaterialInstance *>(tMaterialInstance);
            auto face = static_cast<filament::MaterialInstance::StencilFace>(tFace);
            materialInstance->setStencilReferenceValue(value, face);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilWrite(TMaterialInstance *materialInstance, bool enabled)
        {
            reinterpret_cast<::filament::MaterialInstance *>(materialInstance)->setStencilWrite(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setCullingMode(TMaterialInstance *materialInstance, TCullingMode culling)
        {
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            auto cullingMode = static_cast<filament::MaterialInstance::CullingMode>(culling);
            instance->setCullingMode(cullingMode);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilReadMask(
            TMaterialInstance *materialInstance,
            uint8_t mask)
        {
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            instance->setStencilReadMask(mask);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setStencilWriteMask(
            TMaterialInstance *materialInstance,
            uint8_t mask)
        {
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            instance->setStencilWriteMask(mask);
        }

        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setTransparencyMode(
            TMaterialInstance *materialInstance,
            TTransparencyMode transparencyMode)
        {
            auto *instance = reinterpret_cast<::filament::MaterialInstance *>(materialInstance);
            instance->setTransparencyMode((filament::TransparencyMode)transparencyMode);
        }
#ifdef __cplusplus
    }
}
#endif
