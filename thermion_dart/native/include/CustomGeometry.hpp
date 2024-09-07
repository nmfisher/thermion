#pragma once

#include <stddef.h>

#include <filament/Engine.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>
#include <filament/RenderableManager.h>
#include <filament/Viewport.h>
#include <filament/Frustum.h>

namespace thermion_filament
{

    using namespace filament;

// CustomGeometry.h
class CustomGeometry {
public:
    CustomGeometry(float* vertices, uint32_t numVertices, uint16_t* indices, uint32_t numIndices, RenderableManager::PrimitiveType primitiveType, Engine* engine);
    ~CustomGeometry();

    void computeBoundingBox();
    VertexBuffer* vertexBuffer();
    IndexBuffer* indexBuffer();
    Box getBoundingBox() const;

    float* vertices;
    uint32_t numVertices;
    uint16_t* indices;
    uint32_t numIndices;
    Box boundingBox;
    RenderableManager::PrimitiveType primitiveType;

private:
    Engine* _engine;
    bool _vertexBufferFreed = false;
    bool _indexBufferFreed = false;

};



}