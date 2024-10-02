#ifndef _DART_FILAMENT_FFI_API_H
#define _DART_FILAMENT_FFI_API_H

#include "ThermionDartApi.h"
#include "TView.h"

#ifdef __cplusplus
namespace thermion {
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

    void Viewer_createOnRenderThread(
        void *const context,
        void *const platform,
        const char *uberArchivePath,
        const void *const loader,
        void (*renderCallback)(void *const renderCallbackOwner),
        void *const renderCallbackOwner,
        void (*callback)(TViewer *viewer));
    void Viewer_createSwapChainRenderThread(TViewer *viewer, void *const surface, void (*onComplete)(TSwapChain*));
    void Viewer_createHeadlessSwapChainRenderThread(TViewer *viewer, uint32_t width, uint32_t height, void (*onComplete)(TSwapChain*));
    void Viewer_destroySwapChainRenderThread(TViewer *viewer, TSwapChain* swapChain, void (*onComplete)());
    void Viewer_renderRenderThread(TViewer *viewer, TView* view, TSwapChain* swapChain);
    void Viewer_captureRenderThread(TViewer *viewer, TView* view,  TSwapChain* swapChain, uint8_t* out, void (*onComplete)());
    void Viewer_captureRenderTargetRenderThread(TViewer *viewer, TView* view,  TSwapChain* swapChain, TRenderTarget* renderTarget, uint8_t* out, void (*onComplete)());
    void Viewer_requestFrameRenderThread(TViewer *viewer, void(*onComplete)());

    void View_setToneMappingRenderThread(TView *tView, TEngine *tEngine, thermion::ToneMapping toneMapping);
    void View_setBloomRenderThread(TView *tView, double bloom);


    void destroy_filament_viewer_render_thread(TViewer *viewer);
    
    FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback);
    void set_rendering_render_thread(TViewer *viewer, bool rendering, void(*onComplete)());
    
    void set_frame_interval_render_thread(TViewer *viewer, float frameInterval);
    void set_background_color_render_thread(TViewer *viewer, const float r, const float g, const float b, const float a);
    void clear_background_image_render_thread(TViewer *viewer);
    void set_background_image_render_thread(TViewer *viewer, const char *path, bool fillHeight, void (*onComplete)());
    void set_background_image_position_render_thread(TViewer *viewer, float x, float y, bool clamp);
    void load_skybox_render_thread(TViewer *viewer, const char *skyboxPath, void (*onComplete)());
    void remove_skybox_render_thread(TViewer *viewer);

    void SceneManager_loadGlbFromBufferRenderThread(TSceneManager *sceneManager, const uint8_t *const data, size_t length, int numInstances, bool keepData, int priority, int layer, void (*callback)(EntityId));
    void load_glb_render_thread(TSceneManager *sceneManager, const char *assetPath, int numInstances, bool keepData, void (*callback)(EntityId));
    void load_gltf_render_thread(TSceneManager *sceneManager, const char *assetPath, const char *relativePath, bool keepData, void (*callback)(EntityId));
    void create_instance_render_thread(TSceneManager *sceneManager, EntityId entityId, void (*callback)(EntityId));
    void remove_entity_render_thread(TViewer *viewer, EntityId asset, void (*callback)());
    void clear_entities_render_thread(TViewer *viewer, void (*callback)());
    
    void apply_weights_render_thread(
        TSceneManager *sceneManager,
        EntityId asset,
        const char *const entityName,
        float *const weights,
        int count);
    void set_animation_frame_render_thread(TSceneManager *sceneManager, EntityId asset, int animationIndex, int animationFrame);
    void stop_animation_render_thread(TSceneManager *sceneManager, EntityId asset, int index);
    void get_animation_count_render_thread(TSceneManager *sceneManager, EntityId asset, void (*callback)(int));
    void get_animation_name_render_thread(TSceneManager *sceneManager, EntityId asset, char *const outPtr, int index, void (*callback)());
    void get_morph_target_name_render_thread(TSceneManager *sceneManager, EntityId assetEntity, EntityId childEntity, char *const outPtr, int index, void (*callback)());
    void get_morph_target_name_count_render_thread(TSceneManager *sceneManager, EntityId asset, EntityId childEntity, void (*callback)(int32_t));
    void set_morph_target_weights_render_thread(TSceneManager *sceneManager,
                                                            EntityId asset,
                                                            const float *const morphData,
                                                            int numWeights,
                                                            void (*callback)(bool));

    void update_bone_matrices_render_thread(TSceneManager *sceneManager,
        EntityId asset, void(*callback)(bool));
    void set_bone_transform_render_thread(
        TSceneManager *sceneManager,
        EntityId asset,
        int skinIndex, 
        int boneIndex,
        const float *const transform,
        void (*callback)(bool));
    void set_post_processing_render_thread(TViewer *viewer, bool enabled);
    void reset_to_rest_pose_render_thread(TSceneManager *sceneManager, EntityId entityId, void(*callback)());
    void create_geometry_render_thread(
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
        TMaterialInstance *materialInstance, 
        bool keepData, 
        void (*callback)(EntityId));
    void unproject_texture_render_thread(TViewer* viewer, EntityId entity, uint8_t* input, uint32_t inputWidth, uint32_t inputHeight, uint8_t* out, uint32_t outWidth, uint32_t outHeight, void(*callback)());


#ifdef __cplusplus
}
}
#endif

#endif // _DART_FILAMENT_FFI_API_H
