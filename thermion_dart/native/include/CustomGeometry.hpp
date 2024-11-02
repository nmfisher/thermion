#pragma once

#include <stddef.h>

#include <filament/Engine.h>
#include <filament/Frustum.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>
#include <filament/RenderableManager.h>
#include <filament/Viewport.h>

#include <utils/Entity.h>
#include <utils/EntityManager.h>

namespace thermion
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

    utils::Entity createInstance(MaterialInstance *materialInstance);
    
private:
    Engine* _engine;

    VertexBuffer* vertexBuffer;
    IndexBuffer* indexBuffer;

    float* vertices = nullptr;
    float* normals = nullptr;
    float *uvs = nullptr;
    uint32_t numVertices = 0;
    uint16_t* indices = 0;
    uint32_t numIndices = 0;
    Box boundingBox;
    RenderableManager::PrimitiveType primitiveType;

    void computeBoundingBox();

};



}