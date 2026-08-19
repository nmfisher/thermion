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

// ---------------------------------------------------------------------------
// Runtime material compilation (.mat source -> .filamat package).
//
// Phase 1 of docs/research/runtime-material-compile.md. The real
// implementation is only linked into desktop builds (linux/macos/windows,
// where the artifact ships libfilamat + libmatp); every other platform gets
// a stub that fails with an explanatory message. The header declares the API
// unconditionally so bindings generate everywhere.
// ---------------------------------------------------------------------------

enum TMaterialPlatform {
    // Values match filamat::MaterialBuilderBase::Platform.
    T_MATERIAL_PLATFORM_DESKTOP = 0,
    T_MATERIAL_PLATFORM_MOBILE = 1,
    T_MATERIAL_PLATFORM_ALL = 2,
};
typedef enum TMaterialPlatform TMaterialPlatform;

enum TMaterialTargetApi {
    // Bit values match filamat::MaterialBuilderBase::TargetApi and may be
    // OR-ed together.
    T_MATERIAL_TARGET_API_OPENGL = 0x01,
    T_MATERIAL_TARGET_API_VULKAN = 0x02,
    T_MATERIAL_TARGET_API_METAL = 0x04,
    T_MATERIAL_TARGET_API_WEBGPU = 0x08,
    T_MATERIAL_TARGET_API_ALL = 0x0F,
    // Derive the target from the engine's active backend (recommended).
    T_MATERIAL_TARGET_API_FROM_ENGINE = 0x100,
};
typedef enum TMaterialTargetApi TMaterialTargetApi;

enum TMaterialOptimization {
    // Values match filamat::MaterialBuilderBase::Optimization.
    T_MATERIAL_OPTIMIZATION_NONE = 0,
    T_MATERIAL_OPTIMIZATION_PREPROCESSOR = 1,
    T_MATERIAL_OPTIMIZATION_SIZE = 2,
    T_MATERIAL_OPTIMIZATION_PERFORMANCE = 3,
};
typedef enum TMaterialOptimization TMaterialOptimization;

/// Compiles .mat [matSource] ([length] bytes, not necessarily
/// NUL-terminated) into a filamat package, synchronously on the calling
/// thread. #include directives must already be resolved by the caller (the
/// Dart layer flattens them).
///
/// [platform]/[targetApi]/[optimization] select the compilation targets;
/// pass T_MATERIAL_TARGET_API_FROM_ENGINE to derive targetApi from the
/// engine's backend.
///
/// [definesJson] is either nullptr or a flat JSON object of preprocessor
/// defines, e.g. `{"OCCLUSION": "1"}`. Only string keys/values and basic
/// backslash escapes are supported.
///
/// [embedSource] controls whether the .mat source is embedded in the
/// package (matc's no-embed-source flag).
///
/// On success returns a malloc'd buffer of *outSize bytes that the caller
/// must release with [Engine_freeCompiledMaterial]. On failure returns
/// nullptr and writes a NUL-terminated message into [outError] (capacity
/// [outErrorCap]).
EMSCRIPTEN_KEEPALIVE const uint8_t *Engine_compileMaterial(
    TEngine *tEngine,
    const char *matSource,
    size_t length,
    TMaterialPlatform platform,
    TMaterialTargetApi targetApi,
    TMaterialOptimization optimization,
    const char *definesJson,
    uint8_t embedSource,
    char *outError,
    size_t outErrorCap,
    size_t *outSize);

/// Releases a buffer returned by [Engine_compileMaterial].
EMSCRIPTEN_KEEPALIVE void Engine_freeCompiledMaterial(const uint8_t *data);

/// As [Engine_compileMaterial], but the work runs on the engine's render
/// thread. The task writes the malloc'd package to *[outData] and its size to
/// *[outSize] (release it with [Engine_freeCompiledMaterial]), or nullptr on
/// failure with the message in [outError], then invokes [onComplete] with
/// [requestId].
EMSCRIPTEN_KEEPALIVE void Engine_compileMaterialRenderThread(
    TEngine *tEngine,
    const char *matSource,
    size_t length,
    TMaterialPlatform platform,
    TMaterialTargetApi targetApi,
    TMaterialOptimization optimization,
    const char *definesJson,
    uint8_t embedSource,
    char *outError,
    size_t outErrorCap,
    const uint8_t **outData,
    size_t *outSize,
    uint32_t requestId,
    void (*onComplete)(int32_t requestId));
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

