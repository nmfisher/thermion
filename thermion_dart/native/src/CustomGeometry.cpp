#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>
#include <filament/RenderableManager.h>
#include <filament/Viewport.h>
#include <filament/Frustum.h>

#include "CustomGeometry.hpp"

namespace thermion_filament {

using namespace filament;

CustomGeometry::CustomGeometry(
    float* vertices, 
    uint32_t numVertices, 
    uint16_t* indices, 
    uint32_t numIndices, 
    RenderableManager::PrimitiveType primitiveType, 
    Engine* engine)
    : numVertices(numVertices), numIndices(numIndices), _engine(engine) {
    this->primitiveType = primitiveType;
    this->vertices = new float[numVertices];
    std::memcpy(this->vertices, vertices, numVertices * sizeof(float));

    this->indices = new uint16_t[numIndices];
    std::memcpy(this->indices, indices, numIndices * sizeof(uint16_t));  

    computeBoundingBox();
}

IndexBuffer* CustomGeometry::indexBuffer() { 
    IndexBuffer::BufferDescriptor::Callback indexCallback = [](void *buf, size_t,
                                                               void *data)
    {
    //   free((void *)buf);
    };

    auto indexBuffer = IndexBuffer::Builder()
        .indexCount(numIndices)
        .bufferType(IndexBuffer::IndexType::USHORT)
        .build(*_engine);

    indexBuffer->setBuffer(*_engine, IndexBuffer::BufferDescriptor(
        this->indices, indexBuffer->getIndexCount() * sizeof(uint16_t), indexCallback));
    return indexBuffer;
}

VertexBuffer* CustomGeometry::vertexBuffer() { 
    VertexBuffer::BufferDescriptor::Callback vertexCallback = [](void *buf, size_t,
                                                                 void *data)
    {
    //   free((void *)buf);
    };

    auto vertexBuffer = VertexBuffer::Builder()
        .vertexCount(numVertices)
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
        .build(*_engine);

    vertexBuffer->setBufferAt(*_engine, 0, VertexBuffer::BufferDescriptor(
        this->vertices, vertexBuffer->getVertexCount() * sizeof(math::float3), vertexCallback));
    return vertexBuffer;
}

CustomGeometry::~CustomGeometry() {
    delete[] vertices;
    delete[] indices;
}

void CustomGeometry::computeBoundingBox() {
    float minX = FLT_MAX, minY = FLT_MAX, minZ = FLT_MAX;
    float maxX = -FLT_MAX, maxY = -FLT_MAX, maxZ = -FLT_MAX;

    for (uint32_t i = 0; i < numVertices; i += 3) {
        minX = std::min(vertices[i], minX);
        minY = std::min(vertices[i + 1], minY);
        minZ = std::min(vertices[i + 2], minZ);
        maxX = std::max(vertices[i], maxX);
        maxY = std::max(vertices[i + 1], maxY);
        maxZ = std::max(vertices[i + 2], maxZ);
    }

    boundingBox = Box{{minX, minY, minZ}, {maxX, maxY, maxZ}};
}

Box CustomGeometry::getBoundingBox() const {
    return boundingBox;
}

}