#ifndef _FLUTTER_FILAMENT_API_H
#define _FLUTTER_FILAMENT_API_H

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"

#include "ResourceBuffer.hpp"
#include "MathUtils.hpp"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TViewer *Viewer_create(const void *const context, const void *const loader, void *const platform, const char *uberArchivePath);
	EMSCRIPTEN_KEEPALIVE void Viewer_destroy(TViewer *viewer);
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

	
	// Engine
	EMSCRIPTEN_KEEPALIVE TEngine *Viewer_getEngine(TViewer* viewer);
	EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine* tEngine, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE TTransformManager *Engine_getTransformManager(TEngine *engine);
	EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *engine);
	EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine *engine, EntityId entity);
	EMSCRIPTEN_KEEPALIVE TEntityManager *Engine_getEntityManager(TEngine *engine);
	
	EMSCRIPTEN_KEEPALIVE TMaterial *Engine_buildMaterial(TEngine *tEngine, const uint8_t* materialData, size_t length);
	EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterial(TEngine *tEngine, TMaterial *tMaterial);
	
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
	
	EMSCRIPTEN_KEEPALIVE EntityId get_main_camera(TViewer *viewer);
	
	EMSCRIPTEN_KEEPALIVE void set_frame_interval(TViewer *viewer, float interval);
	
	EMSCRIPTEN_KEEPALIVE void queue_relative_position_update_world_axis(TSceneManager *sceneManager, EntityId entity, float viewportX, float viewportY, float x, float y, float z);
	EMSCRIPTEN_KEEPALIVE void queue_position_update_from_viewport_coords(TSceneManager *sceneManager, TView *view, EntityId entity, float viewportX, float viewportY);
	
	EMSCRIPTEN_KEEPALIVE void ios_dummy();
	EMSCRIPTEN_KEEPALIVE void thermion_flutter_free(void *ptr);
	EMSCRIPTEN_KEEPALIVE void add_collision_component(TSceneManager *sceneManager, EntityId entityId, void (*callback)(const EntityId entityId1, const EntityId entityId2), bool affectsCollidingTransform);
	EMSCRIPTEN_KEEPALIVE void remove_collision_component(TSceneManager *sceneManager, EntityId entityId);

	EMSCRIPTEN_KEEPALIVE void test_collisions(TSceneManager *sceneManager, EntityId entity);
	
	EMSCRIPTEN_KEEPALIVE Aabb2 get_bounding_box(TSceneManager *sceneManager, TView *view, EntityId entity);
	EMSCRIPTEN_KEEPALIVE void get_bounding_box_to_out(TSceneManager *sceneManager, TView *view, EntityId entity, float *minX, float *minY, float *maxX, float *maxY);	
	
	EMSCRIPTEN_KEEPALIVE void unproject_texture(TViewer* viewer, EntityId entity,uint8_t* input, uint32_t inputWidth, uint32_t inputHeight, uint8_t *out, uint32_t outWidth, uint32_t outHeight);
	EMSCRIPTEN_KEEPALIVE void *const create_texture(TSceneManager *sceneManager, uint8_t *data, size_t length);
	EMSCRIPTEN_KEEPALIVE void destroy_texture(TSceneManager *sceneManager, void *const texture);
	EMSCRIPTEN_KEEPALIVE void apply_texture_to_material(TSceneManager *sceneManager, EntityId entity, void *const texture, const char *parameterName, int materialIndex);

	
#ifdef __cplusplus
}
#endif
#endif
