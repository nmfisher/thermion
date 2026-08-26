#include <filament/Engine.h>
#include <filament/BufferObject.h>
#include <filament/VertexBuffer.h>

#include <mutex>
#include <unordered_map>

#include "Log.hpp"
#include "c_api/TVertexBuffer.h"
#include "scene/VertexBufferMetadata.hpp"

namespace
{
    struct VertexBufferBuilderState
    {
        filament::VertexBuffer::Builder builder;
        TVertexBufferStorageMode storageMode = VERTEX_BUFFER_STORAGE_MODE_DIRECT;
    };

    std::mutex gVertexBufferMetadataMutex;
    std::unordered_map<const filament::VertexBuffer *, TVertexBufferStorageMode> gVertexBufferStorageModes;
}

namespace thermion
{
    void registerVertexBufferStorageMode(
        filament::VertexBuffer *buffer,
        TVertexBufferStorageMode storageMode)
    {
        if (!buffer)
            return;
        std::lock_guard<std::mutex> lock(gVertexBufferMetadataMutex);
        gVertexBufferStorageModes[buffer] = storageMode;
    }

    void unregisterVertexBufferStorageMode(filament::VertexBuffer *buffer)
    {
        if (!buffer)
            return;
        std::lock_guard<std::mutex> lock(gVertexBufferMetadataMutex);
        gVertexBufferStorageModes.erase(buffer);
    }

    TVertexBufferStorageMode getVertexBufferStorageMode(
        const filament::VertexBuffer *buffer)
    {
        std::lock_guard<std::mutex> lock(gVertexBufferMetadataMutex);
        const auto entry = gVertexBufferStorageModes.find(buffer);
        return entry == gVertexBufferStorageModes.end()
                   ? VERTEX_BUFFER_STORAGE_MODE_UNKNOWN
                   : entry->second;
    }

    extern "C"
    {
        using namespace filament;

        // ============================================================================
        // VertexBufferBuilder
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE TVertexBufferBuilder* VertexBufferBuilder_create() {
            auto* builder = new VertexBufferBuilderState();
            return reinterpret_cast<TVertexBufferBuilder*>(builder);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_bufferCount(TVertexBufferBuilder* tBuilder, uint8_t count) {
            auto* builder = reinterpret_cast<VertexBufferBuilderState*>(tBuilder);
            builder->builder.bufferCount(count);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_vertexCount(TVertexBufferBuilder* tBuilder, uint32_t count) {
            auto* builder = reinterpret_cast<VertexBufferBuilderState*>(tBuilder);
            builder->builder.vertexCount(count);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_enableBufferObjects(TVertexBufferBuilder* tBuilder, bool enabled) {
            auto* builder = reinterpret_cast<VertexBufferBuilderState*>(tBuilder);
            builder->builder.enableBufferObjects(enabled);
            builder->storageMode = enabled
                                       ? VERTEX_BUFFER_STORAGE_MODE_BUFFER_OBJECTS
                                       : VERTEX_BUFFER_STORAGE_MODE_DIRECT;
        }

        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_attribute(
            TVertexBufferBuilder* tBuilder,
            TVertexAttribute attribute,
            uint8_t bufferIndex,
            TVertexAttributeType attributeType,
            uint32_t byteOffset,
            uint8_t byteStride
        ) {
            auto* builder = reinterpret_cast<VertexBufferBuilderState*>(tBuilder);

            // Map TVertexAttribute to filament::VertexAttribute explicitly
            VertexAttribute vertexAttribute;
            switch (attribute) {
                case TVERTEX_ATTRIBUTE_POSITION:     vertexAttribute = VertexAttribute::POSITION;     break;
                case TVERTEX_ATTRIBUTE_TANGENTS:     vertexAttribute = VertexAttribute::TANGENTS;     break;
                case TVERTEX_ATTRIBUTE_COLOR:        vertexAttribute = VertexAttribute::COLOR;        break;
                case TVERTEX_ATTRIBUTE_UV0:          vertexAttribute = VertexAttribute::UV0;          break;
                case TVERTEX_ATTRIBUTE_UV1:          vertexAttribute = VertexAttribute::UV1;          break;
                case TVERTEX_ATTRIBUTE_BONE_INDICES: vertexAttribute = VertexAttribute::BONE_INDICES; break;
                case TVERTEX_ATTRIBUTE_BONE_WEIGHTS: vertexAttribute = VertexAttribute::BONE_WEIGHTS; break;
                case TVERTEX_ATTRIBUTE_CUSTOM0:      vertexAttribute = VertexAttribute::CUSTOM0;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM1:      vertexAttribute = VertexAttribute::CUSTOM1;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM2:      vertexAttribute = VertexAttribute::CUSTOM2;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM3:      vertexAttribute = VertexAttribute::CUSTOM3;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM4:      vertexAttribute = VertexAttribute::CUSTOM4;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM5:      vertexAttribute = VertexAttribute::CUSTOM5;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM6:      vertexAttribute = VertexAttribute::CUSTOM6;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM7:      vertexAttribute = VertexAttribute::CUSTOM7;      break;
                default:
                    Log("Error: Invalid TVertexAttribute value");
                    return;
            }

            // Map TVertexAttributeType to backend::ElementType explicitly
            // This ensures we're not dependent on the enum values matching exactly
            VertexBuffer::AttributeType elementType;
            switch (attributeType) {
                case TVERTEXATTRIBUTE_TYPE_BYTE:     elementType = VertexBuffer::AttributeType::BYTE;     break;
                case TVERTEXATTRIBUTE_TYPE_BYTE2:    elementType = VertexBuffer::AttributeType::BYTE2;    break;
                case TVERTEXATTRIBUTE_TYPE_BYTE3:    elementType = VertexBuffer::AttributeType::BYTE3;    break;
                case TVERTEXATTRIBUTE_TYPE_BYTE4:    elementType = VertexBuffer::AttributeType::BYTE4;    break;
                case TVERTEXATTRIBUTE_TYPE_UBYTE:    elementType = VertexBuffer::AttributeType::UBYTE;    break;
                case TVERTEXATTRIBUTE_TYPE_UBYTE2:   elementType = VertexBuffer::AttributeType::UBYTE2;   break;
                case TVERTEXATTRIBUTE_TYPE_UBYTE3:   elementType = VertexBuffer::AttributeType::UBYTE3;   break;
                case TVERTEXATTRIBUTE_TYPE_UBYTE4:   elementType = VertexBuffer::AttributeType::UBYTE4;   break;
                case TVERTEXATTRIBUTE_TYPE_SHORT:    elementType = VertexBuffer::AttributeType::SHORT;    break;
                case TVERTEXATTRIBUTE_TYPE_SHORT2:   elementType = VertexBuffer::AttributeType::SHORT2;   break;
                case TVERTEXATTRIBUTE_TYPE_SHORT3:   elementType = VertexBuffer::AttributeType::SHORT3;   break;
                case TVERTEXATTRIBUTE_TYPE_SHORT4:   elementType = VertexBuffer::AttributeType::SHORT4;   break;
                case TVERTEXATTRIBUTE_TYPE_USHORT:   elementType = VertexBuffer::AttributeType::USHORT;   break;
                case TVERTEXATTRIBUTE_TYPE_USHORT2:  elementType = VertexBuffer::AttributeType::USHORT2;  break;
                case TVERTEXATTRIBUTE_TYPE_USHORT3:  elementType = VertexBuffer::AttributeType::USHORT3;  break;
                case TVERTEXATTRIBUTE_TYPE_USHORT4:  elementType = VertexBuffer::AttributeType::USHORT4;  break;
                case TVERTEXATTRIBUTE_TYPE_INT:      elementType = VertexBuffer::AttributeType::INT;      break;
                case TVERTEXATTRIBUTE_TYPE_UINT:     elementType = VertexBuffer::AttributeType::UINT;     break;
                case TVERTEXATTRIBUTE_TYPE_FLOAT:    elementType = VertexBuffer::AttributeType::FLOAT;    break;
                case TVERTEXATTRIBUTE_TYPE_FLOAT2:   elementType = VertexBuffer::AttributeType::FLOAT2;   break;
                case TVERTEXATTRIBUTE_TYPE_FLOAT3:   elementType = VertexBuffer::AttributeType::FLOAT3;   break;
                case TVERTEXATTRIBUTE_TYPE_FLOAT4:   elementType = VertexBuffer::AttributeType::FLOAT4;   break;
                case TVERTEXATTRIBUTE_TYPE_HALF:     elementType = VertexBuffer::AttributeType::HALF;     break;
                case TVERTEXATTRIBUTE_TYPE_HALF2:    elementType = VertexBuffer::AttributeType::HALF2;    break;
                case TVERTEXATTRIBUTE_TYPE_HALF3:    elementType = VertexBuffer::AttributeType::HALF3;    break;
                case TVERTEXATTRIBUTE_TYPE_HALF4:    elementType = VertexBuffer::AttributeType::HALF4;    break;
                default:
                    Log("Error: Invalid TVertexAttributeType value");
                    return;
            }

            builder->builder.attribute(vertexAttribute, bufferIndex, elementType, byteOffset, byteStride);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_normalized(TVertexBufferBuilder* tBuilder, TVertexAttribute attribute, bool normalize) {
            auto* builder = reinterpret_cast<VertexBufferBuilderState*>(tBuilder);

            // Map TVertexAttribute to filament::VertexAttribute explicitly
            VertexAttribute vertexAttribute;
            switch (attribute) {
                case TVERTEX_ATTRIBUTE_POSITION:     vertexAttribute = VertexAttribute::POSITION;     break;
                case TVERTEX_ATTRIBUTE_TANGENTS:     vertexAttribute = VertexAttribute::TANGENTS;     break;
                case TVERTEX_ATTRIBUTE_COLOR:        vertexAttribute = VertexAttribute::COLOR;        break;
                case TVERTEX_ATTRIBUTE_UV0:          vertexAttribute = VertexAttribute::UV0;          break;
                case TVERTEX_ATTRIBUTE_UV1:          vertexAttribute = VertexAttribute::UV1;          break;
                case TVERTEX_ATTRIBUTE_BONE_INDICES: vertexAttribute = VertexAttribute::BONE_INDICES; break;
                case TVERTEX_ATTRIBUTE_BONE_WEIGHTS: vertexAttribute = VertexAttribute::BONE_WEIGHTS; break;
                case TVERTEX_ATTRIBUTE_CUSTOM0:      vertexAttribute = VertexAttribute::CUSTOM0;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM1:      vertexAttribute = VertexAttribute::CUSTOM1;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM2:      vertexAttribute = VertexAttribute::CUSTOM2;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM3:      vertexAttribute = VertexAttribute::CUSTOM3;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM4:      vertexAttribute = VertexAttribute::CUSTOM4;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM5:      vertexAttribute = VertexAttribute::CUSTOM5;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM6:      vertexAttribute = VertexAttribute::CUSTOM6;      break;
                case TVERTEX_ATTRIBUTE_CUSTOM7:      vertexAttribute = VertexAttribute::CUSTOM7;      break;
                default:
                    Log("Error: Invalid TVertexAttribute value");
                    return;
            }

            builder->builder.normalized(vertexAttribute, normalize);
        }

        EMSCRIPTEN_KEEPALIVE TVertexBuffer* VertexBufferBuilder_build(TVertexBufferBuilder* tBuilder, TEngine* tEngine) {
            auto* builder = reinterpret_cast<VertexBufferBuilderState*>(tBuilder);
            auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto* vertexBuffer = builder->builder.build(*engine);
            registerVertexBufferStorageMode(vertexBuffer, builder->storageMode);
            return reinterpret_cast<TVertexBuffer*>(vertexBuffer);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_destroy(TVertexBufferBuilder* tBuilder) {
            auto* builder = reinterpret_cast<VertexBufferBuilderState*>(tBuilder);
            delete builder;
        }

        // ============================================================================
        // VertexBuffer Operations
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE size_t VertexBuffer_getVertexCount(TVertexBuffer* tBuffer) {
            auto* vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tBuffer);
            return vertexBuffer->getVertexCount();
        }

        EMSCRIPTEN_KEEPALIVE TVertexBufferStorageMode VertexBuffer_getStorageMode(TVertexBuffer* tBuffer) {
            auto* vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tBuffer);
            return getVertexBufferStorageMode(vertexBuffer);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferAt(
            TEngine* tEngine,
            TVertexBuffer* tBuffer,
            uint8_t bufferIndex,
            void* data,
            size_t sizeInBytes,
            uint32_t byteOffset
        ) {
            auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto* vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tBuffer);

            // Copy data to ensure it remains valid after the function returns
            void* dataCopy = malloc(sizeInBytes);
            if (!dataCopy) {
                Log("Error: Failed to allocate memory for vertex buffer data");
                return;
            }
            memcpy(dataCopy, data, sizeInBytes);

            // Create a BufferDescriptor with a callback to free the copied data
            VertexBuffer::BufferDescriptor bufferDescriptor(
                dataCopy,
                sizeInBytes,
                [](void* buffer, size_t size, void* user) {
                    free(buffer);
                }
            );

            vertexBuffer->setBufferAt(*engine, bufferIndex, std::move(bufferDescriptor), byteOffset);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferObjectAt(
            TEngine* tEngine,
            TVertexBuffer* tBuffer,
            uint8_t bufferIndex,
            TBufferObject* tBufferObject
        ) {
            auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto* vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tBuffer);
            auto* bufferObject = reinterpret_cast<filament::BufferObject*>(tBufferObject);
            vertexBuffer->setBufferObjectAt(*engine, bufferIndex, bufferObject);
        }

        EMSCRIPTEN_KEEPALIVE void VertexBuffer_destroy(TEngine* tEngine, TVertexBuffer* tBuffer) {
            auto* engine = reinterpret_cast<filament::Engine*>(tEngine);
            auto* vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tBuffer);
            unregisterVertexBufferStorageMode(vertexBuffer);
            engine->destroy(vertexBuffer);
        }

    } // extern "C"
} // namespace thermion
