#include "c_api/TEngine.h"

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/Material.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>

#include <ktxreader/Ktx1Reader.h>
#include <ktxreader/Ktx2Reader.h>

#include <imageio/ImageDecoder.h>
#include <imageio/ImageEncoder.h>
#include <image/ColorTransform.h>

#include <utils/EntityManager.h>

#include "Log.hpp"

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

        EMSCRIPTEN_KEEPALIVE TEngine *Engine_create(TBackend backend) {
            auto *engine = filament::Engine::create(static_cast<filament::Engine::Backend>(backend));
            return reinterpret_cast<TEngine *>(engine);
        }
        
        EMSCRIPTEN_KEEPALIVE TRenderer *Engine_createRenderer(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *renderer = engine->createRenderer();
            return reinterpret_cast<TRenderer *>(renderer);
        }

        EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createSwapChain(TEngine *tEngine, void *window, uint64_t flags) {            
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *swapChain = engine->createSwapChain(window, flags);
            return reinterpret_cast<TSwapChain*>(swapChain);
        }

        EMSCRIPTEN_KEEPALIVE TSwapChain *Engine_createHeadlessSwapChain(TEngine *tEngine, uint32_t width, uint32_t height, uint64_t flags) {            
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *swapChain = engine->createSwapChain(width, height, flags);
            return reinterpret_cast<TSwapChain*>(swapChain);
        }

    
        EMSCRIPTEN_KEEPALIVE TView *Engine_createView(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *view = engine->createView();
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

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_createCamera(TEngine* tEngine) {
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

        ::filament::Texture::InternalFormat convertToFilamentFormat(TTextureFormat tFormat) {
            switch (tFormat) {
                // 8-bits per element
                case TEXTUREFORMAT_R8:                     return ::filament::Texture::InternalFormat::R8;
                case TEXTUREFORMAT_R8_SNORM:               return ::filament::Texture::InternalFormat::R8_SNORM;
                case TEXTUREFORMAT_R8UI:                   return ::filament::Texture::InternalFormat::R8UI;
                case TEXTUREFORMAT_R8I:                    return ::filament::Texture::InternalFormat::R8I;
                case TEXTUREFORMAT_STENCIL8:               return ::filament::Texture::InternalFormat::STENCIL8;
                
                // 16-bits per element
                case TEXTUREFORMAT_R16F:                   return ::filament::Texture::InternalFormat::R16F;
                case TEXTUREFORMAT_R16UI:                  return ::filament::Texture::InternalFormat::R16UI;
                case TEXTUREFORMAT_R16I:                   return ::filament::Texture::InternalFormat::R16I;
                case TEXTUREFORMAT_RG8:                    return ::filament::Texture::InternalFormat::RG8;
                case TEXTUREFORMAT_RG8_SNORM:              return ::filament::Texture::InternalFormat::RG8_SNORM;
                case TEXTUREFORMAT_RG8UI:                  return ::filament::Texture::InternalFormat::RG8UI;
                case TEXTUREFORMAT_RG8I:                   return ::filament::Texture::InternalFormat::RG8I;
                case TEXTUREFORMAT_RGB565:                 return ::filament::Texture::InternalFormat::RGB565;
                case TEXTUREFORMAT_RGB9_E5:                return ::filament::Texture::InternalFormat::RGB9_E5;
                case TEXTUREFORMAT_RGB5_A1:                return ::filament::Texture::InternalFormat::RGB5_A1;
                case TEXTUREFORMAT_RGBA4:                  return ::filament::Texture::InternalFormat::RGBA4;
                case TEXTUREFORMAT_DEPTH16:                return ::filament::Texture::InternalFormat::DEPTH16;
                
                // 24-bits per element
                case TEXTUREFORMAT_RGB8:                   return ::filament::Texture::InternalFormat::RGB8;
                case TEXTUREFORMAT_SRGB8:                  return ::filament::Texture::InternalFormat::SRGB8;
                case TEXTUREFORMAT_RGB8_SNORM:             return ::filament::Texture::InternalFormat::RGB8_SNORM;
                case TEXTUREFORMAT_RGB8UI:                 return ::filament::Texture::InternalFormat::RGB8UI;
                case TEXTUREFORMAT_RGB8I:                  return ::filament::Texture::InternalFormat::RGB8I;
                case TEXTUREFORMAT_DEPTH24:                return ::filament::Texture::InternalFormat::DEPTH24;
                
                // 32-bits per element
                case TEXTUREFORMAT_R32F:                   return ::filament::Texture::InternalFormat::R32F;
                case TEXTUREFORMAT_R32UI:                  return ::filament::Texture::InternalFormat::R32UI;
                case TEXTUREFORMAT_R32I:                   return ::filament::Texture::InternalFormat::R32I;
                case TEXTUREFORMAT_RG16F:                  return ::filament::Texture::InternalFormat::RG16F;
                case TEXTUREFORMAT_RG16UI:                 return ::filament::Texture::InternalFormat::RG16UI;
                case TEXTUREFORMAT_RG16I:                  return ::filament::Texture::InternalFormat::RG16I;
                case TEXTUREFORMAT_R11F_G11F_B10F:         return ::filament::Texture::InternalFormat::R11F_G11F_B10F;
                case TEXTUREFORMAT_RGBA8:                  return ::filament::Texture::InternalFormat::RGBA8;
                case TEXTUREFORMAT_SRGB8_A8:               return ::filament::Texture::InternalFormat::SRGB8_A8;
                case TEXTUREFORMAT_RGBA8_SNORM:            return ::filament::Texture::InternalFormat::RGBA8_SNORM;
                case TEXTUREFORMAT_UNUSED:                 return ::filament::Texture::InternalFormat::UNUSED;
                case TEXTUREFORMAT_RGB10_A2:               return ::filament::Texture::InternalFormat::RGB10_A2;
                case TEXTUREFORMAT_RGBA8UI:                return ::filament::Texture::InternalFormat::RGBA8UI;
                case TEXTUREFORMAT_RGBA8I:                 return ::filament::Texture::InternalFormat::RGBA8I;
                case TEXTUREFORMAT_DEPTH32F:               return ::filament::Texture::InternalFormat::DEPTH32F;
                case TEXTUREFORMAT_DEPTH24_STENCIL8:       return ::filament::Texture::InternalFormat::DEPTH24_STENCIL8;
                case TEXTUREFORMAT_DEPTH32F_STENCIL8:      return ::filament::Texture::InternalFormat::DEPTH32F_STENCIL8;
                
                // 48-bits per element
                case TEXTUREFORMAT_RGB16F:                 return ::filament::Texture::InternalFormat::RGB16F;
                case TEXTUREFORMAT_RGB16UI:                return ::filament::Texture::InternalFormat::RGB16UI;
                case TEXTUREFORMAT_RGB16I:                 return ::filament::Texture::InternalFormat::RGB16I;
                
                // 64-bits per element
                case TEXTUREFORMAT_RG32F:                  return ::filament::Texture::InternalFormat::RG32F;
                case TEXTUREFORMAT_RG32UI:                 return ::filament::Texture::InternalFormat::RG32UI;
                case TEXTUREFORMAT_RG32I:                  return ::filament::Texture::InternalFormat::RG32I;
                case TEXTUREFORMAT_RGBA16F:                return ::filament::Texture::InternalFormat::RGBA16F;
                case TEXTUREFORMAT_RGBA16UI:               return ::filament::Texture::InternalFormat::RGBA16UI;
                case TEXTUREFORMAT_RGBA16I:                return ::filament::Texture::InternalFormat::RGBA16I;
                
                // 96-bits per element
                case TEXTUREFORMAT_RGB32F:                 return ::filament::Texture::InternalFormat::RGB32F;
                case TEXTUREFORMAT_RGB32UI:                return ::filament::Texture::InternalFormat::RGB32UI;
                case TEXTUREFORMAT_RGB32I:                 return ::filament::Texture::InternalFormat::RGB32I;
                
                // 128-bits per element
                case TEXTUREFORMAT_RGBA32F:                return ::filament::Texture::InternalFormat::RGBA32F;
                case TEXTUREFORMAT_RGBA32UI:               return ::filament::Texture::InternalFormat::RGBA32UI;
                case TEXTUREFORMAT_RGBA32I:                return ::filament::Texture::InternalFormat::RGBA32I;
                
                // Compressed formats
                case TEXTUREFORMAT_EAC_R11:                return ::filament::Texture::InternalFormat::EAC_R11;
                case TEXTUREFORMAT_EAC_R11_SIGNED:         return ::filament::Texture::InternalFormat::EAC_R11_SIGNED;
                case TEXTUREFORMAT_EAC_RG11:               return ::filament::Texture::InternalFormat::EAC_RG11;
                case TEXTUREFORMAT_EAC_RG11_SIGNED:        return ::filament::Texture::InternalFormat::EAC_RG11_SIGNED;
                case TEXTUREFORMAT_ETC2_RGB8:              return ::filament::Texture::InternalFormat::ETC2_RGB8;
                case TEXTUREFORMAT_ETC2_SRGB8:             return ::filament::Texture::InternalFormat::ETC2_SRGB8;
                case TEXTUREFORMAT_ETC2_RGB8_A1:           return ::filament::Texture::InternalFormat::ETC2_RGB8_A1;
                case TEXTUREFORMAT_ETC2_SRGB8_A1:          return ::filament::Texture::InternalFormat::ETC2_SRGB8_A1;
                case TEXTUREFORMAT_ETC2_EAC_RGBA8:         return ::filament::Texture::InternalFormat::ETC2_EAC_RGBA8;
                case TEXTUREFORMAT_ETC2_EAC_SRGBA8:        return ::filament::Texture::InternalFormat::ETC2_EAC_SRGBA8;
                
                // DXT formats
                case TEXTUREFORMAT_DXT1_RGB:               return ::filament::Texture::InternalFormat::DXT1_RGB;
                case TEXTUREFORMAT_DXT1_RGBA:              return ::filament::Texture::InternalFormat::DXT1_RGBA;
                case TEXTUREFORMAT_DXT3_RGBA:              return ::filament::Texture::InternalFormat::DXT3_RGBA;
                case TEXTUREFORMAT_DXT5_RGBA:              return ::filament::Texture::InternalFormat::DXT5_RGBA;
                case TEXTUREFORMAT_DXT1_SRGB:              return ::filament::Texture::InternalFormat::DXT1_SRGB;
                case TEXTUREFORMAT_DXT1_SRGBA:             return ::filament::Texture::InternalFormat::DXT1_SRGBA;
                case TEXTUREFORMAT_DXT3_SRGBA:             return ::filament::Texture::InternalFormat::DXT3_SRGBA;
                case TEXTUREFORMAT_DXT5_SRGBA:             return ::filament::Texture::InternalFormat::DXT5_SRGBA;
                
                // ASTC formats
                case TEXTUREFORMAT_RGBA_ASTC_4x4:          return ::filament::Texture::InternalFormat::RGBA_ASTC_4x4;
                case TEXTUREFORMAT_RGBA_ASTC_5x4:          return ::filament::Texture::InternalFormat::RGBA_ASTC_5x4;
                case TEXTUREFORMAT_RGBA_ASTC_5x5:          return ::filament::Texture::InternalFormat::RGBA_ASTC_5x5;
                case TEXTUREFORMAT_RGBA_ASTC_6x5:          return ::filament::Texture::InternalFormat::RGBA_ASTC_6x5;
                case TEXTUREFORMAT_RGBA_ASTC_6x6:          return ::filament::Texture::InternalFormat::RGBA_ASTC_6x6;
                case TEXTUREFORMAT_RGBA_ASTC_8x5:          return ::filament::Texture::InternalFormat::RGBA_ASTC_8x5;
                case TEXTUREFORMAT_RGBA_ASTC_8x6:          return ::filament::Texture::InternalFormat::RGBA_ASTC_8x6;
                case TEXTUREFORMAT_RGBA_ASTC_8x8:          return ::filament::Texture::InternalFormat::RGBA_ASTC_8x8;
                case TEXTUREFORMAT_RGBA_ASTC_10x5:         return ::filament::Texture::InternalFormat::RGBA_ASTC_10x5;
                case TEXTUREFORMAT_RGBA_ASTC_10x6:         return ::filament::Texture::InternalFormat::RGBA_ASTC_10x6;
                case TEXTUREFORMAT_RGBA_ASTC_10x8:         return ::filament::Texture::InternalFormat::RGBA_ASTC_10x8;
                case TEXTUREFORMAT_RGBA_ASTC_10x10:        return ::filament::Texture::InternalFormat::RGBA_ASTC_10x10;
                case TEXTUREFORMAT_RGBA_ASTC_12x10:        return ::filament::Texture::InternalFormat::RGBA_ASTC_12x10;
                case TEXTUREFORMAT_RGBA_ASTC_12x12:        return ::filament::Texture::InternalFormat::RGBA_ASTC_12x12;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_4x4:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_4x4;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_5x4:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_5x4;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_5x5:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_5x5;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_6x5:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_6x5;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_6x6:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_6x6;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x5:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_8x5;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x6:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_8x6;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_8x8:  return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_8x8;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x5: return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x5;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x6: return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x6;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x8: return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x8;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_10x10:return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_10x10;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_12x10:return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_12x10;
                case TEXTUREFORMAT_SRGB8_ALPHA8_ASTC_12x12:return ::filament::Texture::InternalFormat::SRGB8_ALPHA8_ASTC_12x12;
                
                // RGTC formats
                case TEXTUREFORMAT_RED_RGTC1:              return ::filament::Texture::InternalFormat::RED_RGTC1;
                case TEXTUREFORMAT_SIGNED_RED_RGTC1:       return ::filament::Texture::InternalFormat::SIGNED_RED_RGTC1;
                case TEXTUREFORMAT_RED_GREEN_RGTC2:        return ::filament::Texture::InternalFormat::RED_GREEN_RGTC2;
                case TEXTUREFORMAT_SIGNED_RED_GREEN_RGTC2: return ::filament::Texture::InternalFormat::SIGNED_RED_GREEN_RGTC2;
                
                // BPTC formats
                case TEXTUREFORMAT_RGB_BPTC_SIGNED_FLOAT:  return ::filament::Texture::InternalFormat::RGB_BPTC_SIGNED_FLOAT;
                case TEXTUREFORMAT_RGB_BPTC_UNSIGNED_FLOAT:return ::filament::Texture::InternalFormat::RGB_BPTC_UNSIGNED_FLOAT;
                case TEXTUREFORMAT_RGBA_BPTC_UNORM:        return ::filament::Texture::InternalFormat::RGBA_BPTC_UNORM;
                case TEXTUREFORMAT_SRGB_ALPHA_BPTC_UNORM:  return ::filament::Texture::InternalFormat::SRGB_ALPHA_BPTC_UNORM;
                
                default:
                    // Fallback to a common format if an unknown format is provided
                    return ::filament::Texture::InternalFormat::RGBA8;
            }
        }

        EMSCRIPTEN_KEEPALIVE TTexture *Engine_buildTexture(TEngine *tEngine, 
            uint32_t width, 
            uint32_t height, 
            uint32_t depth, 
            uint8_t levels, 
            TTextureSamplerType tSamplerType, 
            TTextureFormat tFormat)
        {
            TRACE("Creating texture %dx%d (depth %d), sampler type %d, format %d", width, height, depth, static_cast<int>(tSamplerType), static_cast<int>(tFormat));
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto format = convertToFilamentFormat(tFormat);
            auto samplerType = static_cast<::filament::Texture::Sampler>(static_cast<int>(tSamplerType));
            auto *texture = Texture::Builder()
                .width(width)
                .height(height)
                .depth(depth)
                .levels(levels)
                .sampler(samplerType)
                .format(format) 
                .build(*engine);
            if(texture) {
                TRACE("Texture successfully created");
            } else { 
                Log("Error: failed to created texture");
            }
            
            return reinterpret_cast<TTexture *>(texture);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyTexture(TEngine *tEngine, TTexture *tTexture) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *texture = reinterpret_cast<Texture *>(tTexture);
            engine->destroy(texture);
        }

        EMSCRIPTEN_KEEPALIVE TFence *Engine_createFence(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *fence = engine->createFence();
            return reinterpret_cast<TFence *>(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyFence(TEngine *tEngine, TFence *tFence) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *fence = reinterpret_cast<Fence *>(tFence);
            Fence::waitAndDestroy(fence);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_flushAndWait(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            #ifdef __EMSCRIPTEN__
                engine->execute();
                emscripten_webgl_commit_frame();
            #else
                engine->flushAndWait();
            #endif
        }

        EMSCRIPTEN_KEEPALIVE TScene *Engine_createScene(TEngine *tEngine) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *scene = engine->createScene();    
            return reinterpret_cast<TScene *>(scene);
        }

        EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildSkybox(TEngine *tEngine, uint8_t* ktxData, size_t length, void(*onTextureUploadComplete)()) {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto copy = new std::vector<uint8_t>(ktxData, ktxData + length);
            image::Ktx1Bundle *skyboxBundle =
                new image::Ktx1Bundle(static_cast<const uint8_t *>(copy->data()),
                                      static_cast<uint32_t>(length));

            std::vector<void *> *callbackData = new std::vector<void *>{
                reinterpret_cast<void *>(onTextureUploadComplete),
                reinterpret_cast<void *>(skyboxBundle),
                reinterpret_cast<void *>(copy) 
            };
        
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
                    (void*)callbackData);
            auto *skybox =
                filament::Skybox::Builder()
                    .environment(texture)
                    .build(*engine);
        
            return reinterpret_cast<TSkybox *>(skybox);
        }


#ifdef __cplusplus
    }
}
#endif
