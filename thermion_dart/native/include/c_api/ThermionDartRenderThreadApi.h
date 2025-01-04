#ifndef _DART_FILAMENT_FFI_API_H
#define _DART_FILAMENT_FFI_API_H

#include "ThermionDartApi.h"
#include "TView.h"
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

        EMSCRIPTEN_KEEPALIVE void Viewer_createOnRenderThread(
            void *const context,
            void *const platform,
            const char *uberArchivePath,
            const void *const loader,
            void (*renderCallback)(void *const renderCallbackOwner),
            void *const renderCallbackOwner,
            void (*callback)(TViewer *viewer));
        EMSCRIPTEN_KEEPALIVE void Viewer_destroyOnRenderThread(TViewer *viewer);
        EMSCRIPTEN_KEEPALIVE void Viewer_createSwapChainRenderThread(TViewer *viewer, void *const surface, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Viewer_createHeadlessSwapChainRenderThread(TViewer *viewer, uint32_t width, uint32_t height, void (*onComplete)(TSwapChain *));
        EMSCRIPTEN_KEEPALIVE void Viewer_destroySwapChainRenderThread(TViewer *viewer, TSwapChain *swapChain, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_renderRenderThread(TViewer *viewer, TView *view, TSwapChain *swapChain);
        EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderThread(TViewer *viewer, TView *view, TSwapChain *swapChain, uint8_t *out, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderTargetRenderThread(TViewer *viewer, TView *view, TSwapChain *swapChain, TRenderTarget *renderTarget, uint8_t *out, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_requestFrameRenderThread(TViewer *viewer, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_loadIblRenderThread(TViewer *viewer, const char *iblPath, float intensity, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_removeIblRenderThread(TViewer *viewer, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void Viewer_createRenderTargetRenderThread(TViewer *viewer, intptr_t texture, uint32_t width, uint32_t height, void (*onComplete)(TRenderTarget *));
        EMSCRIPTEN_KEEPALIVE void Viewer_destroyRenderTargetRenderThread(TViewer *viewer, TRenderTarget *tRenderTarget, void (*onComplete)());

        EMSCRIPTEN_KEEPALIVE void Engine_buildMaterialRenderThread(TEngine *tEngine, const uint8_t* materialData, size_t length, void (*onComplete)(TMaterial *));
	    EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialRenderThread(TEngine *tEngine, TMaterial *tMaterial, void (*onComplete)());

        EMSCRIPTEN_KEEPALIVE void Material_createInstanceRenderThread(TMaterial *tMaterial, void (*onComplete)(TMaterialInstance*));

        EMSCRIPTEN_KEEPALIVE void View_setToneMappingRenderThread(TView *tView, TEngine *tEngine, thermion::ToneMapping toneMapping);
        EMSCRIPTEN_KEEPALIVE void View_setBloomRenderThread(TView *tView, double bloom);
        EMSCRIPTEN_KEEPALIVE void View_setCameraRenderThread(TView *tView, TCamera *tCamera, void (*callback)());

        FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback);
        EMSCRIPTEN_KEEPALIVE void set_rendering_render_thread(TViewer *viewer, bool rendering, void (*onComplete)());

        EMSCRIPTEN_KEEPALIVE void set_frame_interval_render_thread(TViewer *viewer, float frameInterval);
        EMSCRIPTEN_KEEPALIVE void set_background_color_render_thread(TViewer *viewer, const float r, const float g, const float b, const float a);
        EMSCRIPTEN_KEEPALIVE void clear_background_image_render_thread(TViewer *viewer);
        EMSCRIPTEN_KEEPALIVE void set_background_image_render_thread(TViewer *viewer, const char *path, bool fillHeight, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void set_background_image_position_render_thread(TViewer *viewer, float x, float y, bool clamp);
        EMSCRIPTEN_KEEPALIVE void load_skybox_render_thread(TViewer *viewer, const char *skyboxPath, void (*onComplete)());
        EMSCRIPTEN_KEEPALIVE void remove_skybox_render_thread(TViewer *viewer);

        EMSCRIPTEN_KEEPALIVE void SceneManager_createGridRenderThread(TSceneManager *tSceneManager, TMaterial *tMaterial, void (*callback)(TSceneAsset *));

        EMSCRIPTEN_KEEPALIVE TGizmo *SceneManager_createGizmoRenderThread(
            TSceneManager *tSceneManager, 
            TView *tView, 
            TScene *tScene,
            TGizmoType tGizmoType,
            void (*onComplete)(TGizmo*)
        );

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
        EMSCRIPTEN_KEEPALIVE void *SceneManager_destroyAllRenderThread(TSceneManager *tSceneManager, void (*callback)());
        EMSCRIPTEN_KEEPALIVE void *SceneManager_destroyAssetRenderThread(TSceneManager *tSceneManager, TSceneAsset *sceneAsset, void (*callback)());
        EMSCRIPTEN_KEEPALIVE void SceneManager_createCameraRenderThread(TSceneManager *tSceneManager, void (*callback)(TCamera*));

        EMSCRIPTEN_KEEPALIVE void SceneAsset_createInstanceRenderThread(TSceneAsset *asset, TMaterialInstance **tMaterialInstances, int materialInstanceCount, void (*callback)(TSceneAsset *));

        EMSCRIPTEN_KEEPALIVE void MaterialProvider_createMaterialInstanceRenderThread(TMaterialProvider *tMaterialProvider, TMaterialKey *tKey, void (*callback)(TMaterialInstance*));
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

        EMSCRIPTEN_KEEPALIVE void unproject_texture_render_thread(TViewer *viewer, EntityId entity, uint8_t *input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight, void (*callback)());

#ifdef __cplusplus
    }
}
#endif

#endif // _DART_FILAMENT_FFI_API_H
