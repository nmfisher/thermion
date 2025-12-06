#include <filament/Engine.h>
#include <filament/IndexBuffer.h>

#include "Log.hpp"
#include "c_api/TIndexBuffer.h"

namespace thermion
{
    extern "C"
    {
        using namespace filament;

        // ============================================================================
        // IndexBufferBuilder
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE TIndexBufferBuilder* IndexBufferBuilder_create() {
            auto* builder = new filament::IndexBuffer::Builder();
            return reinterpret_cast<TIndexBufferBuilder*>(builder);
        }

        EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_indexCount(TIndexBufferBuilder* tBuilder, uint32_t count) {
            auto* builder = reinterpret_cast<filament::IndexBuffer::Builder*>(tBuilder);
            builder->indexCount(count);
        }

        EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_bufferType(TIndexBufferBuilder* tBuilder, TIndexType indexType) {
            auto* builder = reinterpret_cast<filament::IndexBuffer::Builder*>(tBuilder);

            // Map TIndexType to filament::IndexBuffer::IndexType (which maps to backend::ElementType)
            IndexBuffer::IndexType type;
            switch (indexType) {
                case TINDEX_TYPE_USHORT:
                    type = IndexBuffer::IndexType::USHORT;  // ElementType::USHORT (12)
                    break;
                case TINDEX_TYPE_UINT:
                    type = IndexBuffer::IndexType::UINT;    // ElementType::UINT (17)
                    break;
                default:
                    Log("Error: Invalid TIndexType value");
                    return;
            }

            builder->bufferType(type);
        }

        EMSCRIPTEN_KEEPALIVE TIndexBuffer* IndexBufferBuilder_build(TIndexBufferBuilder* tBuilder, TEngine* tEngine) {
            auto* builder = reinterpret_cast<filament::IndexBuffer::Builder*>(tBuilder);
            auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto* indexBuffer = builder->build(*engine);
            return reinterpret_cast<TIndexBuffer*>(indexBuffer);
        }

        EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_destroy(TIndexBufferBuilder* tBuilder) {
            auto* builder = reinterpret_cast<filament::IndexBuffer::Builder*>(tBuilder);
            delete builder;
        }

        // ============================================================================
        // IndexBuffer Operations
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE size_t IndexBuffer_getIndexCount(TIndexBuffer* tBuffer) {
            auto* indexBuffer = reinterpret_cast<filament::IndexBuffer*>(tBuffer);
            return indexBuffer->getIndexCount();
        }

        EMSCRIPTEN_KEEPALIVE void IndexBuffer_setBuffer(
            TEngine* tEngine,
            TIndexBuffer* tBuffer,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset
        ) {
            auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto* indexBuffer = reinterpret_cast<filament::IndexBuffer*>(tBuffer);

            // Copy data to ensure it remains valid after the function returns
            void* dataCopy = malloc(sizeInBytes);
            if (!dataCopy) {
                Log("Error: Failed to allocate memory for index buffer data");
                return;
            }
            memcpy(dataCopy, data, sizeInBytes);

            // Create a BufferDescriptor with a callback to free the copied data
            IndexBuffer::BufferDescriptor bufferDescriptor(
                dataCopy,
                sizeInBytes,
                [](void* buffer, size_t size, void* user) {
                    free(buffer);
                }
            );

            indexBuffer->setBuffer(*engine, std::move(bufferDescriptor), byteOffset);
        }

        EMSCRIPTEN_KEEPALIVE void IndexBuffer_destroy(TEngine* tEngine, TIndexBuffer* tBuffer) {
            auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto* indexBuffer = reinterpret_cast<filament::IndexBuffer*>(tBuffer);
            engine->destroy(indexBuffer);
        }

    } // extern "C"
} // namespace thermion
