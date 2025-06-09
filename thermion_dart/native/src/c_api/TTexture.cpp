#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include <vector>

#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/RenderTarget.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <filament/backend/DriverEnums.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>
#include <filament/image/LinearImage.h>
#include <filament/image/ColorTransform.h>
#include <filament/backend/DriverEnums.h>

#include "c_api/TTexture.h"

#include "Log.hpp"

#define STB_IMAGE_IMPLEMENTATION
#include <filament/third_party/stb/stb_image.h>

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament::backend;
        using namespace image;


#endif

    inline float to_float(uint8_t v) {
        return float(v);
    }


    EMSCRIPTEN_KEEPALIVE TLinearImage *Image_decode(uint8_t *data, size_t length, const char *name = "image", bool alpha = true)
    {

        auto start = std::chrono::high_resolution_clock::now();

        int width, height, channels;

        TRACE("Loading image from buffer of length %lu bytes (alpha : %s)", length, alpha ? "true" : "false");
        
        uint8_t *imgData = stbi_load_from_memory(data, length, &width, &height, &channels, alpha ? 4 : 3);
        
        if (!imgData) {
            ERROR("Failed to decode image");
            return nullptr;
        }
        
        LinearImage *linearImage;
        
        if(alpha) {
            linearImage = new LinearImage(toLinearWithAlpha<uint8_t>(
                width,
                height, 
                width * 4,
                imgData,
                to_float, sRGBToLinear<filament::math::float4>));
        } else {
            linearImage = new LinearImage(toLinear<uint8_t>(
                width,
                height,
                width * 3,
                imgData,
                to_float, sRGBToLinear<filament::math::float3>));
        }

        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

        TRACE("Image decoded successfully in %lld ms (%dx%dx%d)", duration.count(), width, height, channels);        
        
        if (!linearImage->isValid())
        {
            Log("Failed to decode image.");
            return nullptr;
        }
                
        return reinterpret_cast<TLinearImage *>(linearImage);
    }

        EMSCRIPTEN_KEEPALIVE float *Image_getBytes(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getPixelRef();
        }

        EMSCRIPTEN_KEEPALIVE uint32_t Image_getWidth(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getWidth();
        }
        EMSCRIPTEN_KEEPALIVE uint32_t Image_getHeight(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getHeight();
        }
        EMSCRIPTEN_KEEPALIVE uint32_t Image_getChannels(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            return linearImage->getChannels();
        }

        EMSCRIPTEN_KEEPALIVE void Image_destroy(TLinearImage *tLinearImage)
        {
            auto *linearImage = reinterpret_cast<::image::LinearImage *>(tLinearImage);
            delete linearImage;
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

        EMSCRIPTEN_KEEPALIVE TTexture *Texture_build(
            TEngine *tEngine, 
            uint32_t width, 
            uint32_t height, 
            uint32_t depth, 
            uint8_t levels, 
            uint16_t tUsage,
            intptr_t import,
            TTextureSamplerType tSamplerType, 
            TTextureFormat tFormat
        )
        {
            TRACE("Creating texture %dx%d (depth %d), sampler type %d, format %d tUsage %d, %d levels", width, height, depth, static_cast<int>(tSamplerType), static_cast<int>(tFormat), tUsage, levels);
            auto *engine = reinterpret_cast<::filament::Engine *>(tEngine);
            auto format = convertToFilamentFormat(tFormat);
            auto samplerType = static_cast<::filament::Texture::Sampler>(static_cast<int>(tSamplerType));
            auto usage = static_cast<TextureUsage>(tUsage);
            
            auto builder = ::filament::Texture::Builder()
                .width(width)
                .height(height)
                .depth(depth)
                .levels(levels)
                .sampler(samplerType)
                .format(format) 
                .usage(usage);
            if(import) {
                TRACE("Importing texture with handle : %d", import);
                builder.import(import);
            }
            auto *texture = builder
                .build(*engine);
            if(texture) {
                TRACE("Texture successfully created with %d levels", texture->getLevels());
            } else { 
                Log("Error: failed to created texture");
            }
            
            return reinterpret_cast<TTexture *>(texture);
        }

        EMSCRIPTEN_KEEPALIVE size_t Texture_getLevels(TTexture *tTexture) {
            auto texture = reinterpret_cast<filament::Texture *>(tTexture);
            return texture->getLevels();
        }

        EMSCRIPTEN_KEEPALIVE bool Texture_loadImage(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage, TPixelDataFormat tBufferFormat, TPixelDataType tPixelDataType, int level)
        {
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);
            auto image = reinterpret_cast<::image::LinearImage *>(tImage);
            auto texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto bufferFormat = static_cast<PixelBufferDescriptor::PixelDataFormat>(static_cast<int>(tBufferFormat));
            auto pixelDataType = static_cast<PixelBufferDescriptor::PixelDataType>(static_cast<int>(tPixelDataType));

            uint32_t w = image->getWidth();
            uint32_t h = image->getHeight();
            uint32_t channels = image->getChannels();

            size_t size;
            switch (bufferFormat)
            {
            case PixelBufferDescriptor::PixelDataFormat::RGB:
            case PixelBufferDescriptor::PixelDataFormat::RGBA:
                size = w * h * channels * sizeof(float);
                break;
            case PixelBufferDescriptor::PixelDataFormat::RGB_INTEGER:
            case PixelBufferDescriptor::PixelDataFormat::RGBA_INTEGER:
                size = w * h * channels * sizeof(uint8_t);
                break;
            default:
                Log("Unsupported buffer format type : %d", bufferFormat);
                return false;
            }

            TRACE("Loading image from dimensions %d x %d, channels %d, size %d, buffer format %d and pixel data type %d", w, h, channels, size, bufferFormat, pixelDataType);

            filament::Texture::PixelBufferDescriptor buffer(
                image->getPixelRef(),
                size,
                bufferFormat,
                pixelDataType);

            texture->setImage(*engine, level, std::move(buffer));
            return true;
        }

        EMSCRIPTEN_KEEPALIVE bool Texture_setImage(
            TEngine *tEngine,
            TTexture *tTexture,
            uint32_t level,
            uint8_t *data,
            size_t size,
            uint32_t width,
            uint32_t height,
            uint32_t channels,
            uint32_t tBufferFormat,
            uint32_t tPixelDataType)
        {
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);

            auto texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto bufferFormat = static_cast<PixelBufferDescriptor::PixelDataFormat>(tBufferFormat);
            auto pixelDataType = static_cast<PixelBufferDescriptor::PixelDataType>(tPixelDataType);

            switch (bufferFormat)
            {
                case PixelBufferDescriptor::PixelDataFormat::RGB:
                case PixelBufferDescriptor::PixelDataFormat::RGBA:
                case PixelBufferDescriptor::PixelDataFormat::RGB_INTEGER:
                case PixelBufferDescriptor::PixelDataFormat::RGBA_INTEGER:
                    break;
                default:
                    Log("Unsupported buffer format type : %d", bufferFormat);
                    return false;
            }

            // the texture upload is async, so we need to copy the buffer
            auto *buffer = new std::vector<uint8_t>(size);
            std::copy(data, data + size, buffer->begin());

            filament::Texture::PixelBufferDescriptor::Callback freeCallback = [](void *buf, size_t,
                void *data)
            {
                delete reinterpret_cast<std::vector<uint8_t> *>(data);
            };

            filament::Texture::PixelBufferDescriptor pbd(
                buffer->data(),
                size,
                bufferFormat,
                pixelDataType,
                1, // alignment
                0, // left
                0, // top
                0, // stride
                freeCallback,
                buffer);
    
            texture->setImage(*engine, level, std::move(pbd));
            return true;
        }

        EMSCRIPTEN_KEEPALIVE bool Texture_setImageWithDepth(
            TEngine *tEngine,
            TTexture *tTexture,
            uint32_t level,
            uint8_t *data,
            size_t size,
            uint32_t x_offset,
            uint32_t y_offset,
            uint32_t z_offset,
            uint32_t width,
            uint32_t height,
            uint32_t channels,
            uint32_t depth,
            uint32_t tBufferFormat,
            uint32_t tPixelDataType)
        {
            auto engine = reinterpret_cast<filament::Engine *>(tEngine);

            auto texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto bufferFormat = static_cast<PixelBufferDescriptor::PixelDataFormat>(tBufferFormat);
            auto pixelDataType = static_cast<PixelBufferDescriptor::PixelDataType>(tPixelDataType);
            TRACE("Setting texture image (depth %d, %dx%dx%d (%d bytes, z_offset %d)", depth, width, height, channels, size, z_offset);

            switch (bufferFormat)
            {
            case PixelBufferDescriptor::PixelDataFormat::RGB:
            case PixelBufferDescriptor::PixelDataFormat::RGBA:
            {
                size_t expectedSize = width * height * channels * sizeof(float);
                if (size != expectedSize)
                {
                    Log("Size mismatch (expected %lu, got %lu)", expectedSize, size);
                    return false;
                }
                break;
            }
            case PixelBufferDescriptor::PixelDataFormat::RGB_INTEGER:
            case PixelBufferDescriptor::PixelDataFormat::RGBA_INTEGER:
            {
                if (size != width * height * channels * sizeof(uint8_t))
                {
                    Log("Size mismatch");
                    // return false;
                }
                break;
            }
            default:
                Log("Unsupported buffer format type : %d", bufferFormat);
                return false;
            }

            // the texture upload is async, so we need to copy the buffer
            auto *buffer = new std::vector<uint8_t>(size);
            std::copy(data, data + size, buffer->begin());

            filament::Texture::PixelBufferDescriptor::Callback freeCallback = [](void *buf, size_t,
                                                                       void *data)
            {

                delete reinterpret_cast<std::vector<uint8_t> *>(data);
            };

            filament::Texture::PixelBufferDescriptor pbd(
                buffer->data(),
                size,
                bufferFormat,
                pixelDataType,
                1, // alignment
                0, // left
                0, // top
                0, // stride
                freeCallback,
                buffer);

            texture->setImage(
                *engine,
                level,
                x_offset,
                y_offset,
                z_offset,
                width,
                height,
                depth,
                std::move(pbd));

            return true;
        }

        EMSCRIPTEN_KEEPALIVE uint32_t Texture_getWidth(TTexture *tTexture, uint32_t level) {
                auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
                return texture->getWidth();
        }
        
        EMSCRIPTEN_KEEPALIVE uint32_t Texture_getHeight(TTexture *tTexture, uint32_t level) {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            return texture->getHeight();
        }

        EMSCRIPTEN_KEEPALIVE uint32_t Texture_getDepth(TTexture *tTexture, uint32_t level) {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            return texture->getDepth();
        }

        EMSCRIPTEN_KEEPALIVE void Texture_generateMipMaps(TTexture *tTexture, TEngine *tEngine) {
            auto *texture = reinterpret_cast<filament::Texture *>(tTexture);
            auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
            texture->generateMipmaps(*engine);
        }

        EMSCRIPTEN_KEEPALIVE TLinearImage *Image_createEmpty(uint32_t width, uint32_t height, uint32_t channel)
        {
            auto *image = new ::image::LinearImage(width, height, channel);
            return reinterpret_cast<TLinearImage *>(image);
        }

        EMSCRIPTEN_KEEPALIVE TTextureSampler *TextureSampler_create()
        {
            auto *sampler = new filament::TextureSampler();
            return reinterpret_cast<TTextureSampler *>(sampler);
        }

        EMSCRIPTEN_KEEPALIVE TTextureSampler *TextureSampler_createWithFiltering(
            TSamplerMinFilter minFilter,
            TSamplerMagFilter magFilter,
            TSamplerWrapMode wrapS,
            TSamplerWrapMode wrapT,
            TSamplerWrapMode wrapR)
        {

            filament::TextureSampler::MinFilter min = static_cast<filament::TextureSampler::MinFilter>(minFilter);
            filament::TextureSampler::MagFilter mag = static_cast<filament::TextureSampler::MagFilter>(magFilter);
            filament::TextureSampler::WrapMode s = static_cast<filament::TextureSampler::WrapMode>(wrapS);
            filament::TextureSampler::WrapMode t = static_cast<filament::TextureSampler::WrapMode>(wrapT);
            filament::TextureSampler::WrapMode r = static_cast<filament::TextureSampler::WrapMode>(wrapR);

            auto *sampler = new filament::TextureSampler(min, mag, s, t, r);
            return reinterpret_cast<TTextureSampler *>(sampler);
        }

        EMSCRIPTEN_KEEPALIVE TTextureSampler *TextureSampler_createWithComparison(
            TSamplerCompareMode compareMode,
            TSamplerCompareFunc compareFunc)
        {

            if(compareMode == COMPARE_MODE_NONE) {
                TRACE("COMPARE MODE NONE");
            } else if(compareMode == COMPARE_MODE_COMPARE_TO_TEXTURE) { 
                TRACE("COMPARE MODE COMPARE TO TEXTURE");
            } else { 
                TRACE("UNKNWON COMPARE MODE");
            }


            filament::TextureSampler::CompareMode mode = static_cast<filament::TextureSampler::CompareMode>(static_cast<int>(compareMode));
            filament::TextureSampler::CompareFunc func = static_cast<filament::TextureSampler::CompareFunc>(static_cast<int>(compareFunc));

            TRACE("Creating texture sampler with compare mode %d and compare func %d");

            auto *sampler = new filament::TextureSampler(mode, func);
            return reinterpret_cast<TTextureSampler *>(sampler);
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilter(
            TTextureSampler *sampler,
            TSamplerMinFilter filter)
        {
            auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
            textureSampler->setMinFilter(static_cast<filament::TextureSampler::MinFilter>(filter));
            TRACE("Set TextureSampler min filter to %d", filter);
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setAnisotropy(
            TTextureSampler *sampler,
            double anisotropy)
        {
            auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
            textureSampler->setAnisotropy(static_cast<float>(anisotropy));
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMagFilter(
            TTextureSampler *sampler,
            TSamplerMagFilter filter)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setMagFilter(static_cast<filament::TextureSampler::MagFilter>(filter));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeS(
            TTextureSampler *sampler,
            TSamplerWrapMode mode)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setWrapModeS(static_cast<filament::TextureSampler::WrapMode>(mode));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeT(
            TTextureSampler *sampler,
            TSamplerWrapMode mode)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setWrapModeT(static_cast<filament::TextureSampler::WrapMode>(mode));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setWrapModeR(
            TTextureSampler *sampler,
            TSamplerWrapMode mode)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setWrapModeR(static_cast<filament::TextureSampler::WrapMode>(mode));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setCompareMode(
            TTextureSampler *sampler,
            TSamplerCompareMode mode,
            TSamplerCompareFunc func)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setCompareMode(
                    static_cast<filament::TextureSampler::CompareMode>(mode),
                    static_cast<filament::TextureSampler::CompareFunc>(func));
            }
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_destroy(TTextureSampler *sampler)
        {
            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                delete textureSampler;
            }
        }

        EMSCRIPTEN_KEEPALIVE TTexture *RenderTarget_getColorTexture(TRenderTarget *tRenderTarget)
        {
            auto renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
            auto texture = renderTarget->getTexture(filament::RenderTarget::AttachmentPoint::COLOR0);
            return reinterpret_cast<TTexture *>(texture);
        }

        EMSCRIPTEN_KEEPALIVE TTexture *RenderTarget_getDepthTexture(TRenderTarget *tRenderTarget)
        {
            auto renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
            auto texture = renderTarget->getTexture(filament::RenderTarget::AttachmentPoint::DEPTH);
            return reinterpret_cast<TTexture *>(texture);
        }

#ifdef __cplusplus
    }
}
#endif
