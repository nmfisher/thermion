#ifndef _FLUTTER_FILAMENT_FFI_API_H
#define _FLUTTER_FILAMENT_FFI_API_H

#include "FlutterFilamentApi.h"

#ifdef __cplusplus
extern "C"
{
#endif

    ///
    /// This header replicates most of the methods in FlutterFilamentApi.h, and is only intended to be used to generate client FFI bindings.
    /// The intention is that calling one of these methods will call its respective method in FlutterFilamentApi.h, but wrapped in some kind of thread runner to ensure thread safety.
    ///

    typedef int32_t EntityId;
    typedef void (*FilamentRenderCallback)(void *const owner);

    FLUTTER_PLUGIN_EXPORT void create_filament_viewer_ffi(
        void *const context, 
        void *const platform, 
        const char *uberArchivePath, 
        const ResourceLoaderWrapper *const loader, 
        void (*renderCallback)(void *const renderCallbackOwner), 
        void *const renderCallbackOwner,
        void (*callback)(void* const viewer)
        );
    FLUTTER_PLUGIN_EXPORT void create_swap_chain_ffi(void *const viewer, void *const surface, uint32_t width, uint32_t height, void (*onComplete)());
    FLUTTER_PLUGIN_EXPORT void destroy_swap_chain_ffi(void *const viewer, void (*onComplete)());
    FLUTTER_PLUGIN_EXPORT void create_render_target_ffi(void *const viewer, intptr_t nativeTextureId, uint32_t width, uint32_t height, void (*onComplete)());
    FLUTTER_PLUGIN_EXPORT void destroy_filament_viewer_ffi(void *const viewer);
    FLUTTER_PLUGIN_EXPORT void render_ffi(void *const viewer);
    FLUTTER_PLUGIN_EXPORT FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback);
    FLUTTER_PLUGIN_EXPORT void set_rendering_ffi(void *const viewer, bool rendering);
    FLUTTER_PLUGIN_EXPORT void set_frame_interval_ffi(float frameInterval);
    FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection_ffi(void *const viewer, const uint32_t width, const uint32_t height, const float scaleFactor, void (*onComplete)());
    FLUTTER_PLUGIN_EXPORT void set_background_color_ffi(void *const viewer, const float r, const float g, const float b, const float a);
    FLUTTER_PLUGIN_EXPORT void clear_background_image_ffi(void *const viewer);
    FLUTTER_PLUGIN_EXPORT void set_background_image_ffi(void *const viewer, const char *path, bool fillHeight, void (*onComplete)());
    FLUTTER_PLUGIN_EXPORT void set_background_image_position_ffi(void *const viewer, float x, float y, bool clamp);
    FLUTTER_PLUGIN_EXPORT void set_tone_mapping_ffi(void *const viewer, int toneMapping);
    FLUTTER_PLUGIN_EXPORT void set_bloom_ffi(void *const viewer, float strength);
    FLUTTER_PLUGIN_EXPORT void load_skybox_ffi(void *const viewer, const char *skyboxPath);
    FLUTTER_PLUGIN_EXPORT void load_ibl_ffi(void *const viewer, const char *iblPath, float intensity);
    FLUTTER_PLUGIN_EXPORT void remove_skybox_ffi(void *const viewer);
    FLUTTER_PLUGIN_EXPORT void remove_ibl_ffi(void *const viewer);
    FLUTTER_PLUGIN_EXPORT void add_light_ffi(
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
        bool shadows,
        void (*callback)(EntityId));
    FLUTTER_PLUGIN_EXPORT void remove_light_ffi(void *const viewer, EntityId entityId);
    FLUTTER_PLUGIN_EXPORT void clear_lights_ffi(void *const viewer);
    FLUTTER_PLUGIN_EXPORT void load_glb_ffi(void *const sceneManager, const char *assetPath, int numInstances, void (*callback)(EntityId));
    FLUTTER_PLUGIN_EXPORT void load_glb_from_buffer_ffi(void *const sceneManager, const void *const data, size_t length, int numInstances, void (*callback)(EntityId));
    FLUTTER_PLUGIN_EXPORT void load_gltf_ffi(void *const sceneManager, const char *assetPath, const char *relativePath, void (*callback)(EntityId));
    FLUTTER_PLUGIN_EXPORT void create_instance_ffi(void *const sceneManager, EntityId entityId, void (*callback)(EntityId));
    FLUTTER_PLUGIN_EXPORT void remove_entity_ffi(void *const viewer, EntityId asset, void (*callback)());
    FLUTTER_PLUGIN_EXPORT void clear_entities_ffi(void *const viewer, void (*callback)());
    FLUTTER_PLUGIN_EXPORT void set_camera_ffi(void *const viewer, EntityId asset, const char *nodeName, void (*callback)(bool));
    FLUTTER_PLUGIN_EXPORT void apply_weights_ffi(
        void *const sceneManager,
        EntityId asset,
        const char *const entityName,
        float *const weights,
        int count);

    FLUTTER_PLUGIN_EXPORT void play_animation_ffi(void *const sceneManager, EntityId asset, int index, bool loop, bool reverse, bool replaceActive, float crossfade);
    FLUTTER_PLUGIN_EXPORT void set_animation_frame_ffi(void *const sceneManager, EntityId asset, int animationIndex, int animationFrame);
    FLUTTER_PLUGIN_EXPORT void stop_animation_ffi(void *const sceneManager, EntityId asset, int index);
    FLUTTER_PLUGIN_EXPORT void get_animation_count_ffi(void *const sceneManager, EntityId asset, void (*callback)(int));
    FLUTTER_PLUGIN_EXPORT void get_animation_name_ffi(void *const sceneManager, EntityId asset, char *const outPtr, int index, void (*callback)());
    FLUTTER_PLUGIN_EXPORT void get_morph_target_name_ffi(void *const sceneManager, EntityId asset, const char *meshName, char *const outPtr, int index, void (*callback)());
    FLUTTER_PLUGIN_EXPORT void get_morph_target_name_count_ffi(void *const sceneManager, EntityId asset, const char *meshName, void (*callback)(int32_t));
    FLUTTER_PLUGIN_EXPORT void set_morph_target_weights_ffi(void *const sceneManager,
                                                            EntityId asset,
                                                            const char *const entityName,
                                                            const float *const morphData,
                                                            int numWeights);
    FLUTTER_PLUGIN_EXPORT void set_morph_animation_ffi(
        void *sceneManager,
        EntityId asset,
        const char *const entityName,
        const float *const morphData,
        const int *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs,
        void (*callback)(bool));
    FLUTTER_PLUGIN_EXPORT void set_bone_transform_ffi(
        void *sceneManager,
        EntityId asset,
        const char *entityName,
        const float *const transform,
        const char *boneName,
        void (*callback)(bool));
    FLUTTER_PLUGIN_EXPORT void add_bone_animation_ffi(
        void *sceneManager,
        EntityId asset,
        const float *const frameData,
        int numFrames,
        const char *const boneName,
        const char **const meshNames,
        int numMeshTargets,
        float frameLengthInMs,
        bool isModelSpace);
    FLUTTER_PLUGIN_EXPORT void set_post_processing_ffi(void *const viewer, bool enabled);
    FLUTTER_PLUGIN_EXPORT void reset_to_rest_pose_ffi(void *const sceneManager, EntityId entityId);
    FLUTTER_PLUGIN_EXPORT void ios_dummy_ffi();
    FLUTTER_PLUGIN_EXPORT void create_geometry_ffi(void *const viewer, float *vertices, int numVertices, uint16_t *indices, int numIndices, int primitiveType, const char *materialPath, void (*callback)(EntityId));

#ifdef __cplusplus
}
#endif

#endif // _FLUTTER_FILAMENT_FFI_API_H
