#include <cstdint>
#include <cstring>

#include <filament/BufferObject.h>
#include <filament/Engine.h>

#include "c_api/TBufferObject.h"

namespace thermion
{
    extern "C"
    {
        using namespace filament;

        EMSCRIPTEN_KEEPALIVE TBufferObjectBuilder* BufferObjectBuilder_create()
        {
            return reinterpret_cast<TBufferObjectBuilder*>(new BufferObject::Builder());
        }

        EMSCRIPTEN_KEEPALIVE void BufferObjectBuilder_size(
            TBufferObjectBuilder* tBuilder,
            uint32_t sizeInBytes)
        {
            reinterpret_cast<BufferObject::Builder*>(tBuilder)->size(sizeInBytes);
        }

        EMSCRIPTEN_KEEPALIVE TBufferObject* BufferObjectBuilder_build(
            TBufferObjectBuilder* tBuilder,
            TEngine* tEngine)
        {
            auto* builder = reinterpret_cast<BufferObject::Builder*>(tBuilder);
            auto* engine = reinterpret_cast<Engine*>(tEngine);
            return reinterpret_cast<TBufferObject*>(builder->build(*engine));
        }

        EMSCRIPTEN_KEEPALIVE void BufferObjectBuilder_destroy(TBufferObjectBuilder* tBuilder)
        {
            delete reinterpret_cast<BufferObject::Builder*>(tBuilder);
        }

        EMSCRIPTEN_KEEPALIVE void BufferObject_setBuffer(
            TEngine* tEngine,
            TBufferObject* tBuffer,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset)
        {
            auto* copy = new uint8_t[sizeInBytes];
            std::memcpy(copy, data, sizeInBytes);
            auto* engine = reinterpret_cast<Engine*>(tEngine);
            auto* buffer = reinterpret_cast<BufferObject*>(tBuffer);
            buffer->setBuffer(
                *engine,
                BufferObject::BufferDescriptor(
                    copy,
                    sizeInBytes,
                    [](void* data, size_t, void*) { delete[] static_cast<uint8_t*>(data); }),
                byteOffset);
        }

        EMSCRIPTEN_KEEPALIVE void BufferObject_destroy(TEngine* tEngine, TBufferObject* tBuffer)
        {
            reinterpret_cast<Engine*>(tEngine)->destroy(
                reinterpret_cast<BufferObject*>(tBuffer));
        }
    }
}
