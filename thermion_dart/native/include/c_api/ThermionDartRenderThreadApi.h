#pragma once

#include "APIBoundaryTypes.h"

#include "TEngine.h"
#include "TView.h"
#include "TTexture.h"
#include "TMaterialProvider.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif
        typedef int32_t EntityId;
        typedef void (*FilamentRenderCallback)(void *const owner);

        EMSCRIPTEN_KEEPALIVE void RenderThread_create();
        EMSCRIPTEN_KEEPALIVE void RenderThread_destroy();
        EMSCRIPTEN_KEEPALIVE void RenderThread_requestFrameAsync();
        EMSCRIPTEN_KEEPALIVE void RenderThread_setRenderTicker(TRenderTicker *tRenderTicker);
        EMSCRIPTEN_KEEPALIVE void RenderThread_addTask(void (*task)());
        
        EMSCRIPTEN_KEEPALIVE void RenderTicker_renderRenderThread(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void AnimationManager_createRenderThread(TEngine *tEngine, TScene *tScene, void (*onComplete)(TAnimationManager *));

        EMSCRIPTEN_KEEPALIVE void Engine_createRenderThread(
            TBackend backend,
            void* platform,
            void* sharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck,
            void (*onComplete)(TEngine *)
        );
        EMSCRIPTEN_KEEPALIVE void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *));
        EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createCameraRenderThread(TEngine* tEngine, void (*onComplete)(TCamera *));
        EMSCRIPTEN_KEEPALIVE void Engine_createViewRenderThread(TEngine *tEngine, void (*onComplete)(TView *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyRenderThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainRenderThread(TEngine *tEngine, TSwapChain *tSwapChain, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyViewRenderThread(TEngine *tEngine, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroySceneRenderThread(TEngine *tEngine, TScene *tScene, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGradingRenderThread(TEngine *tEngine, TColorGrading *tColorGrading, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceRenderThread(TEngine *tEngine, TMaterialInstance *tMaterialInstance, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxRenderThread(TEngine *tEngine, TSkybox *tSkybox, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightRenderThread(TEngine *tEngine, TIndirectLight *tIndirectLight, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Texture_buildRenderThread(TEngine *engine, 
            uint32_t width, 
            uint32_t height, 
            uint32_t depth, 
            uint8_t levels, 
            uint16_t tUsage,
            intptr_t import,
            TTextureSamplerType sampler, 
            TTextureFormat format,
            void (*onComplete)(TTexture*)
        );
        EMSCRIPTEN_KEEPALIVE void Texture_generateMipMapsRenderThread(TTexture *tTexture, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Ktx1Reader_createTextureRenderThread(TEngine *tEngine, TKtx1Bundle *tBundle, uint32_t requestId, VoidCallback onTextureUploadComplete, void (*onComplete)(TTexture *));

        EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureRenderThread(TEngine *engine, TTexture* tTexture, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence*));
        EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroyRenderThread(TFence *tFence, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitRenderThread(TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_executeRenderThread(TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxRenderThread(TEngine *tEngine, TTexture *tTexture, void (*onComplete)(TSkybox *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceTextureRenderThread(TEngine *tEngine, TTexture *tReflectionsTexture, TTexture* tIrradianceTexture, float intensity, void (*onComplete)(TIndirectLight *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceHarmonicsRenderThread(TEngine *tEngine, TTexture *tReflectionsTexture, float *harmonics, float intensity, void (*onComplete)(TIndirectLight *));

        EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptionsRenderThread(TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameRenderThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool));
        EMSCRIPTEN_KEEPALIVE void Renderer_endFrameRenderThread(TRenderer *tRenderer, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_renderRenderThread(TRenderer *tRenderer, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewRenderThread(TRenderer *tRenderer, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_readPixelsRenderThread(
            TRenderer *tRenderer,
            uint32_t width, uint32_t height, uint32_t xOffset, uint32_t yOffset,
            TRenderTarget *tRenderTarget,
            TPixelDataFormat tPixelBufferFormat,
            TPixelDataType tPixelDataType,
            uint8_t *out,
            size_t outLength,
            uint32_t requestId,  VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *));
        EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createGizmoMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createOutlineMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));

        EMSCRIPTEN_KEEPALIVE void ColorGrading_createRenderThread(TEngine *tEngine, TToneMapping toneMapping, void (*callback)(TColorGrading *));  
        EMSCRIPTEN_KEEPALIVE void View_pickRenderThread(TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback);
        EMSCRIPTEN_KEEPALIVE void View_setColorGradingRenderThread(TView *tView, TColorGrading *tColorGrading, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, uint32_t requestId,  VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void SceneAsset_createGridRenderThread(TEngine *tEngine, TMaterial * tMaterial, void (*callback)(TSceneAsset *));

        EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyRenderThread(TSceneAsset *tSceneAsset, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromFilamentAssetRenderThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            TNameComponentManager *tNameComponentManager,
            TFilamentAsset *tFilamentAsset,
            void (*onComplete)(TSceneAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceRenderThread(TSceneAsset *asset, TMaterialInstance **tMaterialInstances, int materialInstanceCount, void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createGeometryRenderThread(
            TEngine *tEngine, 
            float *vertices,
            uint32_t numVertices,
            float *normals,
            uint32_t numNormals,
            float *uvs,
            uint32_t numUvs,
            uint16_t *indices,
            uint32_t numIndices,
            TPrimitiveType tPrimitiveType,
            TMaterialInstance **materialInstances,
            int materialInstanceCount,
            void (*callback)(TSceneAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceRenderThread(
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
            bool hasVolume,
            void (*callback)(TMaterialInstance *));

        EMSCRIPTEN_KEEPALIVE void AnimationManager_updateBoneMatricesRenderThread(
            TAnimationManager *tAnimationManager,
            TSceneAsset *sceneAsset,
            void (*callback)(bool));

        EMSCRIPTEN_KEEPALIVE void AnimationManager_setMorphTargetWeightsRenderThread(
            TAnimationManager *tAnimationManager,
            EntityId entityId,
            const float *const morphData,
            int numWeights,
            void (*callback)(bool));

        // Image methods
        EMSCRIPTEN_KEEPALIVE void Image_createEmptyRenderThread(uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *));
        EMSCRIPTEN_KEEPALIVE void Image_decodeRenderThread(uint8_t* data, size_t length, const char* name, bool alpha, void (*onComplete)(TLinearImage *));
        EMSCRIPTEN_KEEPALIVE void Image_getBytesRenderThread(TLinearImage *tLinearImage, void (*onComplete)(float *));
        EMSCRIPTEN_KEEPALIVE void Image_destroyRenderThread(TLinearImage *tLinearImage, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Image_getWidthRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getHeightRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getChannelsRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));


        EMSCRIPTEN_KEEPALIVE void Texture_loadImageRenderThread(
            TEngine *tEngine,
            TTexture *tTexture,
            TLinearImage *tImage,
            TPixelDataFormat bufferFormat,
            TPixelDataType pixelDataType,
            int level,
            void (*onComplete)(bool)
        );
        EMSCRIPTEN_KEEPALIVE void Texture_setImageRenderThread(
            TEngine *tEngine,
            TTexture *tTexture,
            uint32_t level,
            uint8_t *data,
            size_t size,
            uint32_t x_offset,
            uint32_t y_offset,
            uint32_t z_offset,
            uint32_t width,
            uint32_t height,
            uint32_t depth,
            uint32_t bufferFormat,
            uint32_t pixelDataType,
            void (*onComplete)(bool)
        );
        EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureRenderThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *));
        EMSCRIPTEN_KEEPALIVE void RenderTarget_createRenderThread(
            TEngine *tEngine,
            uint32_t width,
            uint32_t height,
            TTexture *color,
            TTexture *depth,
            void (*onComplete)(TRenderTarget *)
        );
        EMSCRIPTEN_KEEPALIVE void RenderTarget_destroyRenderThread(
            TEngine *tEngine,
            TRenderTarget *tRenderTarget,
            uint32_t requestId, VoidCallback onComplete
        );


        // TextureSampler methods
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createRenderThread(void (*onComplete)(TTextureSampler*));
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithFilteringRenderThread(
            TSamplerMinFilter minFilter, 
            TSamplerMagFilter magFilter, 
            TSamplerWrapMode wrapS, 
            TSamplerWrapMode wrapT, 
            TSamplerWrapMode wrapR,
            void (*onComplete)(TTextureSampler*)
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithComparisonRenderThread(
            TSamplerCompareMode compareMode, 
            TSamplerCompareFunc compareFunc,
            void (*onComplete)(TTextureSampler*)
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilterRenderThread(
            TTextureSampler* sampler, 
            TSamplerMinFilter filter,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterRenderThread(
            TTextureSampler* sampler, 
            TSamplerMagFilter filter,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyRenderThread(
            TTextureSampler* sampler, 
            double anisotropy,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeRenderThread(
            TTextureSampler* sampler, 
            TSamplerCompareMode mode, 
            TTextureSamplerCompareFunc func,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyRenderThread(
            TTextureSampler* sampler,
            uint32_t requestId, VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void AnimationManager_setBoneTransformRenderThread(
            TAnimationManager *tAnimationManager,
            EntityId asset,
            int skinIndex,
            int boneIndex,
            const float *const transform,
            void (*callback)(bool));

        EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPoseRenderThread(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createRenderThread(TEngine *tEngine, TMaterialProvider *tMaterialProvider, TNameComponentManager *tNameComponentManager, void (*callback)(TGltfAssetLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createRenderThread(TEngine *tEngine, void (*callback)(TGltfResourceLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroyRenderThread(TEngine *tEngine, TGltfResourceLoader *tResourceLoader, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_loadResourcesRenderThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceDataRenderThread(TGltfResourceLoader *tGltfResourceLoader, const char *uri, uint8_t *data, size_t length, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncBeginLoadRenderThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoadRenderThread(TGltfResourceLoader *tGltfResourceLoader);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncGetLoadProgressRenderThread(TGltfResourceLoader *tGltfResourceLoader, void (*callback)(float));

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadRenderThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            uint8_t *data,
            size_t length,
            uint8_t numInstances,
            void (*callback)(TFilamentAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetRenderThread(TScene* tScene, TFilamentAsset *tAsset, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Gizmo_createRenderThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            TGltfResourceLoader *tGltfResourceLoader,
            TNameComponentManager *tNameComponentManager,
            TView *tView,
            TMaterial *tMaterial,
            TGizmoType tGizmoType,    
            void (*callback)(TGizmo *)
        );



#ifdef __cplusplus
    }
}
#endif
