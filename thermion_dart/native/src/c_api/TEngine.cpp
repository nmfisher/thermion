#ifdef __EMSCRIPTEN__
#include <emscripten/html5.h>
#include "ThermionWebApi.h"
#include <backend/platforms/PlatformWebGL.h>
#endif

#include "c_api/TEngine.h"

#include <filament/Camera.h>
#include <filament/backend/DriverEnums.h>
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
            auto handle = Thermion_createGLContext();
            tSharedContext = (void*)handle;
            tPlatform = (backend::Platform *)new filament::backend::PlatformWebGL();
            #endif
            filament::Engine::Config config;
            config.stereoscopicEyeCount = stereoscopicEyeCount;
            config.disableHandleUseAfterFreeCheck = disableHandleUseAfterFreeCheck;
            auto *platform = reinterpret_cast<filament::backend::Platform *>(tPlatform);
            auto *engine = filament::Engine::create(
                static_cast<filament::Engine::Backend>(backend),
                platform,
                tSharedContext,
                &config
            );
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
            return reinterpret_cast<TTransformManager *>(&transformManager);
        }

        EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &renderableManager = engine->getRenderableManager();
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
            return reinterpret_cast<TEntityManager *>(&entityManager);
        }

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_createCamera(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            utils::Entity entity = utils::EntityManager::get().create();
            auto *camera = engine->createCamera(entity);
            return reinterpret_cast<TCamera *>(camera);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyCamera(TEngine *tEngine, TCamera *tCamera) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            engine->destroyCameraComponent(camera->getEntity());
            utils::EntityManager::get().destroy(camera->getEntity());
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
            return reinterpret_cast<TScene *>(scene);
        }

        EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildSkybox(TEngine *tEngine, TTexture *tTexture)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *texture = reinterpret_cast<Texture *>(tTexture);
            
            auto *skybox =
                filament::Skybox::Builder()
                    .environment(texture)
                    .build(*engine);

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

#ifdef __cplusplus
    }
}
#endif
