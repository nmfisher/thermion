#pragma once

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

        EMSCRIPTEN_KEEPALIVE void RenderLoop_create();
        EMSCRIPTEN_KEEPALIVE void RenderLoop_destroy();
        EMSCRIPTEN_KEEPALIVE void RenderLoop_requestAnimationFrame(void (*onComplete));
        EMSCRIPTEN_KEEPALIVE void RenderTicker_renderRenderThread(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos);
        // EMSCRIPTEN_KEEPALIVE void RenderLoop_addTask(TRenderLoop* tRenderLoop, void (*task)());

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
        EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChainRenderThread(TEngine *tEngine, TSwapChain *tSwapChain, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstanceRenderThread(TEngine *tEngine, TMaterialInstance *tMaterialInstance, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_destroySkyboxRenderThread(TEngine *tEngine, TSkybox *tSkybox, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLightRenderThread(TEngine *tEngine, TIndirectLight *tIndirectLight, void (*onComplete)());
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
        EMSCRIPTEN_KEEPALIVE void Engine_destroyTextureRenderThread(TEngine *engine, TTexture* tTexture, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_createFenceRenderThread(TEngine *tEngine, void (*onComplete)(TFence*));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyFenceRenderThread(TEngine *tEngine, TFence *tFence, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWaitRenderThead(TEngine *tEngine, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_buildSkyboxRenderThread(TEngine *tEngine, uint8_t *skyboxData, size_t length, void (*onComplete)(TSkybox *), void (*onTextureUploadComplete)());
        EMSCRIPTEN_KEEPALIVE void Engine_buildIndirectLightRenderThread(TEngine *tEngine, uint8_t *iblData, size_t length, float intensity, void (*onComplete)(TIndirectLight *), void (*onTextureUploadComplete)());

        EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptionsRenderThread(TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Renderer_beginFrameRenderThread(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos, void (*onComplete)(bool));
        EMSCRIPTEN_KEEPALIVE void Renderer_endFrameRenderThread(TRenderer *tRenderer, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Renderer_renderRenderThread(TRenderer *tRenderer, TView *tView, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneViewRenderThread(TRenderer *tRenderer, TView *tView, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Renderer_readPixelsRenderThread(
            TRenderer *tRenderer,
            TView *tView,
            TRenderTarget *tRenderTarget,
            TPixelDataFormat tPixelBufferFormat,
            TPixelDataType tPixelDataType,
            uint8_t *out,
            void (*onComplete)());

        EMSCRIPTEN_KEEPALIVE void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance *));

        EMSCRIPTEN_KEEPALIVE void View_setToneMappingRenderThread(TView *tView, TEngine *tEngine, ToneMapping toneMapping);
        EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength);
        EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, void (*callback)());

        FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback);

        EMSCRIPTEN_KEEPALIVE void SceneManager_createGridRenderThread(TSceneManager *tSceneManager, TMaterial *tMaterial, void (*callback)(TSceneAsset *));

        EMSCRIPTEN_KEEPALIVE TGizmo *SceneManager_createGizmoRenderThread(
            TSceneManager *tSceneManager,
            TView *tView,
            TScene *tScene,
            TGizmoType tGizmoType,
            void (*onComplete)(TGizmo *));

        EMSCRIPTEN_KEEPALIVE void SceneManager_createGeometryRenderThread(
            TSceneManager *sceneManager,
            float *vertices,
            int numVertices,
            float *normals,
            int numNormals,
            float *uvs,
            int numUvs,
            uint16_t *indices,
            int numIndices,
            int primitiveType,
            TMaterialInstance **materialInstances,
            int materialInstanceCount,
            bool keepData,
            void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneManager_loadGlbFromBufferRenderThread(TSceneManager *sceneManager, const uint8_t *const data, size_t length, int numInstances, bool keepData, int priority, int layer, bool loadResourcesAsync, void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneManager_createUnlitMaterialInstanceRenderThread(TSceneManager *sceneManager, void (*callback)(TMaterialInstance *));
        EMSCRIPTEN_KEEPALIVE void SceneManager_createUnlitFixedSizeMaterialInstanceRenderThread(TSceneManager *sceneManager, void (*callback)(TMaterialInstance *));
        EMSCRIPTEN_KEEPALIVE void SceneManager_loadGlbRenderThread(TSceneManager *sceneManager, const char *assetPath, int numInstances, bool keepData, void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneManager_loadGltfRenderThread(TSceneManager *sceneManager, const char *assetPath, const char *relativePath, bool keepData, void (*callback)(TSceneAsset *));
        EMSCRIPTEN_KEEPALIVE void SceneManager_destroyAllRenderThread(TSceneManager *tSceneManager, void (*callback)());
        EMSCRIPTEN_KEEPALIVE void SceneManager_destroyAssetRenderThread(TSceneManager *tSceneManager, TSceneAsset *sceneAsset, void (*callback)());
        EMSCRIPTEN_KEEPALIVE void SceneManager_destroyAssetsRenderThread(TSceneManager *tSceneManager, void (*callback)());
        EMSCRIPTEN_KEEPALIVE void SceneManager_destroyLightsRenderThread(TSceneManager *tSceneManager, void (*callback)());
        EMSCRIPTEN_KEEPALIVE void SceneManager_addLightRenderThread(
            TSceneManager *tSceneManager,
            uint8_t type,
            float colour,
            float intensity,
            float posX,
            float posY,
            float posZ,
            float dirX,
            float dirY,
            float dirZ,
            float falloffRadius,
            float spotLightConeInner,
            float spotLightConeOuter,
            float sunAngularRadius,
            float sunHaloSize,
            float sunHaloFallof,
            bool shadows,
            void (*callback)(EntityId));
        EMSCRIPTEN_KEEPALIVE void SceneManager_removeLightRenderThread(TSceneManager *tSceneManager, EntityId entityId, void (*callback)());
        EMSCRIPTEN_KEEPALIVE void SceneManager_createCameraRenderThread(TSceneManager *tSceneManager, void (*callback)(TCamera *));
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
        EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceRenderThread(TMaterialProvider *tMaterialProvider, TMaterialKey *tKey, void (*callback)(TMaterialInstance *));
        EMSCRIPTEN_KEEPALIVE void SceneManager_destroyMaterialInstanceRenderThread(TSceneManager *tSceneManager, TMaterialInstance *tMaterialInstance, void (*callback)());

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
        EMSCRIPTEN_KEEPALIVE void Image_decodeRenderThread(uint8_t* data, size_t length, const char* name, void (*onComplete)(TLinearImage *));
        EMSCRIPTEN_KEEPALIVE void Image_getBytesRenderThread(TLinearImage *tLinearImage, void (*onComplete)(float *));
        EMSCRIPTEN_KEEPALIVE void Image_destroyRenderThread(TLinearImage *tLinearImage, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Image_getWidthRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getHeightRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));
        EMSCRIPTEN_KEEPALIVE void Image_getChannelsRenderThread(TLinearImage *tLinearImage, void (*onComplete)(uint32_t));

        // Texture methods
        EMSCRIPTEN_KEEPALIVE void Texture_buildRenderThread(TEngine *engine, 
            uint32_t width, 
            uint32_t height, 
            uint32_t depth, 
            uint8_t levels, 
            uint16_t tUsage,
            intptr_t import,
            TTextureSamplerType sampler, 
            TTextureFormat format,
            void (*onComplete)(TTexture *)
        );

        EMSCRIPTEN_KEEPALIVE void Texture_loadImageRenderThread(
            TEngine *tEngine,
            TTexture *tTexture,
            TLinearImage *tImage,
            TPixelDataFormat bufferFormat,
            TPixelDataType pixelDataType,
            void (*onComplete)(bool)
        );
        EMSCRIPTEN_KEEPALIVE void Texture_setImageRenderThread(
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
        EMSCRIPTEN_KEEPALIVE void Texture_setImageWithDepthRenderThread(
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
        EMSCRIPTEN_KEEPALIVE void RenderTarget_getColorTextureRenderThread(TRenderTarget *tRenderTarget, void (*onComplete)(TTexture *));
        EMSCRIPTEN_KEEPALIVE void RenderTarget_createRenderThread(
            TEngine *tEngine,
            uint32_t width,
            uint32_t height,
            TTexture *color,
            TTexture *depth,
            void (*onComplete)(TRenderTarget *)
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
            void (*onComplete)()
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilterRenderThread(
            TTextureSampler* sampler, 
            TSamplerMagFilter filter,
            void (*onComplete)()
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeSRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            void (*onComplete)()
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeTRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            void (*onComplete)()
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeRRenderThread(
            TTextureSampler* sampler, 
            TSamplerWrapMode mode,
            void (*onComplete)()
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropyRenderThread(
            TTextureSampler* sampler, 
            double anisotropy,
            void (*onComplete)()
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareModeRenderThread(
            TTextureSampler* sampler, 
            TSamplerCompareMode mode, 
            TTextureSamplerCompareFunc func,
            void (*onComplete)()
        );
        EMSCRIPTEN_KEEPALIVE void TextureSampler_destroyRenderThread(
            TTextureSampler* sampler,
            void (*onComplete)()
        );

        EMSCRIPTEN_KEEPALIVE void AnimationManager_updateBoneMatricesRenderThread(TSceneManager *sceneManager,
                                                                     EntityId asset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void set_bone_transform_render_thread(
            TSceneManager *sceneManager,
            EntityId asset,
            int skinIndex,
            int boneIndex,
            const float *const transform,
            void (*callback)(bool));

        EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose_render_thread(TSceneManager *sceneManager, EntityId entityId, void (*callback)());

        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_createRenderThread(TEngine *tEngine, TMaterialProvider *tMaterialProvider, void (*callback)(TGltfAssetLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_createRenderThread(TEngine *tEngine, void (*callback)(TGltfResourceLoader *));
        EMSCRIPTEN_KEEPALIVE void GltfAssetLoader_loadRenderThread(
            TGltfAssetLoader *tAssetLoader,
            TGltfResourceLoader *tResourceLoader,
            uint8_t *data,
            size_t length,
            uint8_t numInstances,
            void (*callback)(TFilamentAsset *)
        );
        EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAssetRenderThread(TScene* tScene, TFilamentAsset *tAsset, void (*callback)());



#ifdef __cplusplus
    }
}
#endif

