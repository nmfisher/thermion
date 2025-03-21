#include "c_api/TEngine.h"

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

#include <ktxreader/Ktx1Reader.h>
#include <ktxreader/Ktx2Reader.h>

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

        uint64_t TSWAP_CHAIN_CONFIG_TRANSPARENT = filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT;
        uint64_t TSWAP_CHAIN_CONFIG_READABLE = filament::backend::SWAP_CHAIN_CONFIG_READABLE;
        uint64_t TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER = filament::backend::SWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER;
        uint64_t TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER = filament::backend::SWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;

        EMSCRIPTEN_KEEPALIVE TEngine *Engine_create(
            TBackend backend,
            void* tPlatform,
            void* tSharedContext,
            uint8_t stereoscopicEyeCount,
            bool disableHandleUseAfterFreeCheck)
        {
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

        EMSCRIPTEN_KEEPALIVE void Engine_destroy(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            Engine::destroy(engine);
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
                TRACE("SWAP_CHAIN_CONFIG_READABLE");
            }
            #endif
            return reinterpret_cast<TSwapChain *>(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroySwapChain(TEngine *tEngine, TSwapChain *tSwapChain) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *swapChain = reinterpret_cast<SwapChain *>(tSwapChain);
            engine->destroy(swapChain);
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

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_createCamera(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            utils::Entity entity = utils::EntityManager::get().create();
            auto *camera = engine->createCamera(entity);
            return reinterpret_cast<TCamera *>(camera);
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

        EMSCRIPTEN_KEEPALIVE void Engine_destroyFence(TEngine *tEngine, TFence *tFence)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *fence = reinterpret_cast<Fence *>(tFence);
            Fence::waitAndDestroy(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWait(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
#ifdef __EMSCRIPTEN__
            engine->execute();
            emscripten_webgl_commit_frame();
#else
    engine->flushAndWait();
#endif
        }

        EMSCRIPTEN_KEEPALIVE TScene *Engine_createScene(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *scene = engine->createScene();
            return reinterpret_cast<TScene *>(scene);
        }

        EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildSkybox(TEngine *tEngine, uint8_t *ktxData, size_t length, void (*onTextureUploadComplete)())
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto copy = new std::vector<uint8_t>(ktxData, ktxData + length);
            image::Ktx1Bundle *skyboxBundle =
                new image::Ktx1Bundle(static_cast<const uint8_t *>(copy->data()),
                                      static_cast<uint32_t>(length));

            std::vector<void *> *callbackData = new std::vector<void *>{
                reinterpret_cast<void *>(onTextureUploadComplete),
                reinterpret_cast<void *>(skyboxBundle),
                reinterpret_cast<void *>(copy)};

            auto *texture =
                ktxreader::Ktx1Reader::createTexture(
                    engine, *skyboxBundle, false, [](void *userdata)
                    {
                        std::vector<void*>* vec = (std::vector<void*>*)userdata;
                        
                        void *callbackPtr = vec->at(0);
                        image::Ktx1Bundle *skyboxBundle = reinterpret_cast<image::Ktx1Bundle *>(vec->at(1));
                        std::vector<uint8_t> *copy = reinterpret_cast<std::vector<uint8_t>*>(vec->at(2));

                        delete vec;
                        
                        if (callbackPtr)
                        {
                          void (*callback)(void) = (void (*)(void))callbackPtr;
                          callback();
                        } 
                        delete skyboxBundle;
                        delete copy; 
                    },
                    (void *)callbackData);
            auto *skybox =
                filament::Skybox::Builder()
                    .environment(texture)
                    .build(*engine);

            return reinterpret_cast<TSkybox *>(skybox);
        }

        EMSCRIPTEN_KEEPALIVE TIndirectLight *Engine_buildIndirectLight(TEngine *tEngine, uint8_t *ktxData, size_t length, float intensity, void (*onTextureUploadComplete)())
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto copy = new std::vector<uint8_t>(ktxData, ktxData + length);

            image::Ktx1Bundle *iblBundle =
                new image::Ktx1Bundle(static_cast<const uint8_t *>(copy->data()),
                                      static_cast<uint32_t>(length));
            filament::math::float3 harmonics[9];
            iblBundle->getSphericalHarmonics(harmonics);


            std::vector<void *> *callbackData = new std::vector<void *>{
                reinterpret_cast<void *>(onTextureUploadComplete),
                reinterpret_cast<void *>(iblBundle),
                reinterpret_cast<void *>(copy)};

            auto *texture =
                ktxreader::Ktx1Reader::createTexture(
                    engine, *iblBundle, false, [](void *userdata)
                    {
                        std::vector<void*>* vec = (std::vector<void*>*)userdata;
                        
                        void *callbackPtr = vec->at(0);
                        image::Ktx1Bundle *iblBundle = reinterpret_cast<image::Ktx1Bundle *>(vec->at(1));
                        std::vector<uint8_t> *copy = reinterpret_cast<std::vector<uint8_t>*>(vec->at(2));

                        delete vec;
                        
                        if (callbackPtr)
                        {
                          void (*callback)(void) = (void (*)(void))callbackPtr;
                          callback();
                        } 
                        delete iblBundle;
                        delete copy;                     
                },

                (void *)callbackData);
            auto *indirectLight = filament::IndirectLight::Builder()
                                      .reflections(texture)
                                      .irradiance(3, harmonics)
                                      .intensity(intensity)
                                      .build(*engine);
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
            if(indirectLight->getReflectionsTexture()) {
                engine->destroy(indirectLight->getReflectionsTexture());
            }
            if(indirectLight->getIrradianceTexture()) {
                engine->destroy(indirectLight->getIrradianceTexture());
            }
            engine->destroy(indirectLight);
        }

#ifdef __cplusplus
    }
}
#endif
