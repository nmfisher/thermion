#ifdef __EMSCRIPTEN__
#include <emscripten/html5.h>
#include "ThermionWebApi.h"
#include <backend/platforms/PlatformWebGL.h>
#endif

#include "c_api/TEngine.h"

#include <filament/Camera.h>
#include <backend/DriverEnums.h>
#include <filament/DebugRegistry.h>
#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndirectLight.h>
#include <filament/Material.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>
#include <gltfio/math.h>
#include <gltfio/materials/uberarchive.h>

#include <imageio/ImageDecoder.h>
#include <imageio/ImageEncoder.h>
#include <image/ColorTransform.h>

#include <utils/EntityManager.h>
#include <utils/NameComponentManager.h>

#include "Log.hpp"
#include "MathUtils.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;

        // Defined in ThermionDartRenderThreadApi.cpp. Direct-API getters use
        // these to record which render thread owns an engine-scoped object
        // (and which canvas the active thread's engine renders to).
        void RenderThread_registerOwnerFromOwner(void *owner, void *knownOwner);
        const char *RenderThread_getActiveCanvasSelector();
#endif

        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_TRANSPARENT = filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT;
        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_READABLE = filament::backend::SWAP_CHAIN_CONFIG_READABLE;
        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER = filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER;
        EMSCRIPTEN_KEEPALIVE uint64_t TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER = filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;

        EMSCRIPTEN_KEEPALIVE TEngine *Engine_create(
            TBackend backend,
            void* tPlatform,
            void* tSharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck)
        {
            #ifdef __EMSCRIPTEN__
            // Engine_create runs inside the engine's RenderThread task, so the
            // active thread IS this engine's thread — create the WebGL context
            // on the canvas that was transferred to it.
            auto handle = Thermion_createGLContext(RenderThread_getActiveCanvasSelector());
            tSharedContext = (void*)handle;
            tPlatform = (backend::Platform *)new filament::backend::PlatformWebGL();
            #endif
            filament::Engine::Config config;
            config.stereoscopicEyeCount = stereoscopicEyeCount;
            config.disableHandleUseAfterFreeCheck = disableHandleUseAfterFreeCheck;

            auto *platform = reinterpret_cast<filament::backend::Platform *>(tPlatform);
                  
            auto *engine = filament::Engine::Builder()
                .backend(static_cast<filament::Engine::Backend>(backend))
                .platform(platform)
                .featureLevel(filament::Engine::FeatureLevel::FEATURE_LEVEL_1)
                .sharedContext(tSharedContext)
                .config(&config)
                .build();
            
            return reinterpret_cast<TEngine *>(engine);
        }

        EMSCRIPTEN_KEEPALIVE TFeatureLevel Engine_getSupportedFeatureLevel(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto featureLevel = engine->getSupportedFeatureLevel();
            switch(featureLevel) {
                case filament::backend::FeatureLevel::FEATURE_LEVEL_0:
                    return FEATURE_LEVEL_0;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_1:
                    return FEATURE_LEVEL_1;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_2:
                    return FEATURE_LEVEL_2;
                case filament::backend::FeatureLevel::FEATURE_LEVEL_3:
                    return FEATURE_LEVEL_3;
            }
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroy(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            Engine::destroy(engine);
            TRACE("Engine destroyed");
        }

        EMSCRIPTEN_KEEPALIVE TRenderer *Engine_createRenderer(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *renderer = engine->createRenderer();
            return reinterpret_cast<TRenderer *>(renderer);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyRenderer(TEngine *tEngine, TRenderer *tRenderer)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *renderer = reinterpret_cast<Renderer *>(tRenderer);
            engine->destroy(renderer);
        }

        EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createSwapChain(TEngine *tEngine, void *window, uint64_t flags)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            #ifdef ENABLE_TRACING
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) == filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) {
                TRACE("SWAP_CHAIN_CONFIG_TRANSPARENT");
                
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_READABLE) == filament::backend::SWAP_CHAIN_CONFIG_READABLE) {
                TRACE("SWAP_CHAIN_CONFIG_READABLE");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) == filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) {
                TRACE("SWAP_CHAIN_CONFIG_READABLE");
            }
            #endif
            auto *swapChain = engine->createSwapChain(window, flags);
            return reinterpret_cast<TSwapChain *>(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createHeadlessSwapChain(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags)
        {
            TRACE("Creating headless swapchain %dx%d, flags %flags", width, height, flags);
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *swapChain = engine->createSwapChain(width, height, flags);
            #ifdef ENABLE_TRACING
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) == filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT) {
                TRACE("SWAP_CHAIN_CONFIG_TRANSPARENT");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_READABLE) == filament::backend::SWAP_CHAIN_CONFIG_READABLE) {
                TRACE("SWAP_CHAIN_CONFIG_READABLE");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) == filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER) {
                TRACE("SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER");
            }
            if((flags & filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER) == filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER) {
                TRACE("SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER");
            }
            #endif
            return reinterpret_cast<TSwapChain *>(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChain(TEngine *tEngine, TSwapChain *tSwapChain) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *swapChain = reinterpret_cast<SwapChain *>(tSwapChain);
            engine->destroy(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyView(TEngine *tEngine, TView *tView) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *view = reinterpret_cast<View *>(tView);
            engine->destroy(view);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyScene(TEngine *tEngine, TScene *tScene) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *scene = reinterpret_cast<Scene *>(tScene);
            engine->destroy(scene);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyColorGrading(TEngine *tEngine, TColorGrading *tColorGrading) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *colorGrading = reinterpret_cast<ColorGrading *>(tColorGrading);
            engine->destroy(colorGrading);
        }

        EMSCRIPTEN_KEEPALIVE TView *Engine_createView(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *view = engine->createView();
            view->setShadowingEnabled(false);
            view->setAmbientOcclusionOptions({.enabled = false});
            view->setDynamicResolutionOptions({.enabled = false});
            return reinterpret_cast<TView *>(view);
        }

        EMSCRIPTEN_KEEPALIVE TTransformManager *Engine_getTransformManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &transformManager = engine->getTransformManager();
            // Direct-API getters run on the main thread; record which render
            // thread owns this manager so RenderThread dispatch can route to it.
            RenderThread_registerOwnerFromOwner(&transformManager, tEngine);
            return reinterpret_cast<TTransformManager *>(&transformManager);
        }

        EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &renderableManager = engine->getRenderableManager();
            RenderThread_registerOwnerFromOwner(&renderableManager, tEngine);
            return reinterpret_cast<TRenderableManager *>(&renderableManager);
        }

        EMSCRIPTEN_KEEPALIVE TLightManager *Engine_getLightManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &lightManager = engine->getLightManager();
            return reinterpret_cast<TLightManager *>(&lightManager);
        }

        EMSCRIPTEN_KEEPALIVE TEntityManager *Engine_getEntityManager(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &entityManager = engine->getEntityManager();
            RenderThread_registerOwnerFromOwner(&entityManager, tEngine);
            return reinterpret_cast<TEntityManager *>(&entityManager);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_setAutomaticInstancingEnabled(TEngine *tEngine, bool enabled) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            engine->setAutomaticInstancingEnabled(enabled);
        }

        EMSCRIPTEN_KEEPALIVE size_t Engine_getMaxAutomaticInstances(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            return engine->getMaxAutomaticInstances();
        }

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_createCamera(TEngine *tEngine, EntityId entityId)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            utils::Entity entity = utils::Entity::import(entityId);
            auto *camera = engine->createCamera(entity);
            return reinterpret_cast<TCamera *>(camera);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyCamera(TEngine *tEngine, TCamera *tCamera) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            auto &em = utils::EntityManager::get();
            engine->destroyCameraComponent(camera->getEntity());
        }

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine *tEngine, EntityId entityId)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto entity = utils::Entity::import(entityId);
            if (entity.isNull())
            {
                return std::nullptr_t();
            }
            auto *camera = engine->getCameraComponent(entity);
            return reinterpret_cast<TCamera *>(camera);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_setTransform(TEngine *tEngine, EntityId entity, double4x4 transform)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &transformManager = engine->getTransformManager();

            auto transformInstance = transformManager.getInstance(utils::Entity::import(entity));
            if (!transformInstance.isValid())
            {
                Log("Transform instance not valid");
            }
            transformManager.setTransform(transformInstance, convert_double4x4_to_mat4(transform));
        }

        EMSCRIPTEN_KEEPALIVE TMaterial *Engine_buildMaterial(TEngine *tEngine, const uint8_t *materialData, size_t length)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *material = Material::Builder()
                                 .package(materialData, length)
                                 .build(*engine);
            return reinterpret_cast<TMaterial *>(material);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterial(TEngine *tEngine, TMaterial *tMaterial)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *material = reinterpret_cast<Material *>(tMaterial);
            engine->destroy(material);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterialInstance(TEngine *tEngine, TMaterialInstance *tMaterialInstance) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *mi = reinterpret_cast<MaterialInstance *>(tMaterialInstance);
            engine->destroy(mi);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyTexture(TEngine *tEngine, TTexture *tTexture)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *texture = reinterpret_cast<Texture *>(tTexture);
            // Parent resources can release a texture as part of their queued
            // destruction. Treat a later explicit release as idempotent;
            // Engine::destroy on an invalid texture can raise inside the
            // render-thread packaged_task and strand the Dart completion.
            if (!engine->isValid(texture))
            {
                return;
            }
            engine->destroy(texture);
        }

        EMSCRIPTEN_KEEPALIVE TFence *Engine_createFence(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *fence = engine->createFence();
            return reinterpret_cast<TFence *>(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Fence_waitAndDestroy(TFence *tFence) {
            auto *fence = reinterpret_cast<filament::Fence *>(tFence);
            Fence::waitAndDestroy(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyFence(TEngine *tEngine, TFence *tFence)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *fence = reinterpret_cast<Fence *>(tFence);
            Fence::waitAndDestroy(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWait(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            engine->flushAndWait();
        }
        
        EMSCRIPTEN_KEEPALIVE void Engine_execute(TEngine *tEngine) {
            #ifdef __EMSCRIPTEN__
                auto *engine = reinterpret_cast<Engine *>(tEngine);
                engine->execute();
            #else
                Log("WARNING - ignored on non-WASM");
            #endif
        }

        EMSCRIPTEN_KEEPALIVE TScene *Engine_createScene(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *scene = engine->createScene();
            RenderThread_registerOwnerFromOwner(scene, tEngine);
            return reinterpret_cast<TScene *>(scene);
        }

        EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildSkybox(TEngine *tEngine, TTexture *tTexture, bool showSun, float intensity, uint8_t priority)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *texture = reinterpret_cast<Texture *>(tTexture);

            auto skyboxBuilder = filament::Skybox::Builder();

            if (texture)
            {
                skyboxBuilder.environment(texture);
            }
            skyboxBuilder.showSun(showSun);
            if (intensity >= 0.0f)
            {
                skyboxBuilder.intensity(intensity);
            }
            skyboxBuilder.priority(priority);

            auto *skybox = skyboxBuilder.build(*engine);

            return reinterpret_cast<TSkybox *>(skybox);
        }

        EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildColoredSkybox(TEngine *tEngine, float r, float g, float b, float a, bool showSun, float intensity, uint8_t priority)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto skyboxBuilder = filament::Skybox::Builder()
                .color({r, g, b, a})
                .showSun(showSun)
                .priority(priority);
            if (intensity >= 0.0f)
            {
                skyboxBuilder.intensity(intensity);
            }
            auto *skybox = skyboxBuilder.build(*engine);
            return reinterpret_cast<TSkybox *>(skybox);
        }

        EMSCRIPTEN_KEEPALIVE TIndirectLight *Engine_buildIndirectLightFromIrradianceTexture(TEngine *tEngine, TTexture *tReflectionsTexture, TTexture* tIrradianceTexture, float intensity)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *reflectionsTexture = reinterpret_cast<Texture *>(tReflectionsTexture);
            auto *irradianceTexture = reinterpret_cast<Texture *>(tIrradianceTexture);

            auto indirectLightBuilder = filament::IndirectLight::Builder().intensity(intensity);

            if(!irradianceTexture) {
                Log("Irradiance texture must not be empty");
                return std::nullptr_t();
            }
            
            if(reflectionsTexture) {
                indirectLightBuilder.reflections(reflectionsTexture);
            }

                                                                            
            auto *indirectLight = indirectLightBuilder.build(*engine);
            return reinterpret_cast<TIndirectLight *>(indirectLight);
        }

         EMSCRIPTEN_KEEPALIVE TIndirectLight *Engine_buildIndirectLightFromIrradianceHarmonics(TEngine *tEngine, TTexture *tReflectionsTexture, float *harmonics, float intensity)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *reflectionsTexture = reinterpret_cast<Texture *>(tReflectionsTexture);

            auto indirectLightBuilder = filament::IndirectLight::Builder().intensity(intensity);

            if(reflectionsTexture) {
                indirectLightBuilder.reflections(reflectionsTexture);
            }
            
            if(harmonics) {
                filament::math::float3 sphericalHarmonics[9];
                memcpy(sphericalHarmonics, harmonics, 27 * sizeof(float));
                indirectLightBuilder.irradiance(3, sphericalHarmonics);
            }
                                                                            
            auto *indirectLight = indirectLightBuilder.build(*engine);
            return reinterpret_cast<TIndirectLight *>(indirectLight);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroySkybox(TEngine *tEngine, TSkybox *tSkybox) {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *skybox = reinterpret_cast<filament::Skybox *>(tSkybox);
            // Callers can destroy a caller-attached skybox themselves before
            // the scene (or a viewer teardown that derives from the scene)
            // releases it. Treat a later explicit release as idempotent, as
            // Engine_destroyTexture does.
            if (!engine->isValid(skybox))
            {
                return;
            }
            if(skybox->getTexture()) {
                engine->destroy(skybox->getTexture());
            }
            engine->destroy(skybox);
        }
        
        EMSCRIPTEN_KEEPALIVE void Engine_destroyIndirectLight(TEngine *tEngine, TIndirectLight *tIndirectLight) {
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto *indirectLight = reinterpret_cast<filament::IndirectLight *>(tIndirectLight);
            engine->destroy(indirectLight);
        }

        EMSCRIPTEN_KEEPALIVE EntityId EntityManager_createEntity(TEntityManager *tEntityManager) {
            auto entityManager = reinterpret_cast<utils::EntityManager *>(tEntityManager);
            auto entity = entityManager->create();
            return utils::Entity::smuggle(entity);
        }

        EMSCRIPTEN_KEEPALIVE void EntityManager_destroyEntity(TEntityManager *tEntityManager, EntityId entityId) {
            auto entityManager = reinterpret_cast<utils::EntityManager *>(tEntityManager);
            entityManager->destroy(utils::Entity::import(entityId));
        }

        EMSCRIPTEN_KEEPALIVE TDebugRegistry *Engine_getDebugRegistry(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &debugRegistry = engine->getDebugRegistry();
            return reinterpret_cast<TDebugRegistry *>(&debugRegistry);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_hasProperty(TDebugRegistry *tDebugRegistry, const char *name) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->hasProperty(name);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_bool(TDebugRegistry *tDebugRegistry, const char *name, bool value) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->setProperty(name, value);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_int(TDebugRegistry *tDebugRegistry, const char *name, int value) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->setProperty(name, value);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_setProperty_float(TDebugRegistry *tDebugRegistry, const char *name, float value) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->setProperty(name, value);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_bool(TDebugRegistry *tDebugRegistry, const char *name, bool *outValue) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->getProperty(name, outValue);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_int(TDebugRegistry *tDebugRegistry, const char *name, int *outValue) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->getProperty(name, outValue);
        }

        EMSCRIPTEN_KEEPALIVE bool DebugRegistry_getProperty_float(TDebugRegistry *tDebugRegistry, const char *name, float *outValue) {
            auto *debugRegistry = reinterpret_cast<filament::DebugRegistry *>(tDebugRegistry);
            return debugRegistry->getProperty(name, outValue);
        }

#ifdef __cplusplus
    }
}
#endif
