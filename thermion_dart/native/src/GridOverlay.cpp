#include "GridOverlay.hpp"

#include <filament/Engine.h>
#include <utils/Entity.h>
#include <utils/EntityManager.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>
#include <gltfio/math.h>

#include "material/grid.h"
#include "SceneManager.hpp"
#include "Log.hpp"

namespace thermion {

using namespace filament::gltfio;

GridOverlay::GridOverlay(Engine &engine) : _engine(engine)
{
    auto &entityManager = EntityManager::get();
    auto &transformManager = engine.getTransformManager();

    const int gridSize = 100;
    const float gridSpacing = 1.0f;
    int vertexCount = (gridSize + 1) * 4; // 2 axes, 2 vertices per line

    float* gridVertices = new float[vertexCount * 3];
    int index = 0;

    // Create grid lines
    for (int i = 0; i <= gridSize; ++i) {
        float pos = i * gridSpacing - (gridSize * gridSpacing / 2);

        // X-axis lines
        gridVertices[index++] = pos;
        gridVertices[index++] = 0;
        gridVertices[index++] = -(gridSize * gridSpacing / 2);

        gridVertices[index++] = pos;
        gridVertices[index++] = 0;
        gridVertices[index++] = (gridSize * gridSpacing / 2);

        // Z-axis lines
        gridVertices[index++] = -(gridSize * gridSpacing / 2);
        gridVertices[index++] = 0;
        gridVertices[index++] = pos;

        gridVertices[index++] = (gridSize * gridSpacing / 2);
        gridVertices[index++] = 0;
        gridVertices[index++] = pos;
    }

    auto vb = VertexBuffer::Builder()
        .vertexCount(vertexCount)
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
        .build(engine);

    vb->setBufferAt(engine, 0, VertexBuffer::BufferDescriptor(
        gridVertices, vertexCount * sizeof(filament::math::float3),
        [](void* buffer, size_t size, void*) { delete[] static_cast<float*>(buffer); }
    ));

    uint32_t* gridIndices = new uint32_t[vertexCount];
    for (uint32_t i = 0; i < vertexCount; ++i) {
        gridIndices[i] = i;
    }

    auto ib = IndexBuffer::Builder()
        .indexCount(vertexCount)
        .bufferType(IndexBuffer::IndexType::UINT)
        .build(engine);

    ib->setBuffer(engine, IndexBuffer::BufferDescriptor(
        gridIndices, vertexCount * sizeof(uint32_t),
        [](void* buffer, size_t size, void*) { delete[] static_cast<uint32_t*>(buffer); }
    ));

    _gridEntity = entityManager.create();
    _material = Material::Builder()
        .package(GRID_PACKAGE, GRID_GRID_SIZE)
        .build(engine);

    _materialInstance = _material->createInstance();

    _materialInstance->setParameter("maxDistance", 50.0f); // Adjust as needed
    _materialInstance->setParameter("color", math::float3{0.5f, 0.5f, 0.5f}); // Gray color for the grid


    RenderableManager::Builder(1)
        .boundingBox({{-gridSize * gridSpacing / 2, 0, -gridSize * gridSpacing / 2},
                      {gridSize * gridSpacing / 2, 0, gridSize * gridSpacing / 2}})
        .material(0, _materialInstance)
        .geometry(0, RenderableManager::PrimitiveType::LINES, vb, ib, 0, vertexCount)
        .priority(6)
        .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
        .culling(false)
        .receiveShadows(false)
        .castShadows(false)
        .build(engine, _gridEntity);
const float sphereRadius = 0.05f;
const int sphereSegments = 16;
const int sphereRings = 16;

vertexCount = (sphereRings + 1) * (sphereSegments + 1);
int indexCount = sphereRings * sphereSegments * 6;

math::float3* vertices = new math::float3[vertexCount];
uint32_t* indices = new uint32_t[indexCount];

int vertexIndex = 0;
// Generate sphere vertices
for (int ring = 0; ring <= sphereRings; ++ring) {
    float theta = ring * M_PI / sphereRings;
    float sinTheta = std::sin(theta);
    float cosTheta = std::cos(theta);

    for (int segment = 0; segment <= sphereSegments; ++segment) {
        float phi = segment * 2 * M_PI / sphereSegments;
        float sinPhi = std::sin(phi);
        float cosPhi = std::cos(phi);

        float x = cosPhi * sinTheta;
        float y = cosTheta;
        float z = sinPhi * sinTheta;

        vertices[vertexIndex++] = {x * sphereRadius, y * sphereRadius, z * sphereRadius};
    }
}

int indexIndex = 0;
// Generate sphere indices
for (int ring = 0; ring < sphereRings; ++ring) {
    for (int segment = 0; segment < sphereSegments; ++segment) {
        uint32_t current = ring * (sphereSegments + 1) + segment;
        uint32_t next = current + sphereSegments + 1;

        indices[indexIndex++] = current;
        indices[indexIndex++] = next;
        indices[indexIndex++] = current + 1;

        indices[indexIndex++] = current + 1;
        indices[indexIndex++] = next;
        indices[indexIndex++] = next + 1;
    }
}

auto sphereVb = VertexBuffer::Builder()
    .vertexCount(vertexCount)
    .bufferCount(1)
    .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
    .build(engine);

sphereVb->setBufferAt(engine, 0, VertexBuffer::BufferDescriptor(
    vertices, vertexCount * sizeof(math::float3),
    [](void* buffer, size_t size, void*) { delete[] static_cast<math::float3*>(buffer); }
));

auto sphereIb = IndexBuffer::Builder()
    .indexCount(indexCount)
    .bufferType(IndexBuffer::IndexType::UINT)
    .build(engine);

sphereIb->setBuffer(engine, IndexBuffer::BufferDescriptor(
    indices, indexCount * sizeof(uint32_t),
    [](void* buffer, size_t size, void*) { delete[] static_cast<uint32_t*>(buffer); }
));

_sphereEntity = entityManager.create();

RenderableManager::Builder(1)
    .boundingBox({{-sphereRadius, -sphereRadius, -sphereRadius},
                  {sphereRadius, sphereRadius, sphereRadius}})
    .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, sphereVb, sphereIb, 0, indexCount)
    .priority(6)
    .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
    .culling(false)
    .receiveShadows(false)
    .castShadows(false)
    .build(engine, _sphereEntity);

}
  

void GridOverlay::destroy()
{
    auto &rm = _engine.getRenderableManager();
    auto &tm = _engine.getTransformManager();
    rm.destroy(_sphereEntity);
    rm.destroy(_gridEntity);
    tm.destroy(_sphereEntity);
    tm.destroy(_gridEntity);
    _engine.destroy(_sphereEntity);
    _engine.destroy(_gridEntity);
}

} // namespace thermion