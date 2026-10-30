#pragma once

#include "APIBoundaryTypes.h"

#include "TEngine.h"
#include "TView.h"
#include "TTexture.h"
#include "TMaterialProvider.h"
#include "TVertexBuffer.h"
#include "TIndexBuffer.h"
#include "TBufferObject.h"
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

        EMSCRIPTEN_KEEPALIVE void* JobThread_create();
        // Creates a JobThread that transfers the given canvas element
        // (CSS selector) to its worker — one thread per viewer on web.
        EMSCRIPTEN_KEEPALIVE void* JobThread_createForCanvas(const char *canvasSelector);
        EMSCRIPTEN_KEEPALIVE void JobThread_destroy(void *jobThread);

        EMSCRIPTEN_KEEPALIVE void JobThread_addTask(void (*task)());
        // Borrows the matrix pointer without copying its values.
        // The caller must keep it alive and unchanged until onComplete is called.
        EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformNativeJobThread(TTransformManager *manager, EntityId entity, TMat4 *matrix, uint32_t requestId, VoidCallback onComplete);
        // Copies all 16 column-major doubles before returning. The caller may
        // immediately reuse/free matrix16 while the queued task is pending.
        EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformFromBufferJobThread(TTransformManager *manager, EntityId entity, const double *matrix16, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderableJobThread(TRenderManager *tRenderer, TSwapChain *tSwapChain, TView **tViews, uint8_t numViews, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void RenderManager_renderJobThread(TRenderManager *tRenderManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManagerJobThread(TRenderManager *tRenderManager, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManagerJobThread(TRenderManager *tRenderManager, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChainJobThread(TRenderManager *tRenderManager, TSwapChain *tSwapChain, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void AnimationManager_createJobThread(TEngine *tEngine, void (*onComplete)(TAnimationManager *));
        EMSCRIPTEN_KEEPALIVE void AnimationManager_destroyJobThread(TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Engine_createJobThread(
            TBackend backend,
            void* platform,
            void* sharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck,
            void (*onComplete)(TEngine *)
        );
        EMSCRIPTEN_KEEPALIVE void Engine_createRendererJobThread(TEngine *tEngine, void (*onComplete)(TRenderer *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyRendererJobThread(TEngine *tEngine, TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainJobThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainJobThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createCameraJobThread(TEngine* tEngine, EntityId entityId, void (*onComplete)(TCamera *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyCameraJobThread(TEngine *tEngine, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createViewJobThread(TEngine *tEngine, void (*onComplete)(TView *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialJobThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyJobThread(TEngine *tEngine, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainJobThread(TEngine *tEngine, TSwapChain *tSwapChain, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyViewJobThread(TEngine *tEngine, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroySceneJobThread(TEngine *tEngine, TScene *tScene, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGradingJobThread(TEngine *tEngine, TColorGrading *tColorGrading, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialJobThread(TEngine *tEngine, TMaterial *tMaterial, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceJobThread(TEngine *tEngine, TMaterialInstance *tMaterialInstance, uint32_t requestId,  VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxJobThread(TEngine *tEngine, TSkybox *tSkybox, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightJobThread(TEngine *tEngine, TIndirectLight *tIndirectLight, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Texture_buildJobThread(TEngine *engine,
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
        EMSCRIPTEN_KEEPALIVE void Texture_setExternalImageJobThread(TEngine *tEngine, TTexture *tTexture, void *externalImage, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Texture_generateMipMapsJobThread(TTexture *tTexture, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Ktx1Reader_createTextureJobThread(TEngine *tEngine, TKtx1Bundle *tBundle, uint32_t requestId, VoidCallback onTextureUploadComplete, void (*onComplete)(TTexture *));
        EMSCRIPTEN_KEEPALIVE void Ktx2Reader_createTextureJobThread(TEngine *tEngine, uint8_t *data, size_t size, void (*onComplete)(TTexture *));

        EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureJobThread(TEngine *engine, TTexture* tTexture, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createFenceJobThread(TEngine *tEngine, void (*onComplete)(TFence*));
        EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroyJobThread(TFence *tFence, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceJobThread(TEngine *tEngine, TFence *tFence, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitJobThread(TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_executeJobThread(TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxJobThread(TEngine *tEngine, TTexture *tTexture, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildColoredSkyboxJobThread(TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceTextureJobThread(TEngine *tEngine, TTexture *tReflectionsTexture, TTexture* tIrradianceTexture, float intensity, void (*onComplete)(TIndirectLight *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceHarmonicsJobThread(TEngine *tEngine, TTexture *tReflectionsTexture, float *harmonics, float intensity, void (*onComplete)(TIndirectLight *));

        EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptionsJobThread(TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameJobThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool));
        EMSCRIPTEN_KEEPALIVE void Renderer_endFrameJobThread(TRenderer *tRenderer, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_renderJobThread(TRenderer *tRenderer, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewJobThread(TRenderer *tRenderer, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_readPixelsJobThread(
            TRenderer *tRenderer,
            uint32_t width, uint32_t height, uint32_t xOffset, uint32_t yOffset,
            TRenderTarget *tRenderTarget,
            TPixelDataFormat tPixelBufferFormat,
            TPixelDataType tPixelDataType,
            uint8_t *out,
            size_t outLength,
            uint32_t requestId,  VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Material_createInstanceJobThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *));
        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTextureJobThread(TMaterialInstance *tMaterialInstance, const char *propertyName, TTexture* tTexture, TTextureSampler* tSampler, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialJobThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createGizmoMaterialJobThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createBoneOverlayMaterialJobThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createSilhouetteMaterialJobThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createEdgeOutlineMaterialJobThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createWireframeMaterialJobThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createTranslationAxisMaterialJobThread(TEngine *tEngine, void (*onComplete)(TMaterial *));

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_createJobThread(void (*onComplete)(TColorGradingBuilder *));
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_buildJobThread(TColorGradingBuilder *tBuilder, TEngine *tEngine, void (*onComplete)(TColorGrading *));
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_destroyJobThread(TColorGradingBuilder *tBuilder, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void ToneMapper_createLinearJobThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESJobThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESLegacyJobThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createFilmicJobThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createPBRNeutralJobThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXJobThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXWithLookJobThread(TEngine *tEngine, int look, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createGenericJobThread(TEngine *tEngine, float contrast, float midGrayIn, float midGrayOut, float hdrMax, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createDisplayRangeJobThread(TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_destroyJobThread(TToneMapper *tToneMapper, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void View_pickJobThread(TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback);
        EMSCRIPTEN_KEEPALIVE void View_setColorGradingJobThread(TView *tView, TColorGrading *tColorGrading, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setBloomJobThread(TView *tView, bool enabled, double strength, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setCameraJobThread(TView *tView, TCamera *tCamera, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_getNameJobThread(TView *tView, void (*onComplete)(const char *));
        EMSCRIPTEN_KEEPALIVE void View_setNameJobThread(TView *tView, const char *name, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setViewportJobThread(TView *tView, uint32_t width, uint32_t height, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setRenderTargetJobThread(TView *tView, TRenderTarget *tRenderTarget, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setAntiAliasingJobThread(TView *tView, bool msaa, bool fxaa, bool taa, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setPostProcessingJobThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabledJobThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabledJobThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setDitheringEnabledJobThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setRenderQualityJobThread(TView *tView, int qualityLevel, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setSceneJobThread(TView *tView, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setLayerEnabledJobThread(TView *tView, int layer, bool visible, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setBlendModeJobThread(TView *tView, int blendMode, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFogOptionsJobThread(TView *tView, TFogOptions tFogOptions, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setAmbientOcclusionOptionsJobThread(TView *tView, TAmbientOcclusionOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFrontFaceWindingInvertedJobThread(TView *tView, bool inverted, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabledJobThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setShadowTypeJobThread(TView *tView, int shadowType, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptionsJobThread(TView *tView, TSoftShadowOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setVsmShadowOptionsJobThread(TView *tView, TVsmShadowOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabledJobThread(TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyJobThread(TSceneAsset *tSceneAsset, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromFilamentAssetJobThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            TNameComponentManager *tNameComponentManager,
            TFilamentAsset *tFilamentAsset,
            uint32_t requiredGeometryCapabilities,
            void (*onComplete)(TSceneAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromBuffersJobThread(
            TEngine *tEngine,
            TVertexBuffer *tVertexBuffer,
            TIndexBuffer *tIndexBuffer,
            TMaterialInstance **materialInstances,
            int materialInstanceCount,
            TPrimitiveType tPrimitiveType,
            TVertexBufferStorageMode vertexBufferStorageMode,
            Aabb3 boundingBox,
            void (*callback)(TSceneAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceJobThread(TSceneAsset *asset, TMaterialInstance **tMaterialInstances, int materialInstanceCount, void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceDataJobThread(TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShadingJobThread(TSceneAsset *tSceneAsset, bool flatShading, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceJobThread(
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

        EMSCRIPTEN_KEEPALIVE void AnimationManager_updateJobThread(TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationTimeJobThread(
            TAnimationManager *tAnimationManager,
            TSceneAsset *tSceneAsset,
            int animationIndex,
            float timeInSeconds,
            uint32_t requestId,
            VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void AnimationManager_updateBoneMatricesJobThread(
            TAnimationManager *tAnimationManager,
            TSceneAsset *sceneAsset,
            void (*callback)(bool));

        EMSCRIPTEN_KEEPALIVE void AnimationManager_setMorphTargetWeightsJobThread(
            TAnimationManager *tAnimationManager,
            EntityId entityId,
            const float *const morphData,
            int numWeights,
            void (*callback)(bool));

        // Image methods
        EMSCRIPTEN_KEEPALIVE void Image_createEmptyJobThread(uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *));
        EMSCRIPTEN_KEEPALIVE void Image_decodeJobThread(uint8_t* data, size_t length, const char* name, bool alpha, void (*onComplete)(TLinearImage *));
        EMSCRIPTEN_KEEPALIVE void Image_getBytesJobThread(TLinearImage *tLinearImage, void (*onComplete)(float *));
        EMSCRIPTEN_KEEPALIVE void Image_destroyJobThread(TLinearImage *tLinearImage, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Image_getWidthJobThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getHeightJobThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getChannelsJobThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));


        EMSCRIPTEN_KEEPALIVE void Texture_loadImageJobThread(
            TEngine *tEngine,
            TTexture *tTexture,
            TLinearImage *tImage,
            TPixelDataFormat bufferFormat,
            TPixelDataType pixelDataType,
            int level,
            void (*onComplete)(bool)
        );
        EMSCRIPTEN_KEEPALIVE void Texture_setImageJobThread(
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
        EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureJobThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *));
        EMSCRIPTEN_KEEPALIVE void RenderTarget_createJobThread(
            TEngine *tEngine,
            TTexture *color,
            TTexture *depth,
            void (*onComplete)(TRenderTarget *)
        );
        EMSCRIPTEN_KEEPALIVE void RenderTarget_destroyJobThread(
            TEngine *tEngine,
            TRenderTarget *tRenderTarget,
            uint32_t requestId, VoidCallback onComplete
        );


        // TextureSampler methods
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createJobThread(void (*onComplete)(TTextureSampler*));
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithFilteringJobThread(
            TSamplerMinFilter minFilter,
            TSamplerMagFilter magFilter,
            TSamplerWrapMode wrapS,
            TSamplerWrapMode wrapT,
            TSamplerWrapMode wrapR,
            void (*onComplete)(TTextureSampler*)
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithComparisonJobThread(
            TSamplerCompareMode compareMode,
            TSamplerCompareFunc compareFunc,
            void (*onComplete)(TTextureSampler*)
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilterJobThread(
            TTextureSampler* sampler,
            TSamplerMinFilter filter,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterJobThread(
            TTextureSampler* sampler,
            TSamplerMagFilter filter,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSJobThread(
            TTextureSampler* sampler,
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTJobThread(
            TTextureSampler* sampler,
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRJobThread(
            TTextureSampler* sampler,
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyJobThread(
            TTextureSampler* sampler,
            double anisotropy,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeJobThread(
            TTextureSampler* sampler,
            TSamplerCompareMode mode,
            TTextureSamplerCompareFunc func,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyJobThread(
            TTextureSampler* sampler,
            uint32_t requestId, VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPoseJobThread(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createJobThread(TEngine *tEngine, TMaterialProvider *tMaterialProvider, TNameComponentManager *tNameComponentManager, void (*callback)(TGltfAssetLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_destroyJobThread(TGltfAssetLoader *tAssetLoader, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createJobThread(TEngine *tEngine, void (*callback)(TGltfResourceLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroyJobThread(TEngine *tEngine, TGltfResourceLoader *tResourceLoader, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_loadResourcesJobThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceDataJobThread(TGltfResourceLoader *tGltfResourceLoader, const char *uri, uint8_t *data, size_t length, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncBeginLoadJobThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoadJobThread(TGltfResourceLoader *tGltfResourceLoader);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncGetLoadProgressJobThread(TGltfResourceLoader *tGltfResourceLoader, void (*callback)(float));

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadJobThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            uint8_t *data,
            size_t length,
            uint32_t numInstances,
            void (*callback)(TFilamentAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetJobThread(TScene* tScene, TFilamentAsset *tAsset, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void FilamentAsset_getWireframeJobThread(TFilamentAsset *tFilamentAsset, void (*onComplete)(EntityId));
        EMSCRIPTEN_KEEPALIVE void Scene_addEntityJobThread(TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_removeEntityJobThread(TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_addToSceneJobThread(TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromSceneJobThread(TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_setSkyboxJobThread(TScene *tScene, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLightJobThread(TScene *tScene, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Gizmo_createJobThread(
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
        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_buildJobThread(
            TVertexBufferBuilder *tBuilder,
            TEngine *tEngine,
            void (*onComplete)(TVertexBuffer *)
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_destroyJobThread(
            TEngine *tEngine,
            TVertexBuffer *tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferAtJobThread(
            TEngine* tEngine,
            TVertexBuffer* tBuffer,
            uint8_t bufferIndex,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferObjectAtJobThread(
            TEngine* tEngine,
            TVertexBuffer* tBuffer,
            uint8_t bufferIndex,
            TBufferObject* tBufferObject,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void BufferObjectBuilder_buildJobThread(
            TBufferObjectBuilder* tBuilder,
            TEngine* tEngine,
            void (*onComplete)(TBufferObject*)
        );
        EMSCRIPTEN_KEEPALIVE void BufferObject_setBufferJobThread(
            TEngine* tEngine,
            TBufferObject* tBuffer,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void BufferObject_destroyJobThread(
            TEngine* tEngine,
            TBufferObject* tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );

        // IndexBuffer render thread methods
        EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_buildJobThread(
            TIndexBufferBuilder *tBuilder,
            TEngine *tEngine,
            void (*onComplete)(TIndexBuffer *)
        );
        EMSCRIPTEN_KEEPALIVE void IndexBuffer_destroyJobThread(
            TEngine *tEngine,
            TIndexBuffer *tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void IndexBuffer_setBufferJobThread(
            TEngine* tEngine,
            TIndexBuffer* tBuffer,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        // RenderableBuilder render thread methods
        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildJobThread(
            TRenderableBuilder *tBuilder,
            TEngine *tEngine,
            EntityId entityId,
            void (*onComplete)(int)
        );

        // Copy skinning data before returning, then apply it and build in one
        // render-thread task. data contains boneCount * 8 floats for Bone data,
        // or boneCount * 16 floats for matrices. The task releases the copy.
        // Keep tBuilder alive until onComplete, as with buildJobThread.
        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildWithSkinningJobThread(
            TRenderableBuilder *tBuilder,
            TEngine *tEngine,
            EntityId entityId,
            size_t boneCount,
            const float *data,
            bool boneData,
            void (*onComplete)(int)
        );

        EMSCRIPTEN_KEEPALIVE void EntityManager_createEntityJobThread(TEntityManager *tEntityManager, void (*onComplete)(EntityId));
        EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntityJobThread(TEntityManager *tEntityManager, EntityId entityId, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformJobThread(
            TTransformManager *tTransformManager,
            EntityId entityId,
            double4x4 transform,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_setParentJobThread(
            TTransformManager *tTransformManager,
            EntityId child,
            EntityId parent,
            bool preserveScaling,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_createComponentJobThread(
            TTransformManager *tTransformManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_removeComponentJobThread(
            TTransformManager *tTransformManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_destroyEntityJobThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setMorphWeightsJobThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            const float *weights,
            size_t count,
            size_t offset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromMat4JobThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            const float *transforms,
            size_t boneCount,
            size_t offset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromBoneJobThread(
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
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setGeometryAtNonIndexedJobThread(
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
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadowsJobThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadowsJobThread(
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCasterJobThread(
            TLightManager *tLightManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void LightManager_setShadowOptionsJobThread(
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
