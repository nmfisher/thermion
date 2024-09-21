#ifndef _DART_FILAMENT_FFI_API_H
#define _DART_FILAMENT_FFI_API_H

#include "ThermionDartApi.h"

#ifdef __cplusplus
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

    EMSCRIPTEN_KEEPALIVE void create_filament_viewer_render_thread(
        void *const context,
        void *const platform,
        const char *uberArchivePath,
        const void *const loader,
        void (*renderCallback)(void *const renderCallbackOwner),
        void *const renderCallbackOwner,
        void (*callback)(void *const viewer));
    EMSCRIPTEN_KEEPALIVE void create_swap_chain_render_thread(void *const viewer, void *const surface, uint32_t width, uint32_t height, void (*onComplete)());
    EMSCRIPTEN_KEEPALIVE void destroy_swap_chain_render_thread(void *const viewer, void (*onComplete)());
    EMSCRIPTEN_KEEPALIVE void create_render_target_render_thread(void *const viewer, intptr_t nativeTextureId, uint32_t width, uint32_t height, void (*onComplete)());
    EMSCRIPTEN_KEEPALIVE void destroy_filament_viewer_render_thread(void *const viewer);
    EMSCRIPTEN_KEEPALIVE void render_render_thread(void *const viewer);
    EMSCRIPTEN_KEEPALIVE void capture_render_thread(void *const viewer, uint8_t* out, void (*onComplete)());
    EMSCRIPTEN_KEEPALIVE FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback);
    EMSCRIPTEN_KEEPALIVE void set_rendering_render_thread(void *const viewer, bool rendering, void(*onComplete)());
    EMSCRIPTEN_KEEPALIVE void request_frame_render_thread(void *const viewer);
    EMSCRIPTEN_KEEPALIVE void set_frame_interval_render_thread(void *const viewer, float frameInterval);
    EMSCRIPTEN_KEEPALIVE void set_background_color_render_thread(void *const viewer, const float r, const float g, const float b, const float a);
    EMSCRIPTEN_KEEPALIVE void clear_background_image_render_thread(void *const viewer);
    EMSCRIPTEN_KEEPALIVE void set_background_image_render_thread(void *const viewer, const char *path, bool fillHeight, void (*onComplete)());
    EMSCRIPTEN_KEEPALIVE void set_background_image_position_render_thread(void *const viewer, float x, float y, bool clamp);
    EMSCRIPTEN_KEEPALIVE void set_tone_mapping_render_thread(void *const viewer, int toneMapping);
    EMSCRIPTEN_KEEPALIVE void set_bloom_render_thread(void *const viewer, float strength);
    EMSCRIPTEN_KEEPALIVE void load_skybox_render_thread(void *const viewer, const char *skyboxPath, void (*onComplete)());
    EMSCRIPTEN_KEEPALIVE void load_ibl_render_thread(void *const viewer, const char *iblPath, float intensity);
    EMSCRIPTEN_KEEPALIVE void remove_skybox_render_thread(void *const viewer);
    EMSCRIPTEN_KEEPALIVE void remove_ibl_render_thread(void *const viewer);
    EMSCRIPTEN_KEEPALIVE void add_light_render_thread(
        void *const viewer,
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
    EMSCRIPTEN_KEEPALIVE void remove_light_render_thread(void *const viewer, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE void clear_lights_render_thread(void *const viewer);
    EMSCRIPTEN_KEEPALIVE void load_glb_render_thread(void *const sceneManager, const char *assetPath, int numInstances, bool keepData, void (*callback)(EntityId));
    EMSCRIPTEN_KEEPALIVE void load_glb_from_buffer_render_thread(void *const sceneManager, const uint8_t *const data, size_t length, int numInstances, bool keepData, int priority, int layer, void (*callback)(EntityId));
    EMSCRIPTEN_KEEPALIVE void load_gltf_render_thread(void *const sceneManager, const char *assetPath, const char *relativePath, bool keepData, void (*callback)(EntityId));
    EMSCRIPTEN_KEEPALIVE void create_instance_render_thread(void *const sceneManager, EntityId entityId, void (*callback)(EntityId));
    EMSCRIPTEN_KEEPALIVE void remove_entity_render_thread(void *const viewer, EntityId asset, void (*callback)());
    EMSCRIPTEN_KEEPALIVE void clear_entities_render_thread(void *const viewer, void (*callback)());
    EMSCRIPTEN_KEEPALIVE void set_camera_render_thread(void *const viewer, EntityId asset, const char *nodeName, void (*callback)(bool));
    EMSCRIPTEN_KEEPALIVE void apply_weights_render_thread(
        void *const sceneManager,
        EntityId asset,
        const char *const entityName,
        float *const weights,
        int count);
    EMSCRIPTEN_KEEPALIVE void set_animation_frame_render_thread(void *const sceneManager, EntityId asset, int animationIndex, int animationFrame);
    EMSCRIPTEN_KEEPALIVE void stop_animation_render_thread(void *const sceneManager, EntityId asset, int index);
    EMSCRIPTEN_KEEPALIVE void get_animation_count_render_thread(void *const sceneManager, EntityId asset, void (*callback)(int));
    EMSCRIPTEN_KEEPALIVE void get_animation_name_render_thread(void *const sceneManager, EntityId asset, char *const outPtr, int index, void (*callback)());
    EMSCRIPTEN_KEEPALIVE void get_morph_target_name_render_thread(void *const sceneManager, EntityId assetEntity, EntityId childEntity, char *const outPtr, int index, void (*callback)());
    EMSCRIPTEN_KEEPALIVE void get_morph_target_name_count_render_thread(void *const sceneManager, EntityId asset, EntityId childEntity, void (*callback)(int32_t));
    EMSCRIPTEN_KEEPALIVE void set_morph_target_weights_render_thread(void *const sceneManager,
                                                            EntityId asset,
                                                            const float *const morphData,
                                                            int numWeights,
                                                            void (*callback)(bool));

    EMSCRIPTEN_KEEPALIVE void update_bone_matrices_render_thread(void *sceneManager,
        EntityId asset, void(*callback)(bool));
    EMSCRIPTEN_KEEPALIVE void set_bone_transform_render_thread(
        void *sceneManager,
        EntityId asset,
        int skinIndex, 
        int boneIndex,
        const float *const transform,
        void (*callback)(bool));
    EMSCRIPTEN_KEEPALIVE void set_post_processing_render_thread(void *const viewer, bool enabled);
    EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose_render_thread(void *const sceneManager, EntityId entityId, void(*callback)());
    EMSCRIPTEN_KEEPALIVE void create_geometry_render_thread(
        void *const sceneManager, 
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
    EMSCRIPTEN_KEEPALIVE void unproject_texture_render_thread(void *const sceneManager, EntityId entity, uint8_t* input, uint32_t inputWidth, uint32_t inputHeight, uint8_t* out, uint32_t outWidth, uint32_t outHeight, void(*callback)());


#ifdef __cplusplus
}
#endif

#endif // _DART_FILAMENT_FFI_API_H
