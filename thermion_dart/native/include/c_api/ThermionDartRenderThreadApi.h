#pragma once

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
        typedef void (*VoidCallback)();
        typedef int32_t EntityId;
        typedef void (*FilamentRenderCallback)(void *const owner);

        void RenderThread_create();
        void RenderThread_destroy();
        void RenderThread_requestFrameAsync();
        void RenderThread_setRenderTicker(TRenderTicker *tRenderTicker);
        void RenderThread_addTask(void (*task)());
        
        void RenderTicker_renderRenderThread(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos, VoidCallback onComplete);
        void AnimationManager_createRenderThread(TEngine *tEngine, TScene *tScene, void (*onComplete)(TAnimationManager *));

        void Engine_createRenderThread(
            TBackend backend,
            void* platform,
            void* sharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck,
            void (*onComplete)(TEngine *)
        );
        void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *));
        void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *));
        void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *));
        void Engine_createCameraRenderThread(TEngine* tEngine, void (*onComplete)(TCamera *));
        void Engine_createViewRenderThread(TEngine *tEngine, void (*onComplete)(TView *));
        void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *));
        void Engine_destroyRenderThread(TEngine *tEngine, VoidCallback onComplete);
        void Engine_destroySwapChainRenderThread(TEngine *tEngine, TSwapChain *tSwapChain, VoidCallback onComplete);
        void Engine_destroyViewRenderThread(TEngine *tEngine, TView *tView, VoidCallback onComplete);
        void Engine_destroySceneRenderThread(TEngine *tEngine, TScene *tScene, VoidCallback onComplete);
        void Engine_destroyColorGradingRenderThread(TEngine *tEngine, TColorGrading *tColorGrading, VoidCallback onComplete);
        void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, VoidCallback onComplete);
        void Engine_destroyMaterialInstanceRenderThread(TEngine *tEngine, TMaterialInstance *tMaterialInstance, VoidCallback onComplete);
        void Engine_destroySkyboxRenderThread(TEngine *tEngine, TSkybox *tSkybox, VoidCallback onComplete);
        void Engine_destroyIndirectLightRenderThread(TEngine *tEngine, TIndirectLight *tIndirectLight, VoidCallback onComplete);
        void Texture_buildRenderThread(TEngine *engine, 
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

        void Engine_destroyTextureRenderThread(TEngine *engine, TTexture* tTexture, VoidCallback onComplete);
        void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence*));
        void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, VoidCallback onComplete);
        void Engine_flushAndWaitRenderThread(TEngine *tEngine, VoidCallback onComplete);
        void Engine_executeRenderThread(TEngine *tEngine, VoidCallback onComplete);
        void Engine_buildSkyboxRenderThread(TEngine *tEngine, uint8_t *skyboxData, size_t length, void (*onComplete)(TSkybox *), void (*onTextureUploadComplete)());
        void Engine_buildIndirectLightRenderThread(TEngine *tEngine, uint8_t *iblData, size_t length, float intensity, void (*onComplete)(TIndirectLight *), void (*onTextureUploadComplete)());

        void Renderer_setClearOptionsRenderThread(TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard, VoidCallback onComplete);
        void Renderer_beginFrameRenderThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool));
        void Renderer_endFrameRenderThread(TRenderer *tRenderer, VoidCallback onComplete);
        void Renderer_renderRenderThread(TRenderer *tRenderer, TView *tView, VoidCallback onComplete);
        void Renderer_renderStandaloneViewRenderThread(TRenderer *tRenderer, TView *tView, VoidCallback onComplete);
        void Renderer_readPixelsRenderThread(
            TRenderer *tRenderer,
            TView *tView,
            TRenderTarget *tRenderTarget,
            TPixelDataFormat tPixelBufferFormat,
            TPixelDataType tPixelDataType,
            uint8_t *out,
            size_t outLength,
            VoidCallback onComplete);

        void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *));
        void Material_createImageMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));
        void Material_createGizmoMaterialRenderThread(TEngine *tEngine, void (*onComplete)(TMaterial *));

        void ColorGrading_createRenderThread(TEngine *tEngine, TToneMapping toneMapping, void (*callback)(TColorGrading *));  
        void View_setColorGradingRenderThread(TView *tView, TColorGrading *tColorGrading, VoidCallback onComplete);
        void View_setBloomRenderThread(TView *tView, bool enabled, double strength, VoidCallback onComplete);
        void View_setCameraRenderThread(TView *tView, TCamera *tCamera, VoidCallback onComplete);

        FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback);

        void SceneAsset_destroyRenderThread(TSceneAsset *tSceneAsset, VoidCallback onComplete);
        void SceneAsset_createFromFilamentAssetRenderThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            TNameComponentManager *tNameComponentManager,
            TFilamentAsset *tFilamentAsset,
            void (*onComplete)(TSceneAsset *)
        );
        void SceneAsset_createInstanceRenderThread(TSceneAsset *asset, TMaterialInstance **tMaterialInstances, int materialInstanceCount, void (*callback)(TSceneAsset *));
        void SceneAsset_createGeometryRenderThread(
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
        void MaterialProvider_createMaterialInstanceRenderThread(TMaterialProvider *tMaterialProvider, TMaterialKey *tKey, void (*callback)(TMaterialInstance *));

        void AnimationManager_updateBoneMatricesRenderThread(
            TAnimationManager *tAnimationManager,
            TSceneAsset *sceneAsset,
            void (*callback)(bool));

        void AnimationManager_setMorphTargetWeightsRenderThread(
            TAnimationManager *tAnimationManager,
            EntityId entityId,
            const float *const morphData,
            int numWeights,
            void (*callback)(bool));

        // Image methods
        void Image_createEmptyRenderThread(uint32_t width, uint32_t height, uint32_t channel, void (*onComplete)(TLinearImage *));
        void Image_decodeRenderThread(uint8_t* data, size_t length, const char* name, void (*onComplete)(TLinearImage *));
        void Image_getBytesRenderThread(TLinearImage *tLinearImage, void (*onComplete)(float *));
        void Image_destroyRenderThread(TLinearImage *tLinearImage, VoidCallback onComplete);
        void Image_getWidthRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        void Image_getHeightRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        void Image_getChannelsRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));


        void Texture_loadImageRenderThread(
            TEngine *tEngine,
            TTexture *tTexture,
            TLinearImage *tImage,
            TPixelDataFormat bufferFormat,
            TPixelDataType pixelDataType,
            void (*onComplete)(bool)
        );
        void Texture_setImageRenderThread(
            TEngine *tEngine,
            TTexture *tTexture,
            uint32_t level,
            uint8_t *data,
            size_t size,
            uint32_t width,
            uint32_t height,
            uint32_t channels,
            uint32_t bufferFormat,
            uint32_t pixelDataType,
            void (*onComplete)(bool)
        );
        void Texture_setImageWithDepthRenderThread(
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
            uint32_t channels,
            uint32_t depth,
            uint32_t bufferFormat,
            uint32_t pixelDataType,
            void (*onComplete)(bool)
        );
        void RenderTarget_getColorTextureRenderThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *));
        void RenderTarget_createRenderThread(
            TEngine *tEngine,
            uint32_t width,
            uint32_t height,
            TTexture *color,
            TTexture *depth,
            void (*onComplete)(TRenderTarget *)
        );
        void RenderTarget_destroyRenderThread(
            TEngine *tEngine,
            TRenderTarget *tRenderTarget,
            VoidCallback onComplete
        );


        // TextureSampler methods
        void TextureSampler_createRenderThread(void (*onComplete)(TTextureSampler*));
        void TextureSampler_createWithFilteringRenderThread(
            TSamplerMinFilter minFilter, 
            TSamplerMagFilter magFilter, 
            TSamplerWrapMode wrapS, 
            TSamplerWrapMode wrapT, 
            TSamplerWrapMode wrapR,
            void (*onComplete)(TTextureSampler*)
        );
        void TextureSampler_createWithComparisonRenderThread(
            TSamplerCompareMode compareMode, 
            TSamplerCompareFunc compareFunc,
            void (*onComplete)(TTextureSampler*)
        );
        void TextureSampler_setMinFilterRenderThread(
            TTextureSampler* sampler, 
            TSamplerMinFilter filter,
            VoidCallback onComplete
        );
        void TextureSampler_setMagFilterRenderThread(
            TTextureSampler* sampler, 
            TSamplerMagFilter filter,
            VoidCallback onComplete
        );
        void TextureSampler_setWrapModeSRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            VoidCallback onComplete
        );
        void TextureSampler_setWrapModeTRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            VoidCallback onComplete
        );
        void TextureSampler_setWrapModeRRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            VoidCallback onComplete
        );
        void TextureSampler_setAnisotropyRenderThread(
            TTextureSampler* sampler, 
            double anisotropy,
            VoidCallback onComplete
        );
        void TextureSampler_setCompareModeRenderThread(
            TTextureSampler* sampler, 
            TSamplerCompareMode mode, 
            TTextureSamplerCompareFunc func,
            VoidCallback onComplete
        );
        void TextureSampler_destroyRenderThread(
            TTextureSampler* sampler,
            VoidCallback onComplete
        );

        void AnimationManager_setBoneTransformRenderThread(
            TAnimationManager *tAnimationManager,
            EntityId asset,
            int skinIndex,
            int boneIndex,
            const float *const transform,
            void (*callback)(bool));

        void AnimationManager_resetToRestPoseRenderThread(TAnimationManager *tAnimationManager, EntityId entityId, VoidCallback onComplete);

        void GltfAssetLoader_createRenderThread(TEngine *tEngine, TMaterialProvider *tMaterialProvider, void (*callback)(TGltfAssetLoader *));
        void GltfResourceLoader_createRenderThread(TEngine *tEngine, const char* relativeResourcePath, void (*callback)(TGltfResourceLoader *));
        void GltfResourceLoader_destroyRenderThread(TEngine *tEngine, TGltfResourceLoader *tResourceLoader, VoidCallback onComplete);
        void GltfResourceLoader_loadResourcesRenderThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        void GltfResourceLoader_addResourceDataRenderThread(TGltfResourceLoader *tGltfResourceLoader, const char *uri, uint8_t *data, size_t length, VoidCallback onComplete);
        void GltfResourceLoader_asyncBeginLoadRenderThread(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset, void (*callback)(bool));
        void GltfResourceLoader_asyncUpdateLoadRenderThread(TGltfResourceLoader *tGltfResourceLoader);
        void GltfResourceLoader_asyncGetLoadProgressRenderThread(TGltfResourceLoader *tGltfResourceLoader, void (*callback)(float));

        void GltfAssetLoader_loadRenderThread(
            TEngine *tEngine,
            TGltfAssetLoader *tAssetLoader,
            uint8_t *data,
            size_t length,
            uint8_t numInstances,
            void (*callback)(TFilamentAsset *)
        );
        void Scene_addFilamentAssetRenderThread(TScene* tScene, TFilamentAsset *tAsset, VoidCallback onComplete);
        void Gizmo_createRenderThread(
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

