#include "c_api/TTexture.h"

#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/RenderTarget.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>
#include <filament/image/LinearImage.h>
#include <filament/imageio/ImageDecoder.h>
#include <filament/backend/DriverEnums.h>

#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament::backend;

#endif

        EMSCRIPTEN_KEEPALIVE TLinearImage *Image_decode(uint8_t *data, size_t length, const char *name = "image")
        {
            std::istringstream stream(std::string(reinterpret_cast<const char *>(data), length));

            auto *linearImage = new image::LinearImage(::image::ImageDecoder::decode(stream, name, ::image::ImageDecoder::ColorSpace::SRGB));

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

        EMSCRIPTEN_KEEPALIVE bool Texture_loadImage(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage, TPixelDataFormat tBufferFormat, TPixelDataType tPixelDataType)
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

            texture->setImage(*engine, 0, std::move(buffer));
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
                if (size != width * height * channels * sizeof(float))
                {
                    Log("Size mismatch");
                    return false;
                }
                break;
            case PixelBufferDescriptor::PixelDataFormat::RGB_INTEGER:
            case PixelBufferDescriptor::PixelDataFormat::RGBA_INTEGER:
                if (size != width * height * channels * sizeof(uint8_t))
                {
                    Log("Size mismatch");
                    // return false;
                }
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
                if (size != width * height * channels * sizeof(float))
                {
                    Log("Size mismatch");
                    return false;
                }
                break;
            case PixelBufferDescriptor::PixelDataFormat::RGB_INTEGER:
            case PixelBufferDescriptor::PixelDataFormat::RGBA_INTEGER:
                if (size != width * height * channels * sizeof(uint8_t))
                {
                    Log("Size mismatch");
                    // return false;
                }
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

            filament::TextureSampler::CompareMode mode = static_cast<filament::TextureSampler::CompareMode>(compareMode);
            filament::TextureSampler::CompareFunc func = static_cast<filament::TextureSampler::CompareFunc>(compareFunc);

            auto *sampler = new filament::TextureSampler(mode, func);
            return reinterpret_cast<TTextureSampler *>(sampler);
        }

        EMSCRIPTEN_KEEPALIVE void TextureSampler_setMinFilter(
            TTextureSampler *sampler,
            TSamplerMinFilter filter)
        {

            if (sampler)
            {
                auto *textureSampler = reinterpret_cast<filament::TextureSampler *>(sampler);
                textureSampler->setMinFilter(static_cast<filament::TextureSampler::MinFilter>(filter));
            }
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

#ifdef __cplusplus
    }
}
#endif
