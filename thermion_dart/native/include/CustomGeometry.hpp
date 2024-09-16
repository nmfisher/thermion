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
    CustomGeometry(
        float* vertices, 
        uint32_t numVertices, 
        float* normals, 
        uint32_t numNormals, 
        float *uvs,
        uint32_t numUvs,
        uint16_t* indices, 
        uint32_t numIndices, 
        RenderableManager::PrimitiveType primitiveType, 
        Engine* engine);
    ~CustomGeometry();

    VertexBuffer* vertexBuffer() const;
    IndexBuffer* indexBuffer() const;
    Box getBoundingBox() const;

    float* vertices = nullptr;
    float* normals = nullptr;
    float *uvs = nullptr;
    uint32_t numVertices = 0;
    uint16_t* indices = 0;
    uint32_t numIndices = 0;
    Box boundingBox;
    RenderableManager::PrimitiveType primitiveType;

private:
    Engine* _engine;
    bool _vertexBufferFreed = false;
    bool _indexBufferFreed = false;

    void computeBoundingBox();

};



}