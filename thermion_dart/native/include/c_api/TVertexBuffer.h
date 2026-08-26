#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

    // ============================================================================
    // VertexBufferBuilder
    // ============================================================================

    // Create a vertex buffer builder
    EMSCRIPTEN_KEEPALIVE TVertexBufferBuilder* VertexBufferBuilder_create();

    // Configure the builder
    EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_bufferCount(TVertexBufferBuilder* builder, uint8_t count);
    EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_vertexCount(TVertexBufferBuilder* builder, uint32_t count);
    EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_enableBufferObjects(TVertexBufferBuilder* builder, bool enabled);
    EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_attribute(
        TVertexBufferBuilder* builder,
        TVertexAttribute attribute,
        uint8_t bufferIndex,
        TVertexAttributeType attributeType,
        uint32_t byteOffset,
        uint8_t byteStride
    );
    EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_normalized(TVertexBufferBuilder* builder, TVertexAttribute attribute, bool normalize);

    // Build and destroy
    EMSCRIPTEN_KEEPALIVE TVertexBuffer* VertexBufferBuilder_build(TVertexBufferBuilder* builder, TEngine* engine);
    EMSCRIPTEN_KEEPALIVE void VertexBufferBuilder_destroy(TVertexBufferBuilder* builder);

    // ============================================================================
    // VertexBuffer Operations
    // ============================================================================

    // Get vertex count
    EMSCRIPTEN_KEEPALIVE size_t VertexBuffer_getVertexCount(TVertexBuffer* buffer);
    EMSCRIPTEN_KEEPALIVE TVertexBufferStorageMode VertexBuffer_getStorageMode(TVertexBuffer* buffer);

    // Set buffer data
    EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferAt(
        TEngine* engine,
        TVertexBuffer* buffer,
        uint8_t bufferIndex,
        void* data,
        size_t sizeInBytes,
        uint32_t byteOffset
    );
    EMSCRIPTEN_KEEPALIVE void VertexBuffer_setBufferObjectAt(
        TEngine* engine,
        TVertexBuffer* buffer,
        uint8_t bufferIndex,
        TBufferObject* bufferObject
    );

    // Destroy
    EMSCRIPTEN_KEEPALIVE void VertexBuffer_destroy(TEngine* engine, TVertexBuffer* buffer);

#ifdef __cplusplus
}
#endif
