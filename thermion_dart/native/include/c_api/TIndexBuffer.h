#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

    // ============================================================================
    // IndexBufferBuilder
    // ============================================================================

    // Create an index buffer builder
    EMSCRIPTEN_KEEPALIVE TIndexBufferBuilder* IndexBufferBuilder_create();

    // Configure the builder
    EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_indexCount(TIndexBufferBuilder* builder, uint32_t count);
    EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_bufferType(TIndexBufferBuilder* builder, TIndexType indexType);

    // Build and destroy
    EMSCRIPTEN_KEEPALIVE TIndexBuffer* IndexBufferBuilder_build(TIndexBufferBuilder* builder, TEngine* engine);
    EMSCRIPTEN_KEEPALIVE void IndexBufferBuilder_destroy(TIndexBufferBuilder* builder);

    // ============================================================================
    // IndexBuffer Operations
    // ============================================================================

    // Get index count
    EMSCRIPTEN_KEEPALIVE size_t IndexBuffer_getIndexCount(TIndexBuffer* buffer);

    // Set buffer data
    EMSCRIPTEN_KEEPALIVE void IndexBuffer_setBuffer(
        TEngine* engine,
        TIndexBuffer* buffer,
        void* data,
        size_t sizeInBytes,
        uint32_t byteOffset
    );

    // Destroy
    EMSCRIPTEN_KEEPALIVE void IndexBuffer_destroy(TEngine* engine, TIndexBuffer* buffer);

#ifdef __cplusplus
}
#endif
