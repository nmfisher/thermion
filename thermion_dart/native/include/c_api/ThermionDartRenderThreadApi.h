#ifndef _DART_FILAMENT_FFI_API_H
#define _DART_FILAMENT_FFI_API_H

#include "ThermionDartApi.h"
#include "TView.h"
#include "TTexture.h"
#include "TMaterialProvider.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif

        ///
        /// This header replicates most of the methods in ThermionDartApi.h.
        /// It represents the interface for:
        /// - invoking those methods that must be called on the main Filament engine thread
        /// - setting up a render loop
        ///
        typedef int32_t EntityId;
        typedef void (*FilamentRenderCallback)(void *const owner);

        EMSCRIPTEN_KEEPALIVE void RenderLoop_create();
        EMSCRIPTEN_KEEPALIVE void RenderLoop_destroy();

        EMSCRIPTEN_KEEPALIVE void Viewer_createOnRenderThread(
            void *const context,
            void *const platform,
            const char *uberArchivePath,
            const void *const loader,
            void (*renderCallback)(void *const renderCallbackOwner),
            void *const renderCallbackOwner,
            void (*callback)(TViewer *viewer));
        EMSCRIPTEN_KEEPALIVE void Viewer_createViewRenderThread(TViewer *viewer, void (*onComplete)(TView *tView));
        EMSCRIPTEN_KEEPALIVE void Viewer_destroyOnRenderThread(TViewer *viewer);
        EMSCRIPTEN_KEEPALIVE void Viewer_createSwapChainRenderThread(TViewer *viewer, void *const surface, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Viewer_createHeadlessSwapChainRenderThread(TViewer *viewer, uint32_t width, uint32_t height, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Viewer_destroySwapChainRenderThread(TViewer *viewer, TSwapChain *swapChain, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_renderRenderThread(TViewer *viewer, TView *view, TSwapChain *swapChain);
        EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderThread(TViewer *viewer, TView *view, TSwapChain *swapChain, uint8_t *out, bool useFence, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderTargetRenderThread(TViewer *viewer, TView *view, TSwapChain *swapChain, TRenderTarget *renderTarget, uint8_t *out, bool useFence, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_requestFrameRenderThread(TViewer *viewer, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_loadIblRenderThread(TViewer *viewer, const char *iblPath, float intensity, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_removeIblRenderThread(TViewer *viewer, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_createRenderTargetRenderThread(TViewer *viewer, intptr_t colorTexture, intptr_t depthTexture, uint32_t width, uint32_t height, void (*onComplete)(TRenderTarget *));
        EMSCRIPTEN_KEEPALIVE void Viewer_destroyRenderTargetRenderThread(TViewer *viewer, TRenderTarget *tRenderTarget, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_loadSkyboxRenderThread(TViewer *viewer, const char *skyboxPath, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_removeSkyboxRenderThread(TViewer *viewer, void (*onComplete)());

        EMSCRIPTEN_KEEPALIVE void Engine_createRenderThread(TBackend backend, void (*onComplete)(TEngine *));
        EMSCRIPTEN_KEEPALIVE void Engine_createRendererRenderThread(TEngine *tEngine, void (*onComplete)(TRenderer *));
        EMSCRIPTEN_KEEPALIVE void Engine_createSwapChainRenderThread(TEngine *tEngine, void *window, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createHeadlessSwapChainRenderThread(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Engine_createCameraRenderThread(TEngine* tEngine, void (*onComplete)(TCamera *));
        EMSCRIPTEN_KEEPALIVE void Engine_createViewRenderThread(TEngine *tEngine, void (*onComplete)(TView *));
        EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t *materialData, size_t length, void (*onComplete)(TMaterial *));
        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, void (*onComplete)());
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

        EMSCRIPTEN_KEEPALIVE void View_setToneMappingRenderThread(TView *tView, TEngine *tEngine, thermion::ToneMapping toneMapping);
        EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, bool enabled, double strength);
        EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, void (*callback)());

        FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback);
        EMSCRIPTEN_KEEPALIVE void set_rendering_render_thread(TViewer *viewer, bool rendering, void (*onComplete)());

        EMSCRIPTEN_KEEPALIVE void set_frame_interval_render_thread(TViewer *viewer, float frameInterval);
        EMSCRIPTEN_KEEPALIVE void set_background_color_render_thread(TViewer *viewer, const float r, const float g, const float b, const float a);
        EMSCRIPTEN_KEEPALIVE void clear_background_image_render_thread(TViewer *viewer);
        EMSCRIPTEN_KEEPALIVE void set_background_image_render_thread(TViewer *viewer, const char *path, bool fillHeight, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void set_background_image_position_render_thread(TViewer *viewer, float x, float y, bool clamp);

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
        EMSCRIPTEN_KEEPALIVE void Texture_loadImageRenderThread(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage, TPixelDataFormat bufferFormat, TPixelDataType pixelDataType, void (*onComplete)(bool));
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

        EMSCRIPTEN_KEEPALIVE void update_bone_matrices_render_thread(TSceneManager *sceneManager,
                                                                     EntityId asset, void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void set_bone_transform_render_thread(
            TSceneManager *sceneManager,
            EntityId asset,
            int skinIndex,
            int boneIndex,
            const float *const transform,
            void (*callback)(bool));
        EMSCRIPTEN_KEEPALIVE void set_post_processing_render_thread(TViewer *viewer, bool enabled);
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

#endif // _DART_FILAMENT_FFI_API_H
