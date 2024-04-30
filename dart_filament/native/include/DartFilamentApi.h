#ifndef _FLUTTER_FILAMENT_API_H
#define _FLUTTER_FILAMENT_API_H

#ifdef _WIN32
#ifdef IS_DLL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#endif
#else
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

// we copy the LLVM <stdbool.h> here rather than including,
// because on Windows it's difficult to pin the exact location which confuses dart ffigen

#ifndef __STDBOOL_H
#define __STDBOOL_H

#define __bool_true_false_are_defined 1

#if defined(__STDC_VERSION__) && __STDC_VERSION__ > 201710L
/* FIXME: We should be issuing a deprecation warning here, but cannot yet due
 * to system headers which include this header file unconditionally.
 */
#elif !defined(__cplusplus)
#define bool _Bool
#define true 1
#define false 0
#elif defined(__GNUC__) && !defined(__STRICT_ANSI__)
/* Define _Bool as a GNU extension. */
#define _Bool bool
#if defined(__cplusplus) && __cplusplus < 201103L
/* For C++98, define bool, false, true as a GNU extension. */
#define bool bool
#define false false
#define true true
#endif
#endif

#endif /* __STDBOOL_H */

#if defined(__APPLE__) || defined(__EMSCRIPTEN__)
#include <stddef.h>
#endif

#include "ResourceBuffer.hpp"

typedef int32_t EntityId;
typedef int32_t _ManipulatorMode;

#ifdef __cplusplus
extern "C"
{
#endif

	FLUTTER_PLUGIN_EXPORT const void *create_filament_viewer(const void *const context, const ResourceLoaderWrapper *const loader, void *const platform, const char *uberArchivePath);
	FLUTTER_PLUGIN_EXPORT void destroy_filament_viewer(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void *get_scene_manager(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void create_render_target(const void *const viewer, intptr_t texture, uint32_t width, uint32_t height);
	FLUTTER_PLUGIN_EXPORT void clear_background_image(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void set_background_image(const void *const viewer, const char *path, bool fillHeight);
	FLUTTER_PLUGIN_EXPORT void set_background_image_position(const void *const viewer, float x, float y, bool clamp);
	FLUTTER_PLUGIN_EXPORT void set_background_color(const void *const viewer, const float r, const float g, const float b, const float a);
	FLUTTER_PLUGIN_EXPORT void set_tone_mapping(const void *const viewer, int toneMapping);
	FLUTTER_PLUGIN_EXPORT void set_bloom(const void *const viewer, float strength);
	FLUTTER_PLUGIN_EXPORT void load_skybox(const void *const viewer, const char *skyboxPath);
	FLUTTER_PLUGIN_EXPORT void load_ibl(const void *const viewer, const char *iblPath, float intensity);
	FLUTTER_PLUGIN_EXPORT void rotate_ibl(const void *const viewer, float *rotationMatrix);
	FLUTTER_PLUGIN_EXPORT void remove_skybox(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void remove_ibl(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT EntityId add_light(const void *const viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
	FLUTTER_PLUGIN_EXPORT void remove_light(const void *const viewer, EntityId entityId);
	FLUTTER_PLUGIN_EXPORT void clear_lights(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT EntityId load_glb(void *sceneManager, const char *assetPath, int numInstances);
	FLUTTER_PLUGIN_EXPORT EntityId load_glb_from_buffer(void *sceneManager, const void *const data, size_t length);
	FLUTTER_PLUGIN_EXPORT EntityId load_gltf(void *sceneManager, const char *assetPath, const char *relativePath);
	FLUTTER_PLUGIN_EXPORT EntityId create_instance(void *sceneManager, EntityId id);
	FLUTTER_PLUGIN_EXPORT int get_instance_count(void *sceneManager, EntityId entityId);
	FLUTTER_PLUGIN_EXPORT void get_instances(void *sceneManager, EntityId entityId, EntityId *out);
	FLUTTER_PLUGIN_EXPORT void set_main_camera(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT EntityId get_main_camera(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT bool set_camera(const void *const viewer, EntityId asset, const char *nodeName);
	FLUTTER_PLUGIN_EXPORT void set_view_frustum_culling(const void *const viewer, bool enabled);
	FLUTTER_PLUGIN_EXPORT void render(
		const void *const viewer,
		uint64_t frameTimeInNanos,
		void *pixelBuffer,
		void (*callback)(void *buf, size_t size, void *data),
		void *data);
	FLUTTER_PLUGIN_EXPORT void create_swap_chain(const void *const viewer, const void *const window, uint32_t width, uint32_t height);
	FLUTTER_PLUGIN_EXPORT void destroy_swap_chain(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void set_frame_interval(const void *const viewer, float interval);
	FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection(const void *const viewer, uint32_t width, uint32_t height, float scaleFactor);
	FLUTTER_PLUGIN_EXPORT void scroll_begin(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void scroll_update(const void *const viewer, float x, float y, float z);
	FLUTTER_PLUGIN_EXPORT void scroll_end(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void grab_begin(const void *const viewer, float x, float y, bool pan);
	FLUTTER_PLUGIN_EXPORT void grab_update(const void *const viewer, float x, float y);
	FLUTTER_PLUGIN_EXPORT void grab_end(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void apply_weights(
		void *sceneManager,
		EntityId asset,
		const char *const entityName,
		float *const weights,
		int count);
	FLUTTER_PLUGIN_EXPORT bool set_morph_target_weights(
		void *sceneManager,
		EntityId asset,
		const float *const morphData,
		int numWeights);
	FLUTTER_PLUGIN_EXPORT bool set_morph_animation(
		void *sceneManager,
		EntityId asset,
		const float *const morphData,
		const int *const morphIndices,
		int numMorphTargets,
		int numFrames,
		float frameLengthInMs);

	FLUTTER_PLUGIN_EXPORT void reset_to_rest_pose(
		void *sceneManager,
		EntityId asset);
	FLUTTER_PLUGIN_EXPORT void add_bone_animation(
		void *sceneManager,
		EntityId asset,
		const float *const frameData,
		int numFrames,
		const char *const boneName,
		const char **const meshNames,
		int numMeshTargets,
		float frameLengthInMs,
		bool isModelSpace);
	FLUTTER_PLUGIN_EXPORT bool set_bone_transform(
		void *sceneManager,
		EntityId asset,
		const char *entityName,
		const float *const transform,
		const char *boneName);
	FLUTTER_PLUGIN_EXPORT void play_animation(void *sceneManager, EntityId asset, int index, bool loop, bool reverse, bool replaceActive, float crossfade);
	FLUTTER_PLUGIN_EXPORT void set_animation_frame(void *sceneManager, EntityId asset, int animationIndex, int animationFrame);
	FLUTTER_PLUGIN_EXPORT void stop_animation(void *sceneManager, EntityId asset, int index);
	FLUTTER_PLUGIN_EXPORT int get_animation_count(void *sceneManager, EntityId asset);
	FLUTTER_PLUGIN_EXPORT void get_animation_name(void *sceneManager, EntityId asset, char *const outPtr, int index);
	FLUTTER_PLUGIN_EXPORT float get_animation_duration(void *sceneManager, EntityId asset, int index);
	FLUTTER_PLUGIN_EXPORT void get_morph_target_name(void *sceneManager, EntityId asset, const char *meshName, char *const outPtr, int index);
	FLUTTER_PLUGIN_EXPORT int get_morph_target_name_count(void *sceneManager, EntityId asset, const char *meshName);
	FLUTTER_PLUGIN_EXPORT void remove_entity(const void *const viewer, EntityId asset);
	FLUTTER_PLUGIN_EXPORT void clear_entities(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT bool set_material_color(void *sceneManager, EntityId asset, const char *meshName, int materialIndex, const float r, const float g, const float b, const float a);
	FLUTTER_PLUGIN_EXPORT void transform_to_unit_cube(void *sceneManager, EntityId asset);
	FLUTTER_PLUGIN_EXPORT void queue_position_update(void *sceneManager, EntityId asset, float x, float y, float z, bool relative);
	FLUTTER_PLUGIN_EXPORT void queue_rotation_update(void *sceneManager, EntityId asset, float rads, float x, float y, float z, float w, bool relative);
	FLUTTER_PLUGIN_EXPORT void set_position(void *sceneManager, EntityId asset, float x, float y, float z);
	FLUTTER_PLUGIN_EXPORT void set_rotation(void *sceneManager, EntityId asset, float rads, float x, float y, float z, float w);
	FLUTTER_PLUGIN_EXPORT void set_scale(void *sceneManager, EntityId asset, float scale);

	// Camera methods
	FLUTTER_PLUGIN_EXPORT void move_camera_to_asset(const void *const viewer, EntityId asset);
	FLUTTER_PLUGIN_EXPORT void set_view_frustum_culling(const void *const viewer, bool enabled);
	FLUTTER_PLUGIN_EXPORT void set_camera_exposure(const void *const viewer, float aperture, float shutterSpeed, float sensitivity);
	FLUTTER_PLUGIN_EXPORT void set_camera_position(const void *const viewer, float x, float y, float z);
	FLUTTER_PLUGIN_EXPORT void get_camera_position(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void set_camera_rotation(const void *const viewer, float w, float x, float y, float z);
	FLUTTER_PLUGIN_EXPORT void set_camera_model_matrix(const void *const viewer, const float *const matrix);
	FLUTTER_PLUGIN_EXPORT const double *const get_camera_model_matrix(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT const double *const get_camera_view_matrix(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT const double *const get_camera_projection_matrix(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void set_camera_projection_matrix(const void *const viewer, const double *const matrix, double near, double far);
	FLUTTER_PLUGIN_EXPORT void set_camera_culling(const void *const viewer, double near, double far);
	FLUTTER_PLUGIN_EXPORT double get_camera_culling_near(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT double get_camera_culling_far(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT const double *const get_camera_culling_projection_matrix(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT const double *const get_camera_frustum(const void *const viewer);
	FLUTTER_PLUGIN_EXPORT void set_camera_fov(const void *const viewer, float fovInDegrees, float aspect);
	FLUTTER_PLUGIN_EXPORT void set_camera_focal_length(const void *const viewer, float focalLength);
	FLUTTER_PLUGIN_EXPORT void set_camera_focus_distance(const void *const viewer, float focusDistance);
	FLUTTER_PLUGIN_EXPORT void set_camera_manipulator_options(const void *const viewer, _ManipulatorMode mode, double orbitSpeedX, double orbitSpeedY, double zoomSpeed);

	FLUTTER_PLUGIN_EXPORT int hide_mesh(void *sceneManager, EntityId asset, const char *meshName);
	FLUTTER_PLUGIN_EXPORT int reveal_mesh(void *sceneManager, EntityId asset, const char *meshName);
	FLUTTER_PLUGIN_EXPORT void set_post_processing(void *const viewer, bool enabled);
	FLUTTER_PLUGIN_EXPORT void set_antialiasing(void *const viewer, bool msaa, bool fxaa, bool taa);
	FLUTTER_PLUGIN_EXPORT void pick(void *const viewer, int x, int y, void (*callback)(EntityId entityId, int x, int y));
	FLUTTER_PLUGIN_EXPORT const char *get_name_for_entity(void *const sceneManager, const EntityId entityId);
	FLUTTER_PLUGIN_EXPORT EntityId find_child_entity_by_name(void *const sceneManager, const EntityId parent, const char *name);
	FLUTTER_PLUGIN_EXPORT int get_entity_count(void *const sceneManager, const EntityId target, bool renderableOnly);
	FLUTTER_PLUGIN_EXPORT void get_entities(void *const sceneManager, const EntityId target, bool renderableOnly, EntityId *out);
	FLUTTER_PLUGIN_EXPORT const char *get_entity_name_at(void *const sceneManager, const EntityId target, int index, bool renderableOnly);
	FLUTTER_PLUGIN_EXPORT void set_recording(void *const viewer, bool recording);
	FLUTTER_PLUGIN_EXPORT void set_recording_output_directory(void *const viewer, const char *outputDirectory);
	FLUTTER_PLUGIN_EXPORT void ios_dummy();
	FLUTTER_PLUGIN_EXPORT void flutter_filament_free(void *ptr);
	FLUTTER_PLUGIN_EXPORT void add_collision_component(void *const sceneManager, EntityId entityId, void (*callback)(const EntityId entityId1, const EntityId entityId2), bool affectsCollidingTransform);
	FLUTTER_PLUGIN_EXPORT void remove_collision_component(void *const sceneManager, EntityId entityId);
	FLUTTER_PLUGIN_EXPORT bool add_animation_component(void *const sceneManager, EntityId entityId);

	FLUTTER_PLUGIN_EXPORT EntityId create_geometry(void *const viewer, float *vertices, int numVertices, uint16_t *indices, int numIndices, int primitiveType, const char *materialPath);
	FLUTTER_PLUGIN_EXPORT void set_parent(void *const sceneManager, EntityId child, EntityId parent);
	FLUTTER_PLUGIN_EXPORT void test_collisions(void *const sceneManager, EntityId entity);
	FLUTTER_PLUGIN_EXPORT void set_priority(void *const sceneManager, EntityId entityId, int priority);
	FLUTTER_PLUGIN_EXPORT void get_gizmo(void *const sceneManager, EntityId *out);

#ifdef __cplusplus
}
#endif
#endif