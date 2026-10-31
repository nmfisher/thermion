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

        // Each create call returns a separate thread handle. Pass it to every
        // queued operation for that app. Use resource handles from the same app.
        // Destroy the resources and await their jobs before destroying the thread.
        // A thread handle is invalid after JobThread_destroy().
        EMSCRIPTEN_KEEPALIVE TJobThread* JobThread_create();
        // Creates a JobThread that transfers the given canvas element
        // (CSS selector) to its worker — one thread per viewer on web.
        EMSCRIPTEN_KEEPALIVE TJobThread* JobThread_createForCanvas(const char *canvasSelector);
        EMSCRIPTEN_KEEPALIVE void JobThread_destroy(TJobThread *jobThread);

        EMSCRIPTEN_KEEPALIVE void JobThread_addTask(TJobThread *jobThread, void (*task)());
        // Borrows the matrix pointer without copying its values.
        // The caller must keep it alive and unchanged until onComplete is called.
        EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformNativeJobThread(TJobThread *jobThread, TTransformManager *manager, EntityId entity, TMat4 *matrix, uint32_t requestId, VoidCallback onComplete);
        // Copies all 16 column-major doubles before returning. The caller may
        // immediately reuse/free matrix16 while the queued task is pending.
        EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformFromBufferJobThread(TJobThread *jobThread, TTransformManager *manager, EntityId entity, const double *matrix16, uint32_t requestId, VoidCallback onComplete);
        // Detach and delete the manager on its owning thread after earlier work.
        // Stop submitting work to manager before calling. onComplete means it
        // is deleted; only then may the renderer/engine be destroyed. This does
        // not stop or wait for the worker itself.
        EMSCRIPTEN_KEEPALIVE void RenderManager_destroyJobThread(TJobThread *jobThread, TRenderManager *manager, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderableJobThread(TJobThread *jobThread, TRenderManager *tRenderer, TSwapChain *tSwapChain, TView **tViews, uint8_t numViews, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void RenderManager_renderJobThread(TJobThread *jobThread, TRenderManager *tRenderManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManagerJobThread(TJobThread *jobThread, TRenderManager *tRenderManager, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManagerJobThread(TJobThread *jobThread, TRenderManager *tRenderManager, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChainJobThread(TJobThread *jobThread, TRenderManager *tRenderManager, TSwapChain *tSwapChain, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void AnimationManager_createJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TAnimationManager *));
        EMSCRIPTEN_KEEPALIVE void AnimationManager_destroyJobThread(TJobThread *jobThread, TAnimationManager *tAnimationManager, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Engine_createJobThread(TJobThread *jobThread,
            TBackend backend,
            void* platform,
            void* sharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck,
            void (*onComplete)(TEngine *)
        );
        EMSCRIPTEN_KEEPALIVE void Engine_createRendererJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TRenderer *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyRendererJobThread(TJobThread *jobThread, TEngine *tEngine, TRenderer *tRenderer, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createCameraJobThread(TJobThread *jobThread, TEngine* tEngine, EntityId entityId, void (*onComplete)(TCamera *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyCameraJobThread(TJobThread *jobThread, TEngine *tEngine, TCamera *tCamera, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createViewJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TView *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, TSwapChain *tSwapChain, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyViewJobThread(TJobThread *jobThread, TEngine *tEngine, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroySceneJobThread(TJobThread *jobThread, TEngine *tEngine, TScene *tScene, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGradingJobThread(TJobThread *jobThread, TEngine *tEngine, TColorGrading *tColorGrading, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, TMaterial *tMaterial, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceJobThread(TJobThread *jobThread, TEngine *tEngine, TMaterialInstance *tMaterialInstance, uint32_t requestId,  VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxJobThread(TJobThread *jobThread, TEngine *tEngine, TSkybox *tSkybox, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightJobThread(TJobThread *jobThread, TEngine *tEngine, TIndirectLight *tIndirectLight, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Texture_buildJobThread(TJobThread *jobThread, TEngine *engine,
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
        EMSCRIPTEN_KEEPALIVE void Texture_setExternalImageJobThread(TJobThread *jobThread, TEngine *tEngine, TTexture *tTexture, void *externalImage, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Texture_generateMipMapsJobThread(TJobThread *jobThread, TTexture *tTexture, TEngine *tEngine, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Ktx1Reader_createTextureJobThread(TJobThread *jobThread, TEngine *tEngine, TKtx1Bundle *tBundle, uint32_t requestId, VoidCallback onTextureUploadComplete, void (*onComplete)(TTexture *));
        EMSCRIPTEN_KEEPALIVE void Ktx2Reader_createTextureJobThread(TJobThread *jobThread, TEngine *tEngine, uint8_t *data, size_t size, void (*onComplete)(TTexture *));

        EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureJobThread(TJobThread *jobThread, TEngine *engine, TTexture* tTexture, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_createFenceJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TFence*));
        EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroyJobThread(TJobThread *jobThread, TFence *tFence, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceJobThread(TJobThread *jobThread, TEngine *tEngine, TFence *tFence, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_executeJobThread(TJobThread *jobThread, TEngine *tEngine, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxJobThread(TJobThread *jobThread, TEngine *tEngine, TTexture *tTexture, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildColoredSkyboxJobThread(TJobThread *jobThread, TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority, void (*onComplete)(TSkybox *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceTextureJobThread(TJobThread *jobThread, TEngine *tEngine, TTexture *tReflectionsTexture, TTexture* tIrradianceTexture, float intensity, void (*onComplete)(TIndirectLight *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightFromIrradianceHarmonicsJobThread(TJobThread *jobThread, TEngine *tEngine, TTexture *tReflectionsTexture, float *harmonics, float intensity, void (*onComplete)(TIndirectLight *));

        EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptionsJobThread(TJobThread *jobThread, TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameJobThread(TJobThread *jobThread, TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool));
        EMSCRIPTEN_KEEPALIVE void Renderer_endFrameJobThread(TJobThread *jobThread, TRenderer *tRenderer, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_renderJobThread(TJobThread *jobThread, TRenderer *tRenderer, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewJobThread(TJobThread *jobThread, TRenderer *tRenderer, TView *tView, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Renderer_readPixelsJobThread(TJobThread *jobThread,
            TRenderer *tRenderer,
            uint32_t width, uint32_t height, uint32_t xOffset, uint32_t yOffset,
            TRenderTarget *tRenderTarget,
            TPixelDataFormat tPixelBufferFormat,
            TPixelDataType tPixelDataType,
            uint8_t *out,
            size_t outLength,
            uint32_t requestId,  VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void Material_createInstanceJobThread(TJobThread *jobThread, TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *));
        EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterTextureJobThread(TJobThread *jobThread, TMaterialInstance *tMaterialInstance, const char *propertyName, TTexture* tTexture, TTextureSampler* tSampler, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Material_createImageMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createGizmoMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createBoneOverlayMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createSilhouetteMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createEdgeOutlineMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createWireframeMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Material_createTranslationAxisMaterialJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TMaterial *));

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_createJobThread(TJobThread *jobThread, void (*onComplete)(TColorGradingBuilder *));
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_buildJobThread(TJobThread *jobThread, TColorGradingBuilder *tBuilder, TEngine *tEngine, void (*onComplete)(TColorGrading *));
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_destroyJobThread(TJobThread *jobThread, TColorGradingBuilder *tBuilder, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void ToneMapper_createLinearJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createACESLegacyJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createFilmicJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createPBRNeutralJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createAGXWithLookJobThread(TJobThread *jobThread, TEngine *tEngine, int look, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createGenericJobThread(TJobThread *jobThread, TEngine *tEngine, float contrast, float midGrayIn, float midGrayOut, float hdrMax, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_createDisplayRangeJobThread(TJobThread *jobThread, TEngine *tEngine, void (*onComplete)(TToneMapper *));
        EMSCRIPTEN_KEEPALIVE void ToneMapper_destroyJobThread(TJobThread *jobThread, TToneMapper *tToneMapper, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void View_pickJobThread(TJobThread *jobThread, TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback);
        EMSCRIPTEN_KEEPALIVE void View_setColorGradingJobThread(TJobThread *jobThread, TView *tView, TColorGrading *tColorGrading, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setBloomJobThread(TJobThread *jobThread, TView *tView, bool enabled, double strength, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setCameraJobThread(TJobThread *jobThread, TView *tView, TCamera *tCamera, uint32_t requestId,  VoidCallback onComplete);
        // Copies the name into the caller's buffer if capacity is sufficient.
        // Calls onComplete once with the required byte count, including the null
        // terminator. Zero means no name; an empty name needs one byte. A buffer
        // that is too small is left unchanged. Null with zero capacity is allowed.
        // Keep buffer alive until completion. Keep the view alive and unchanged
        // across any resize/retry calls. Size checking and copying run in one job.
        EMSCRIPTEN_KEEPALIVE void View_getNameJobThread(TJobThread *jobThread, TView *tView, char *buffer, size_t capacity, void (*onComplete)(size_t));
        EMSCRIPTEN_KEEPALIVE void View_setNameJobThread(TJobThread *jobThread, TView *tView, const char *name, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setViewportJobThread(TJobThread *jobThread, TView *tView, uint32_t width, uint32_t height, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setRenderTargetJobThread(TJobThread *jobThread, TView *tView, TRenderTarget *tRenderTarget, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setAntiAliasingJobThread(TJobThread *jobThread, TView *tView, bool msaa, bool fxaa, bool taa, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setPostProcessingJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setDitheringEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setRenderQualityJobThread(TJobThread *jobThread, TView *tView, int qualityLevel, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setSceneJobThread(TJobThread *jobThread, TView *tView, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setLayerEnabledJobThread(TJobThread *jobThread, TView *tView, int layer, bool visible, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setBlendModeJobThread(TJobThread *jobThread, TView *tView, int blendMode, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFogOptionsJobThread(TJobThread *jobThread, TView *tView, TFogOptions tFogOptions, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setAmbientOcclusionOptionsJobThread(TJobThread *jobThread, TView *tView, TAmbientOcclusionOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setFrontFaceWindingInvertedJobThread(TJobThread *jobThread, TView *tView, bool inverted, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setShadowTypeJobThread(TJobThread *jobThread, TView *tView, int shadowType, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptionsJobThread(TJobThread *jobThread, TView *tView, TSoftShadowOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setVsmShadowOptionsJobThread(TJobThread *jobThread, TView *tView, TVsmShadowOptions options, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabledJobThread(TJobThread *jobThread, TView *tView, bool enabled, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void SceneAsset_destroyJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, uint32_t requestId,  VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromFilamentAssetJobThread(TJobThread *jobThread,
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            TNameComponentManager *tNameComponentManager,
            TFilamentAsset *tFilamentAsset,
            uint32_t requiredGeometryCapabilities,
            void (*onComplete)(TSceneAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createFromBuffersJobThread(TJobThread *jobThread,
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
        EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceJobThread(TJobThread *jobThread, TSceneAsset *asset, TMaterialInstance **tMaterialInstances, int materialInstanceCount, void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceDataJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShadingJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, bool flatShading, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceJobThread(TJobThread *jobThread,
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

        EMSCRIPTEN_KEEPALIVE void AnimationManager_updateJobThread(TJobThread *jobThread, TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationTimeJobThread(TJobThread *jobThread,
            TAnimationManager *tAnimationManager,
            TSceneAsset *tSceneAsset,
            int animationIndex,
            float timeInSeconds,
            uint32_t requestId,
            VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void AnimationManager_updateBoneMatricesJobThread(TJobThread *jobThread,
            TAnimationManager *tAnimationManager,
            TSceneAsset *sceneAsset,
            void (*callback)(bool));

        EMSCRIPTEN_KEEPALIVE void AnimationManager_setMorphTargetWeightsJobThread(TJobThread *jobThread,
            TAnimationManager *tAnimationManager,
            EntityId entityId,
            const float *const morphData,
            int numWeights,
            void (*callback)(bool));

        // Image methods
        EMSCRIPTEN_KEEPALIVE void Image_createEmptyJobThread(TJobThread *jobThread, uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *));
        EMSCRIPTEN_KEEPALIVE void Image_decodeJobThread(TJobThread *jobThread, uint8_t* data, size_t length, const char* name, bool alpha, void (*onComplete)(TLinearImage *));
        EMSCRIPTEN_KEEPALIVE void Image_getBytesJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(float *));
        EMSCRIPTEN_KEEPALIVE void Image_destroyJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Image_getWidthJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getHeightJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getChannelsJobThread(TJobThread *jobThread, TLinearImage *tLinearImage, void (*onComplete)(uint32_t));


        EMSCRIPTEN_KEEPALIVE void Texture_loadImageJobThread(TJobThread *jobThread,
            TEngine *tEngine,
            TTexture *tTexture,
            TLinearImage *tImage,
            TPixelDataFormat bufferFormat,
            TPixelDataType pixelDataType,
            int level,
            void (*onComplete)(bool)
        );
        EMSCRIPTEN_KEEPALIVE void Texture_setImageJobThread(TJobThread *jobThread,
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
        EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureJobThread(TJobThread *jobThread, TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *));
        EMSCRIPTEN_KEEPALIVE void RenderTarget_createJobThread(TJobThread *jobThread,
            TEngine *tEngine,
            TTexture *color,
            TTexture *depth,
            void (*onComplete)(TRenderTarget *)
        );
        EMSCRIPTEN_KEEPALIVE void RenderTarget_destroyJobThread(TJobThread *jobThread,
            TEngine *tEngine,
            TRenderTarget *tRenderTarget,
            uint32_t requestId, VoidCallback onComplete
        );


        // TextureSampler methods
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createJobThread(TJobThread *jobThread, void (*onComplete)(TTextureSampler*));
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithFilteringJobThread(TJobThread *jobThread,
            TSamplerMinFilter minFilter,
            TSamplerMagFilter magFilter,
            TSamplerWrapMode wrapS,
            TSamplerWrapMode wrapT,
            TSamplerWrapMode wrapR,
            void (*onComplete)(TTextureSampler*)
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_createWithComparisonJobThread(TJobThread *jobThread,
            TSamplerCompareMode compareMode,
            TSamplerCompareFunc compareFunc,
            void (*onComplete)(TTextureSampler*)
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilterJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            TSamplerMinFilter filter,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            TSamplerMagFilter filter,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            TSamplerWrapMode mode,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            double anisotropy,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            TSamplerCompareMode mode,
            TTextureSamplerCompareFunc func,
            uint32_t requestId, VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyJobThread(TJobThread *jobThread,
            TTextureSampler* sampler,
            uint32_t requestId, VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPoseJobThread(TJobThread *jobThread, TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createJobThread(TJobThread *jobThread, TEngine *tEngine, TMaterialProvider *tMaterialProvider, TNameComponentManager *tNameComponentManager, void (*callback)(TGltfAssetLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_destroyJobThread(TJobThread *jobThread, TGltfAssetLoader *tAssetLoader, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createJobThread(TJobThread *jobThread, TEngine *tEngine, void (*callback)(TGltfResourceLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroyJobThread(TJobThread *jobThread, TEngine *tEngine, TGltfResourceLoader *tResourceLoader, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_loadResourcesJobThread(TJobThread *jobThread, TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceDataJobThread(TJobThread *jobThread, TGltfResourceLoader *tGltfResourceLoader, const char *uri, uint8_t *data, size_t length, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncBeginLoadJobThread(TJobThread *jobThread, TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoadJobThread(TJobThread *jobThread, TGltfResourceLoader *tGltfResourceLoader);
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncGetLoadProgressJobThread(TJobThread *jobThread, TGltfResourceLoader *tGltfResourceLoader, void (*callback)(float));

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadJobThread(TJobThread *jobThread,
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            uint8_t *data,
            size_t length,
            uint32_t numInstances,
            void (*callback)(TFilamentAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetJobThread(TJobThread *jobThread, TScene* tScene, TFilamentAsset *tAsset, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void FilamentAsset_getWireframeJobThread(TJobThread *jobThread, TFilamentAsset *tFilamentAsset, void (*onComplete)(EntityId));
        EMSCRIPTEN_KEEPALIVE void Scene_addEntityJobThread(TJobThread *jobThread, TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_removeEntityJobThread(TJobThread *jobThread, TScene *tScene, EntityId entityId, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_addToSceneJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromSceneJobThread(TJobThread *jobThread, TSceneAsset *tSceneAsset, TScene *tScene, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_setSkyboxJobThread(TJobThread *jobThread, TScene *tScene, TSkybox *tSkybox, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLightJobThread(TJobThread *jobThread, TScene *tScene, TIndirectLight *tIndirectLight, uint32_t requestId, VoidCallback onComplete);
        EMSCRIPTEN_KEEPALIVE void Gizmo_createJobThread(TJobThread *jobThread,
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
        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_buildJobThread(TJobThread *jobThread,
            TVertexBufferBuilder *tBuilder,
            TEngine *tEngine,
            void (*onComplete)(TVertexBuffer *)
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_destroyJobThread(TJobThread *jobThread,
            TEngine *tEngine,
            TVertexBuffer *tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferAtJobThread(TJobThread *jobThread,
            TEngine* tEngine,
            TVertexBuffer* tBuffer,
            uint8_t bufferIndex,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferObjectAtJobThread(TJobThread *jobThread,
            TEngine* tEngine,
            TVertexBuffer* tBuffer,
            uint8_t bufferIndex,
            TBufferObject* tBufferObject,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void BufferObjectBuilder_buildJobThread(TJobThread *jobThread,
            TBufferObjectBuilder* tBuilder,
            TEngine* tEngine,
            void (*onComplete)(TBufferObject*)
        );
        EMSCRIPTEN_KEEPALIVE void BufferObject_setBufferJobThread(TJobThread *jobThread,
            TEngine* tEngine,
            TBufferObject* tBuffer,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void BufferObject_destroyJobThread(TJobThread *jobThread,
            TEngine* tEngine,
            TBufferObject* tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );

        // IndexBuffer render thread methods
        EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_buildJobThread(TJobThread *jobThread,
            TIndexBufferBuilder *tBuilder,
            TEngine *tEngine,
            void (*onComplete)(TIndexBuffer *)
        );
        EMSCRIPTEN_KEEPALIVE void IndexBuffer_destroyJobThread(TJobThread *jobThread,
            TEngine *tEngine,
            TIndexBuffer *tBuffer,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void IndexBuffer_setBufferJobThread(TJobThread *jobThread,
            TEngine* tEngine,
            TIndexBuffer* tBuffer,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        // RenderableBuilder render thread methods
        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildJobThread(TJobThread *jobThread,
            TRenderableBuilder *tBuilder,
            TEngine *tEngine,
            EntityId entityId,
            void (*onComplete)(int)
        );

        // Copy skinning data before returning, then apply it and build in one
        // render-thread task. data contains boneCount * 8 floats for Bone data,
        // or boneCount * 16 floats for matrices. The task releases the copy.
        // Keep tBuilder alive until onComplete, as with buildJobThread.
        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_buildWithSkinningJobThread(TJobThread *jobThread,
            TRenderableBuilder *tBuilder,
            TEngine *tEngine,
            EntityId entityId,
            size_t boneCount,
            const float *data,
            bool boneData,
            void (*onComplete)(int)
        );

        EMSCRIPTEN_KEEPALIVE void EntityManager_createEntityJobThread(TJobThread *jobThread, TEntityManager *tEntityManager, void (*onComplete)(EntityId));
        EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntityJobThread(TJobThread *jobThread, TEntityManager *tEntityManager, EntityId entityId, uint32_t requestId, VoidCallback onComplete);

        EMSCRIPTEN_KEEPALIVE void TransformManager_setTransformJobThread(TJobThread *jobThread,
            TTransformManager *tTransformManager,
            EntityId entityId,
            double4x4 transform,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_setParentJobThread(TJobThread *jobThread,
            TTransformManager *tTransformManager,
            EntityId child,
            EntityId parent,
            bool preserveScaling,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_createComponentJobThread(TJobThread *jobThread,
            TTransformManager *tTransformManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void TransformManager_removeComponentJobThread(TJobThread *jobThread,
            TTransformManager *tTransformManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_destroyEntityJobThread(TJobThread *jobThread,
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setMorphWeightsJobThread(TJobThread *jobThread,
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            const float *weights,
            size_t count,
            size_t offset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromMat4JobThread(TJobThread *jobThread,
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            const float *transforms,
            size_t boneCount,
            size_t offset,
            uint32_t requestId,
            VoidCallback onComplete
        );

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromBoneJobThread(TJobThread *jobThread,
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
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setGeometryAtNonIndexedJobThread(TJobThread *jobThread,
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
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadowsJobThread(TJobThread *jobThread,
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadowsJobThread(TJobThread *jobThread,
            TRenderableManager *tRenderableManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void LightManager_setShadowCasterJobThread(TJobThread *jobThread,
            TLightManager *tLightManager,
            EntityId entityId,
            bool enabled,
            uint32_t requestId,
            VoidCallback onComplete
        );
        EMSCRIPTEN_KEEPALIVE void LightManager_setShadowOptionsJobThread(TJobThread *jobThread,
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
