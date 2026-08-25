#pragma once

#include "APIBoundaryTypes.h"

#include "TEngine.h"
#include "TView.h"
#include "TTexture.h"
#include "TMaterialProvider.h"
#include "TVertexBuffer.h"
#include "TIndexBuffer.h"
#include "TTransformManager.h"
#include "TLightManager.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif
        typedef int32_t EntityId;
        typedef void (*FilamentRenderCallback)(void *const owner);

        EMSCRIPTEN_KEEPALIVE void* RenderThread_create();
        // Creates a RenderThread that transfers the given canvas element
        // (CSS selector) to its worker — one thread per viewer on web.
        EMSCRIPTEN_KEEPALIVE void* RenderThread_createForCanvas(const char *canvasSelector);
        EMSCRIPTEN_KEEPALIVE void RenderThread_destroy(void *renderThread);
        
        EMSCRIPTEN_KEEPALIVE void RenderThread_addTask(void (*task)());
        EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderableRenderThread(TRenderManager *tRenderer, TSwapChain *tSwapChain, TView **tViews, uint8_t numViews, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void RenderManager_renderRenderThread(TRenderManager *tRenderManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManagerRenderThread(TRenderManager *tRenderManager, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManagerRenderThread(TRenderManager *tRenderManager, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChainRenderThread(TRenderManager *tRenderManager, TSwapChain *tSwapChain, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void AnimationManager_createRenderThread(TEngine *tEngine, void (*onComplete)(TAnimationManager *));
        EMSCRIPTEN_KEEPALIVE void AnimationManager_destroyRenderThread(TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Engine_createRenderThread(
            TBackend backend,
            void* platform,
            void* sharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck,
            void (*onComplete)(TEngine *)
        );
        EMSCRIPTEN_KEEPALIVE void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyRendererRenderThread(TEngine *tEngine, TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createCameraRenderThread(TEngine* tEngine, EntityId entityId, void (*onComplete)(TCamera *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyCameraRenderThread(TEngine *tEngine, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete);
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
        EMSCRIPTEN_KEEPALIVE void Texture_setExternalImageRenderThread(TEngine *tEngine, TTexture *tTexture, void *externalImage, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Texture_generateMipMapsRenderThread(TTexture *tTexture, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Ktx1Reader_createTextureRenderThread(TEngine *tEngine, TKtx1Bundle *tBundle, uint32_t requestId, VoidCallback onTextureUploadComplete, void (*onComplete)(TTexture *));
        EMSCRIPTEN_KEEPALIVE void Ktx2Reader_createTextureRenderThread(TEngine *tEngine, uint8_t *data, size_t size, void (*onComplete)(TTexture *));

        EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureRenderThread(TEngine *engine, TTexture* tTexture, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence*));
        EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroyRenderThread(TFence *tFence, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitRenderThread(TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_executeRenderThread(TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxRenderThread(TEngine *tEngine, TTexture *tTexture, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildColoredSkyboxRenderThread(TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *));
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
        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTextureRenderThread(TMaterialInstance *tMaterialInstance, const char *propertyName, TTexture* tTexture, TTextureSampler* tSampler, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createGizmoMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createBoneOverlayMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createSilhouetteMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createEdgeOutlineMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createWireframeMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createTranslationAxisMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_createRenderThread(void (*onComplete)(TColorGradingBuilder *));
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_buildRenderThread(TColorGradingBuilder *tBuilder, TEngine *tEngine, void (*onComplete)(TColorGrading *));
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_destroyRenderThread(TColorGradingBuilder *tBuilder, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void ToneMapper_createLinearRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESLegacyRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createFilmicRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createPBRNeutralRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXWithLookRenderThread(TEngine *tEngine, int look, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createGenericRenderThread(TEngine *tEngine, float contrast, float midGrayIn, float midGrayOut, float hdrMax, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createDisplayRangeRenderThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_destroyRenderThread(TToneMapper *tToneMapper, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void View_pickRenderThread(TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback);
        EMSCRIPTEN_KEEPALIVE void View_setColorGradingRenderThread(TView *tView, TColorGrading *tColorGrading, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_getNameRenderThread(TView *tView, void (*onComplete)(const char *));
        EMSCRIPTEN_KEEPALIVE void View_setNameRenderThread(TView *tView, const char *name, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setViewportRenderThread(TView *tView, uint32_t width, uint32_t height, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setRenderTargetRenderThread(TView *tView, TRenderTarget *tRenderTarget, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setAntiAliasingRenderThread(TView *tView, bool msaa, bool fxaa, bool taa, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setPostProcessingRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setDitheringEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setRenderQualityRenderThread(TView *tView, int qualityLevel, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setSceneRenderThread(TView *tView, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setLayerEnabledRenderThread(TView *tView, int layer, bool visible, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setBlendModeRenderThread(TView *tView, int blendMode, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFogOptionsRenderThread(TView *tView, TFogOptions tFogOptions, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setAmbientOcclusionOptionsRenderThread(TView *tView, TAmbientOcclusionOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFrontFaceWindingInvertedRenderThread(TView *tView, bool inverted, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setShadowTypeRenderThread(TView *tView, int shadowType, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptionsRenderThread(TView *tView, TSoftShadowOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setVsmShadowOptionsRenderThread(TView *tView, TVsmShadowOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabledRenderThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyRenderThread(TSceneAsset *tSceneAsset, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromFilamentAssetRenderThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            TNameComponentManager *tNameComponentManager,
            TFilamentAsset *tFilamentAsset,
            bool rebuildVertices,
            void (*onComplete)(TSceneAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromBuffersRenderThread(
            TEngine *tEngine,
            TVertexBuffer *tVertexBuffer,
            TIndexBuffer *tIndexBuffer,
            TMaterialInstance **materialInstances,
            int materialInstanceCount,
            TPrimitiveType tPrimitiveType,
            Aabb3 boundingBox,
            void (*callback)(TSceneAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceRenderThread(TSceneAsset *asset, TMaterialInstance **tMaterialInstances, int materialInstanceCount, void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceDataRenderThread(TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShadingRenderThread(TSceneAsset *tSceneAsset, bool flatShading, uint32_t requestId, VoidCallback onComplete);
        
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

        EMSCRIPTEN_KEEPALIVE void AnimationManager_updateRenderThread(TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationTimeRenderThread(
            TAnimationManager *tAnimationManager,
            TSceneAsset *tSceneAsset,
            int animationIndex,
            float timeInSeconds,
            uint32_t requestId,
            VoidCallback onComplete);

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

        EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPoseRenderThread(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createRenderThread(TEngine *tEngine, TMaterialProvider *tMaterialProvider, TNameComponentManager *tNameComponentManager, void (*callback)(TGltfAssetLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_destroyRenderThread(TGltfAssetLoader *tAssetLoader, uint32_t requestId, VoidCallback onComplete);
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
            uint32_t numInstances,
            void (*callback)(TFilamentAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetRenderThread(TScene* tScene, TFilamentAsset *tAsset, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void FilamentAsset_getWireframeRenderThread(TFilamentAsset *tFilamentAsset, void (*onComplete)(EntityId));
        EMSCRIPTEN_KEEPALIVE void Scene_addEntityRenderThread(TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_removeEntityRenderThread(TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_addToSceneRenderThread(TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromSceneRenderThread(TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_setSkyboxRenderThread(TScene *tScene, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLightRenderThread(TScene *tScene, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete);
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

        // VertexBuffer render thread methods
        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_buildRenderThread(
            TVertexBufferBuilder *tBuilder,
            TEngine *tEngine,
            void (*onComplete)(TVertexBuffer *)
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_destroyRenderThread(
            TEngine *tEngine,
            TVertexBuffer *tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferAtRenderThread(
            TEngine* tEngine,
            TVertexBuffer* tBuffer,
            uint8_t bufferIndex,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        // IndexBuffer render thread methods
        EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_buildRenderThread(
            TIndexBufferBuilder *tBuilder,
            TEngine *tEngine,
            void (*onComplete)(TIndexBuffer *)
        );
        EMSCRIPTEN_KEEPALIVE void IndexBuffer_destroyRenderThread(
            TEngine *tEngine,
            TIndexBuffer *tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void IndexBuffer_setBufferRenderThread(
            TEngine* tEngine,
            TIndexBuffer* tBuffer,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        // RenderableBuilder render thread methods
        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildRenderThread(
            TRenderableBuilder *tBuilder,
            TEngine *tEngine,
            EntityId entityId,
            void (*onComplete)(int)
        );

        EMSCRIPTEN_KEEPALIVE void EntityManager_createEntityRenderThread(TEntityManager *tEntityManager, void (*onComplete)(EntityId));
        EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntityRenderThread(TEntityManager *tEntityManager, EntityId entityId, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformRenderThread(
            TTransformManager *tTransformManager,
            EntityId entityId,
            double4x4 transform,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_setParentRenderThread(
            TTransformManager *tTransformManager,
            EntityId child,
            EntityId parent,
            bool preserveScaling,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_createComponentRenderThread(
            TTransformManager *tTransformManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_removeComponentRenderThread(
            TTransformManager *tTransformManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_destroyEntityRenderThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setMorphWeightsRenderThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            const float *weights,
            size_t count,
            size_t offset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromMat4RenderThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            const float *transforms,
            size_t boneCount,
            size_t offset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromBoneRenderThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            const float *bones,
            size_t boneCount,
            size_t offset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        // Runtime geometry swaps must run on the render thread: Filament
        // asserts that RenderableManager mutation happens there (the
        // CommandStream thread check). Non-indexed/attribute-less variant —
        // no IndexBuffer, [offset, count) select a vertex range. The result
        // of the underlying setGeometryAt is delivered to the callback.
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setGeometryAtNonIndexedRenderThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            int primitiveIndex,
            uint8_t type,
            TVertexBuffer *tVertices,
            size_t offset,
            size_t count,
            void (*callback)(bool)
        );

        // Shadow flags MUST be applied on the render thread — Filament's
        // RenderableManager/LightManager are not concurrency-safe, so the
        // non-render-thread setters race the renderer and the flags don't take
        // (realtime shadows never appear). These mirror the existing render-
        // thread dispatch pattern.
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadowsRenderThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadowsRenderThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCasterRenderThread(
            TLightManager *tLightManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void LightManager_setShadowOptionsRenderThread(
            TLightManager *tLightManager,
            EntityId entityId,
            TShadowOptions options,
            uint32_t requestId,
            VoidCallback onComplete
        );

#ifdef __cplusplus
    }
}
#endif
