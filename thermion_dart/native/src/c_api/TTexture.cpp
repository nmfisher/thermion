#include "c_api/TTexture.h"

#include <filament/Engine.h>
#include <filament/Material.h>
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

        EMSCRIPTEN_KEEPALIVE TLinearImage* Image_decode(uint8_t* data, size_t length, const char* name = "image") {
            std::istringstream stream(std::string(reinterpret_cast<const char *>(data), length));

            auto *linearImage = new image::LinearImage(::image::ImageDecoder::decode(stream, name, ::image::ImageDecoder::ColorSpace::SRGB));

            if (!linearImage->isValid())
            {
                Log("Failed to decode image.");
                return nullptr;
            }
            return reinterpret_cast<TLinearImage*>(linearImage);

        }

        EMSCRIPTEN_KEEPALIVE uint32_t Image_getWidth(TLinearImage* tLinearImage) {
            auto *linearImage = reinterpret_cast<::image::LinearImage*>(tLinearImage);
            return linearImage->getWidth();
        }
        EMSCRIPTEN_KEEPALIVE uint32_t Image_getHeight(TLinearImage* tLinearImage) {
            auto *linearImage = reinterpret_cast<::image::LinearImage*>(tLinearImage);
            return linearImage->getHeight();
        }
        EMSCRIPTEN_KEEPALIVE uint32_t Image_getChannels(TLinearImage* tLinearImage) {
            auto *linearImage = reinterpret_cast<::image::LinearImage*>(tLinearImage);
            return linearImage->getChannels();
        }

        EMSCRIPTEN_KEEPALIVE void Image_destroy(TLinearImage* tLinearImage) {
            auto *linearImage = reinterpret_cast<::image::LinearImage*>(tLinearImage);
            delete linearImage;
        }

        EMSCRIPTEN_KEEPALIVE bool Texture_loadImage(TEngine *tEngine, TTexture *tTexture, TLinearImage *tImage, TPixelDataFormat tBufferFormat, TPixelDataType tPixelDataType)
        {
            auto engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto image = reinterpret_cast<::image::LinearImage*>(tImage);
            auto texture = reinterpret_cast<filament::Texture*>(tTexture);
            auto bufferFormat = static_cast<PixelBufferDescriptor::PixelDataFormat>(static_cast<int>(tBufferFormat));
            auto pixelDataType = static_cast<PixelBufferDescriptor::PixelDataType>(static_cast<int>(tPixelDataType));
            
            uint32_t w = image->getWidth();
            uint32_t h = image->getHeight();
            uint32_t channels = image->getChannels();

            size_t size;
            switch(bufferFormat) {
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

            Log("Dimensions %d x %d, channels %d, size %d, buffer format %d and pixel data type %d", w, h,channels, size, bufferFormat, pixelDataType);


            filament::Texture::PixelBufferDescriptor buffer(
                image->getPixelRef(),
                size,
                bufferFormat,
                pixelDataType);

            texture->setImage(*engine, 0, std::move(buffer));
            return true;

        }

#ifdef __cplusplus
    }
}
#endif
