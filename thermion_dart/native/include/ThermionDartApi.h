#ifndef _FLUTTER_FILAMENT_API_H
#define _FLUTTER_FILAMENT_API_H

#ifdef _WIN32
#ifdef IS_DLL
#define EMSCRIPTEN_KEEPALIVE __declspec(dllimport)
#else
#define EMSCRIPTEN_KEEPALIVE __declspec(dllexport)
#endif
#else
#ifndef EMSCRIPTEN_KEEPALIVE
#define EMSCRIPTEN_KEEPALIVE __attribute__((visibility("default")))
#endif
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

#include "APIBoundaryTypes.h"
#include "ResourceBuffer.hpp"
#include "ThermionDartAPIUtils.h"

#ifdef __cplusplus
extern "C"
{
#endif



	EMSCRIPTEN_KEEPALIVE TViewer *Viewer_create(const void *const context, const void *const loader, void *const platform, const char *uberArchivePath);
	EMSCRIPTEN_KEEPALIVE void destroy_filament_viewer(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE TSceneManager *Viewer_getSceneManager(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE TRenderTarget* Viewer_createRenderTarget(TViewer *viewer, intptr_t texture, uint32_t width, uint32_t height);
	EMSCRIPTEN_KEEPALIVE void Viewer_destroyRenderTarget(TViewer *viewer, TRenderTarget* tRenderTarget);
	EMSCRIPTEN_KEEPALIVE TSwapChain *Viewer_createSwapChain(TViewer *viewer, const void *const window);
	EMSCRIPTEN_KEEPALIVE TSwapChain *Viewer_createHeadlessSwapChain(TViewer *viewer, uint32_t width, uint32_t height);
	EMSCRIPTEN_KEEPALIVE void Viewer_destroySwapChain(TViewer *viewer, TSwapChain* swapChain);
	EMSCRIPTEN_KEEPALIVE void Viewer_render(
		TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE void Viewer_capture(
		TViewer *viewer,
		TView *view,
		TSwapChain *swapChain,
		uint8_t *pixelBuffer,
		void (*callback)(void));
	EMSCRIPTEN_KEEPALIVE void Viewer_captureRenderTarget(
		TViewer *viewer,
		TView *view,
		TSwapChain *swapChain,
		TRenderTarget *renderTarget,
		uint8_t *pixelBuffer,
		void (*callback)(void));
	EMSCRIPTEN_KEEPALIVE TView* Viewer_createView(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE TView* Viewer_getViewAt(TViewer *viewer, int index);
	EMSCRIPTEN_KEEPALIVE void Viewer_setMainCamera(TViewer *tViewer, TView *tView);	
	EMSCRIPTEN_KEEPALIVE TSwapChain* Viewer_getSwapChainAt(TViewer *tViewer, int index);
	EMSCRIPTEN_KEEPALIVE void Viewer_setViewRenderable(TViewer *viewer, TSwapChain *swapChain, TView* view, bool renderable);	
	EMSCRIPTEN_KEEPALIVE void Viewer_pick(TViewer *viewer, TView* tView, int x, int y, void (*callback)(EntityId entityId, int x, int y, TView *tView));
	
	// Engine
	EMSCRIPTEN_KEEPALIVE TEngine *Viewer_getEngine(TViewer* viewer);
	EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine* tEngine, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void Engine_setTransform(TEngine* tEngine, EntityId entity, double4x4 transform);
	
	EMSCRIPTEN_KEEPALIVE void clear_background_image(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE void set_background_image(TViewer *viewer, const char *path, bool fillHeight);
	EMSCRIPTEN_KEEPALIVE void set_background_image_position(TViewer *viewer, float x, float y, bool clamp);
	EMSCRIPTEN_KEEPALIVE void set_background_color(TViewer *viewer, const float r, const float g, const float b, const float a);
	
	
	EMSCRIPTEN_KEEPALIVE void load_skybox(TViewer *viewer, const char *skyboxPath);
	EMSCRIPTEN_KEEPALIVE void Viewer_loadIbl(TViewer *viewer, const char *iblPath, float intensity);
	EMSCRIPTEN_KEEPALIVE void create_ibl(TViewer *viewer, float r, float g, float b, float intensity);
	EMSCRIPTEN_KEEPALIVE void rotate_ibl(TViewer *viewer, float *rotationMatrix);
	EMSCRIPTEN_KEEPALIVE void remove_skybox(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE void remove_ibl(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE EntityId add_light(
		TViewer *viewer,
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
		bool shadows);
	EMSCRIPTEN_KEEPALIVE void remove_light(TViewer *viewer, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void clear_lights(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE void set_light_position(TViewer *viewer, EntityId light, float x, float y, float z);
	EMSCRIPTEN_KEEPALIVE void set_light_direction(TViewer *viewer, EntityId light, float x, float y, float z);
	EMSCRIPTEN_KEEPALIVE EntityId load_glb(TSceneManager *sceneManager, const char *assetPath, int numInstances, bool keepData);
	EMSCRIPTEN_KEEPALIVE EntityId load_gltf(TSceneManager *sceneManager, const char *assetPath, const char *relativePath, bool keepData);
	EMSCRIPTEN_KEEPALIVE EntityId create_instance(TSceneManager *sceneManager, EntityId id);
	EMSCRIPTEN_KEEPALIVE int get_instance_count(TSceneManager *sceneManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void get_instances(TSceneManager *sceneManager, EntityId entityId, EntityId *out);
	
	EMSCRIPTEN_KEEPALIVE EntityId get_main_camera(TViewer *viewer);
	
	EMSCRIPTEN_KEEPALIVE void set_frame_interval(TViewer *viewer, float interval);
	
	EMSCRIPTEN_KEEPALIVE void apply_weights(
		TSceneManager *sceneManager,
		EntityId entity,
		const char *const entityName,
		float *const weights,
		int count);
	EMSCRIPTEN_KEEPALIVE bool set_morph_target_weights(
		TSceneManager *sceneManager,
		EntityId entity,
		const float *const morphData,
		int numWeights);
	
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *create_material_instance(TSceneManager *sceneManager, TMaterialKey materialConfig);

	EMSCRIPTEN_KEEPALIVE void destroy_material_instance(TSceneManager *sceneManager, TMaterialInstance *instance);

	EMSCRIPTEN_KEEPALIVE void clear_morph_animation(
		TSceneManager *sceneManager,
		EntityId entity);

	EMSCRIPTEN_KEEPALIVE void reset_to_rest_pose(
		TSceneManager *sceneManager,
		EntityId asset);
	EMSCRIPTEN_KEEPALIVE void add_bone_animation(
		TSceneManager *sceneManager,
		EntityId entity,
		int skinIndex,
		int boneIndex,
		const float *const frameData,
		int numFrames,
		float frameLengthInMs,
		float fadeOutInSecs,
		float fadeInInSecs,
		float maxDelta);
	EMSCRIPTEN_KEEPALIVE void get_local_transform(TSceneManager *sceneManager,
												  EntityId entityId, float *const);
	EMSCRIPTEN_KEEPALIVE void get_rest_local_transforms(TSceneManager *sceneManager,
														EntityId entityId, int skinIndex, float *const out, int numBones);
	EMSCRIPTEN_KEEPALIVE void get_world_transform(TSceneManager *sceneManager,
												  EntityId entityId, float *const);
	EMSCRIPTEN_KEEPALIVE void get_inverse_bind_matrix(TSceneManager *sceneManager,
													  EntityId entityId, int skinIndex, int boneIndex, float *const);
	EMSCRIPTEN_KEEPALIVE bool set_bone_transform(
		TSceneManager *sceneManager,
		EntityId entity,
		int skinIndex,
		int boneIndex,
		const float *const transform);
	EMSCRIPTEN_KEEPALIVE void play_animation(TSceneManager *sceneManager, EntityId entity, int index, bool loop, bool reverse, bool replaceActive, float crossfade, float startOffset);
	EMSCRIPTEN_KEEPALIVE void set_animation_frame(TSceneManager *sceneManager, EntityId entity, int animationIndex, int animationFrame);
	EMSCRIPTEN_KEEPALIVE void stop_animation(TSceneManager *sceneManager, EntityId entity, int index);
	EMSCRIPTEN_KEEPALIVE int get_animation_count(TSceneManager *sceneManager, EntityId asset);
	EMSCRIPTEN_KEEPALIVE void get_animation_name(TSceneManager *sceneManager, EntityId entity, char *const outPtr, int index);
	EMSCRIPTEN_KEEPALIVE float get_animation_duration(TSceneManager *sceneManager, EntityId entity, int index);
	EMSCRIPTEN_KEEPALIVE int get_bone_count(TSceneManager *sceneManager, EntityId assetEntity, int skinIndex);
	EMSCRIPTEN_KEEPALIVE void get_bone_names(TSceneManager *sceneManager, EntityId assetEntity, const char **outPtr, int skinIndex);
	EMSCRIPTEN_KEEPALIVE EntityId get_bone(TSceneManager *sceneManager,
										   EntityId entityId,
										   int skinIndex,
										   int boneIndex);
	
	EMSCRIPTEN_KEEPALIVE EntityId SceneManager_createGeometry(
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
		bool keepData);
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *SceneManager_createUnlitMaterialInstance(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE bool SceneManager_setTransform(TSceneManager *sceneManager, EntityId entityId, const double *const transform);
	EMSCRIPTEN_KEEPALIVE void SceneManager_queueTransformUpdates(TSceneManager *sceneManager, EntityId* entities, const double* const transforms, int numEntities);
	EMSCRIPTEN_KEEPALIVE TCamera* SceneManager_findCameraByName(TSceneManager* tSceneManager, EntityId entity, const char* name);
	EMSCRIPTEN_KEEPALIVE void SceneManager_setVisibilityLayer(TSceneManager *tSceneManager, EntityId entity, int layer);
	EMSCRIPTEN_KEEPALIVE TScene* SceneManager_getScene(TSceneManager *tSceneManager);
	EMSCRIPTEN_KEEPALIVE EntityId SceneManager_loadGlbFromBuffer(TSceneManager *sceneManager, const uint8_t *const, size_t length, bool keepData, int priority, int layer, bool loadResourcesAsync);
	EMSCRIPTEN_KEEPALIVE bool SceneManager_setMorphAnimation(
		TSceneManager *sceneManager,
		EntityId entity,
		const float *const morphData,
		const uint32_t *const morphIndices,
		int numMorphTargets,
		int numFrames,
		float frameLengthInMs);
	

	EMSCRIPTEN_KEEPALIVE bool update_bone_matrices(TSceneManager *sceneManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void get_morph_target_name(TSceneManager *sceneManager, EntityId assetEntity, EntityId childEntity, char *const outPtr, int index);
	EMSCRIPTEN_KEEPALIVE int get_morph_target_name_count(TSceneManager *sceneManager, EntityId assetEntity, EntityId childEntity);
	EMSCRIPTEN_KEEPALIVE void remove_entity(TViewer *viewer, EntityId asset);
	EMSCRIPTEN_KEEPALIVE void clear_entities(TViewer *viewer);
	EMSCRIPTEN_KEEPALIVE bool set_material_color(TSceneManager *sceneManager, EntityId entity, const char *meshName, int materialIndex, const float r, const float g, const float b, const float a);
	EMSCRIPTEN_KEEPALIVE void transform_to_unit_cube(TSceneManager *sceneManager, EntityId asset);
	
	EMSCRIPTEN_KEEPALIVE void queue_relative_position_update_world_axis(TSceneManager *sceneManager, EntityId entity, float viewportX, float viewportY, float x, float y, float z);
	EMSCRIPTEN_KEEPALIVE void queue_position_update_from_viewport_coords(TSceneManager *sceneManager, TView *view, EntityId entity, float viewportX, float viewportY);

	EMSCRIPTEN_KEEPALIVE void set_position(TSceneManager *sceneManager, EntityId entity, float x, float y, float z);
	EMSCRIPTEN_KEEPALIVE void set_rotation(TSceneManager *sceneManager, EntityId entity, float rads, float x, float y, float z, float w);
	EMSCRIPTEN_KEEPALIVE void set_scale(TSceneManager *sceneManager, EntityId entity, float scale);

	EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine *engine, EntityId entity);
	EMSCRIPTEN_KEEPALIVE TEntityManager *Engine_getEntityManager(TEngine *engine);

	// SceneManager
	EMSCRIPTEN_KEEPALIVE TCamera* SceneManager_createCamera(TSceneManager *sceneManager);
	EMSCRIPTEN_KEEPALIVE void SceneManager_destroyCamera(TSceneManager *sceneManager, TCamera* camera);
	EMSCRIPTEN_KEEPALIVE size_t SceneManager_getCameraCount(TSceneManager *sceneManager);	
	EMSCRIPTEN_KEEPALIVE TCamera* SceneManager_getCameraAt(TSceneManager *sceneManager, size_t index);	

	EMSCRIPTEN_KEEPALIVE int hide_mesh(TSceneManager *sceneManager, EntityId entity, const char *meshName);
	EMSCRIPTEN_KEEPALIVE int reveal_mesh(TSceneManager *sceneManager, EntityId entity, const char *meshName);
	

	EMSCRIPTEN_KEEPALIVE const char *get_name_for_entity(TSceneManager *sceneManager, const EntityId entityId);
	EMSCRIPTEN_KEEPALIVE EntityId find_child_entity_by_name(TSceneManager *sceneManager, const EntityId parent, const char *name);
	EMSCRIPTEN_KEEPALIVE int get_entity_count(TSceneManager *sceneManager, const EntityId target, bool renderableOnly);
	EMSCRIPTEN_KEEPALIVE void get_entities(TSceneManager *sceneManager, const EntityId target, bool renderableOnly, EntityId *out);
	EMSCRIPTEN_KEEPALIVE const char *get_entity_name_at(TSceneManager *sceneManager, const EntityId target, int index, bool renderableOnly);
	
	EMSCRIPTEN_KEEPALIVE void ios_dummy();
	EMSCRIPTEN_KEEPALIVE void thermion_flutter_free(void *ptr);
	EMSCRIPTEN_KEEPALIVE void add_collision_component(TSceneManager *sceneManager, EntityId entityId, void (*callback)(const EntityId entityId1, const EntityId entityId2), bool affectsCollidingTransform);
	EMSCRIPTEN_KEEPALIVE void remove_collision_component(TSceneManager *sceneManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE bool add_animation_component(TSceneManager *sceneManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void remove_animation_component(TSceneManager *sceneManager, EntityId entityId);

	EMSCRIPTEN_KEEPALIVE EntityId get_parent(TSceneManager *sceneManager, EntityId child);
	EMSCRIPTEN_KEEPALIVE EntityId get_ancestor(TSceneManager *sceneManager, EntityId child);
	EMSCRIPTEN_KEEPALIVE void set_parent(TSceneManager *sceneManager, EntityId child, EntityId parent, bool preserveScaling);
	EMSCRIPTEN_KEEPALIVE void test_collisions(TSceneManager *sceneManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void set_priority(TSceneManager *sceneManager, EntityId entityId, int priority);
	
	EMSCRIPTEN_KEEPALIVE Aabb2 get_bounding_box(TSceneManager *sceneManager, TView *view, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void get_bounding_box_to_out(TSceneManager *sceneManager, TView *view, EntityId entity, float *minX, float *minY, float *maxX, float *maxY);
	
	
	EMSCRIPTEN_KEEPALIVE void set_stencil_highlight(TSceneManager *sceneManager, EntityId entity, float r, float g, float b);
	EMSCRIPTEN_KEEPALIVE void remove_stencil_highlight(TSceneManager *sceneManager, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void set_material_property_float(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, float value);
	EMSCRIPTEN_KEEPALIVE void set_material_property_int(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, int value);
	EMSCRIPTEN_KEEPALIVE void set_material_property_float4(TSceneManager *sceneManager, EntityId entity, int materialIndex, const char *property, double4 value);
	EMSCRIPTEN_KEEPALIVE void set_material_depth_write(TSceneManager *sceneManager, EntityId entity, int materialIndex, bool enabled);
	EMSCRIPTEN_KEEPALIVE void unproject_texture(TViewer* viewer, EntityId entity,uint8_t* input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight);
	EMSCRIPTEN_KEEPALIVE void *const create_texture(TSceneManager *sceneManager, uint8_t *data, size_t length);
	EMSCRIPTEN_KEEPALIVE void destroy_texture(TSceneManager *sceneManager, void *const texture);
	EMSCRIPTEN_KEEPALIVE void apply_texture_to_material(TSceneManager *sceneManager, EntityId entity, void *const texture, const char *parameterName, int materialIndex);

	EMSCRIPTEN_KEEPALIVE TMaterialInstance* get_material_instance_at(TSceneManager *sceneManager, EntityId entity, int materialIndex);
	
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthWrite(TMaterialInstance* materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setDepthCulling(TMaterialInstance* materialInstance, bool enabled);
	EMSCRIPTEN_KEEPALIVE void MaterialInstance_setParameterFloat2(TMaterialInstance* materialInstance, const char* name, double x, double y);


#ifdef __cplusplus
}
#endif
#endif
