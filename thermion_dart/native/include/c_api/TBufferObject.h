#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

    EMSCRIPTEN_KEEPALIVE TBufferObjectBuilder* BufferObjectBuilder_create();
    EMSCRIPTEN_KEEPALIVE void BufferObjectBuilder_size(TBufferObjectBuilder* builder, uint32_t sizeInBytes);
    EMSCRIPTEN_KEEPALIVE TBufferObject* BufferObjectBuilder_build(TBufferObjectBuilder* builder, TEngine* engine);
    EMSCRIPTEN_KEEPALIVE void BufferObjectBuilder_destroy(TBufferObjectBuilder* builder);

    EMSCRIPTEN_KEEPALIVE void BufferObject_setBuffer(
        TEngine* engine,
        TBufferObject* buffer,
        void* data,
        size_t sizeInBytes,
        uint32_t byteOffset);
    EMSCRIPTEN_KEEPALIVE void BufferObject_destroy(TEngine* engine, TBufferObject* buffer);

#ifdef __cplusplus
}
#endif
