#pragma once

#include <filament/VertexBuffer.h>

#include "c_api/APIBoundaryTypes.h"

namespace thermion
{
    void registerVertexBufferStorageMode(
        filament::VertexBuffer *buffer,
        TVertexBufferStorageMode storageMode);

    void unregisterVertexBufferStorageMode(filament::VertexBuffer *buffer);

    TVertexBufferStorageMode getVertexBufferStorageMode(
        const filament::VertexBuffer *buffer);
}
