#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"
#include "TTexture.h"

#ifdef __cplusplus
extern "C"
{
#endif

enum TBackend {
    BACKEND_DEFAULT = 0,  //!< Automatically selects an appropriate driver for the platform.
    BACKEND_OPENGL = 1,   //!< Selects the OpenGL/ES driver (default on Android)
    BACKEND_VULKAN = 2,   //!< Selects the Vulkan driver if the platform supports it (default on Linux/Windows)
    BACKEND_METAL = 3,    //!< Selects the Metal driver if the platform supports it (default on MacOS/iOS).
    BACKEND_NOOP = 4,     //!< Selects the no-op driver for testing purposes.
};
typedef enum TBackend TBackend;

EMSCRIPTEN_KEEPALIVE TEngine *Engine_create(
    TBackend backend,
    void* platform,
    void* sharedContext,
    uint8_t stereoscopicEyeCount,
    bool disableHandleUseAfterFreeCheck
);

EMSCRIPTEN_KEEPALIVE TFeatureLevel Engine_getSupportedFeatureLevel(TEngine *tEngine);

EMSCRIPTEN_KEEPALIVE void Engine_destroy(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE TRenderer *Engine_createRenderer(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE void Engine_destroyRenderer(TEngine *tEngine, TRenderer *tRenderer);
EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createSwapChain(TEngine *tEngine, void *window, uint64_t flags);
EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createHeadlessSwapChain(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags);
EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChain(TEngine *tEngine, TSwapChain *tSwapChain);
EMSCRIPTEN_KEEPALIVE void Engine_destroyView(TEngine *tEngine, TView *tView);
EMSCRIPTEN_KEEPALIVE void Engine_destroyScene(TEngine *tEngine, TScene *tScene);
EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGrading(TEngine *tEngine, TColorGrading *tColorGrading);

EMSCRIPTEN_KEEPALIVE TCamera *Engine_createCamera(TEngine* tEngine, EntityId entityId);
EMSCRIPTEN_KEEPALIVE void Engine_destroyCamera(TEngine *tEngine, TCamera *tCamera);
EMSCRIPTEN_KEEPALIVE TView *Engine_createView(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine* tEngine, EntityId entityId);
EMSCRIPTEN_KEEPALIVE TTransformManager *Engine_getTransformManager(TEngine *engine);
EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *engine);
EMSCRIPTEN_KEEPALIVE TLightManager *Engine_getLightManager(TEngine *engine);
EMSCRIPTEN_KEEPALIVE TEntityManager *Engine_getEntityManager(TEngine *engine);
EMSCRIPTEN_KEEPALIVE void Engine_setAutomaticInstancingEnabled(TEngine *tEngine, bool enabled);
EMSCRIPTEN_KEEPALIVE size_t Engine_getMaxAutomaticInstances(TEngine *tEngine);

EMSCRIPTEN_KEEPALIVE void Engine_destroyTexture(TEngine *tEngine, TTexture *tTexture);

EMSCRIPTEN_KEEPALIVE TFence *Engine_createFence(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE void Engine_destroyFence(TEngine *tEngine, TFence *tFence);
EMSCRIPTEN_KEEPALIVE void Engine_flushAndWait(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE void Engine_execute(TEngine *tEngine);
    
EMSCRIPTEN_KEEPALIVE TMaterial *Engine_buildMaterial(TEngine *tEngine, const uint8_t* materialData, size_t length);
EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterial(TEngine *tEngine, TMaterial *tMaterial);
EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstance(TEngine *tEngine, TMaterialInstance *tMaterialInstance);
EMSCRIPTEN_KEEPALIVE TScene *Engine_createScene(TEngine *tEngine);
// Builds a skybox from an environment cubemap. A negative [intensity] leaves
// the filament default (30000) in place. [showSun] requires a SUN light in the
// scene to have any effect. [priority] is clamped by filament to [0..7];
// 7 (lowest priority, rendered last) is the default.
EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildSkybox(TEngine *tEngine, TTexture* tTexture, bool showSun, float intensity, uint8_t priority);
EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildColoredSkybox(TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority);
EMSCRIPTEN_KEEPALIVE TIndirectLight *Engine_buildIndirectLightFromIrradianceTexture(TEngine *tEngine, TTexture *tReflectionsTexture, TTexture* tIrradianceTexture, float intensity);
EMSCRIPTEN_KEEPALIVE TIndirectLight *Engine_buildIndirectLightFromIrradianceHarmonics(TEngine *tEngine, TTexture *tReflectionsTexture, float *irradianceHarmonics, float intensity);
EMSCRIPTEN_KEEPALIVE void Engine_destroySkybox(TEngine *tEngine, TSkybox *tSkybox);
EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLight(TEngine *tEngine, TIndirectLight *tIndirectLight);
EMSCRIPTEN_KEEPALIVE EntityId EntityManager_createEntity(TEntityManager *tEntityManager);
EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntity(TEntityManager *tEntityManager, EntityId entityId);
EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroy(TFence *tFence);

EMSCRIPTEN_KEEPALIVE TDebugRegistry *Engine_getDebugRegistry(TEngine *tEngine);
EMSCRIPTEN_KEEPALIVE bool DebugRegistry_hasProperty(TDebugRegistry *tDebugRegistry, const char *name);
EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_bool(TDebugRegistry *tDebugRegistry, const char *name, bool value);
EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_int(TDebugRegistry *tDebugRegistry, const char *name, int value);
EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_float(TDebugRegistry *tDebugRegistry, const char *name, float value);
EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_bool(TDebugRegistry *tDebugRegistry, const char *name, bool *outValue);
EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_int(TDebugRegistry *tDebugRegistry, const char *name, int *outValue);
EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_float(TDebugRegistry *tDebugRegistry, const char *name, float *outValue);

#ifdef __cplusplus
}
#endif

