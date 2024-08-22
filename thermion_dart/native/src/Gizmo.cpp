#include "Gizmo.hpp"

#include <filament/Engine.h>
#include <utils/Entity.h>
#include <utils/EntityManager.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>

#include "material/gizmo.h"
#include "Log.hpp"

Gizmo::Gizmo(Engine* const engine)
{
    _material =
        Material::Builder()
            .package(GIZMO_GIZMO_DATA, GIZMO_GIZMO_SIZE)
            .build(*engine);

    // Line and arrow vertices
    float lineLength = 0.8f;
    float lineWidth = 0.005f;
    float arrowLength = 0.2f;
    float arrowWidth = 0.03f;
    float *vertices = new float[13 * 3]{
        // Line vertices (8 vertices)
        -lineWidth, -lineWidth, 0.0f,
        lineWidth, -lineWidth, 0.0f,
        lineWidth, lineWidth, 0.0f,
        -lineWidth, lineWidth, 0.0f,
        -lineWidth, -lineWidth, lineLength,
        lineWidth, -lineWidth, lineLength,
        lineWidth, lineWidth, lineLength,
        -lineWidth, lineWidth, lineLength,
        // Arrow vertices (5 vertices)
        0.0f, 0.0f, lineLength + arrowLength, // Tip of the arrow
        -arrowWidth, -arrowWidth, lineLength, // Base of the arrow
        arrowWidth, -arrowWidth, lineLength,
        arrowWidth, arrowWidth, lineLength,
        -arrowWidth, arrowWidth, lineLength};

    // Line and arrow indices
    uint16_t *indices = new uint16_t[54]{
        // Line indices (24 indices)
        0, 1, 5, 5, 4, 0,
        1, 2, 6, 6, 5, 1,
        2, 3, 7, 7, 6, 2,
        3, 0, 4, 4, 7, 3,
        // Arrow indices (30 indices)
        8, 9, 10,            // Front face
        8, 10, 11,           // Right face
        8, 11, 12,           // Back face
        8, 12, 9,            // Left face
        9, 12, 11, 11, 10, 9 // Base of the arrow
    };

    auto vb = VertexBuffer::Builder()
                  .vertexCount(13)
                  .bufferCount(1)
                  .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                  .build(*engine);

    vb->setBufferAt(*engine, 0, VertexBuffer::BufferDescriptor(vertices, 13 * sizeof(filament::math::float3), [](void *buffer, size_t size, void *)
                                                                { delete[] static_cast<float *>(buffer); }));

    auto ib = IndexBuffer::Builder().indexCount(54).bufferType(IndexBuffer::IndexType::USHORT).build(*engine);
    ib->setBuffer(*engine, IndexBuffer::BufferDescriptor(
                                indices, 54 * sizeof(uint16_t),
                                [](void *buffer, size_t size, void *)
                                { delete[] static_cast<uint16_t *>(buffer); }));

    auto &entityManager = EntityManager::get();

    // Create the three axes
    for (int i = 0; i < 3; i++)
    {
        _entities[i] = entityManager.create();
        _materialInstances[i] = _material->createInstance();

        math::float3 color;
        math::mat4f transform;

        switch (i)
        {
        case 0: // X-axis (Red)
            color = {1.0f, 0.0f, 0.0f};
            transform = math::mat4f::rotation(math::F_PI_2, math::float3{0, 1, 0});
            break;
        case 1: // Y-axis (Green)
            color = {0.0f, 1.0f, 0.0f};
            transform = math::mat4f::rotation(-math::F_PI_2, math::float3{1, 0, 0});
            break;
        case 2: // Z-axis (Blue)
            color = {0.0f, 0.0f, 1.0f};
            break;
        }

        _materialInstances[i]->setParameter("color", color);

        RenderableManager::Builder(1)
            .boundingBox({{0, 0, (lineLength + arrowLength) / 2}, {arrowWidth / 2, arrowWidth / 2, (lineLength + arrowLength) / 2}})
            .material(0, _materialInstances[i])
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb, ib, 0, 54)
            .culling(false)
            .receiveShadows(false)
            .castShadows(false)
            .build(*engine, _entities[i]);

        auto &transformManager = engine->getTransformManager();
        auto instance = transformManager.getInstance(_entities[i]);
        transformManager.setTransform(instance, transform);
    }

    // Create the black cube (center cube)
    _entities[3] = entityManager.create();
    _materialInstances[3] = _material->createInstance();
    _materialInstances[3]->setParameter("color", math::float3{0.0f, 0.0f, 0.0f}); // Black color

    // Create center cube vertices
    float centerCubeSize = 0.05f;
    float *centerCubeVertices = new float[8 * 3]{
        -centerCubeSize, -centerCubeSize, -centerCubeSize,
        centerCubeSize, -centerCubeSize, -centerCubeSize,
        centerCubeSize, centerCubeSize, -centerCubeSize,
        -centerCubeSize, centerCubeSize, -centerCubeSize,
        -centerCubeSize, -centerCubeSize, centerCubeSize,
        centerCubeSize, -centerCubeSize, centerCubeSize,
        centerCubeSize, centerCubeSize, centerCubeSize,
        -centerCubeSize, centerCubeSize, centerCubeSize};

    // Create center cube indices
    uint16_t *centerCubeIndices = new uint16_t[36]{
        0, 1, 2, 2, 3, 0,
        1, 5, 6, 6, 2, 1,
        5, 4, 7, 7, 6, 5,
        4, 0, 3, 3, 7, 4,
        3, 2, 6, 6, 7, 3,
        4, 5, 1, 1, 0, 4};

    auto centerCubeVb = VertexBuffer::Builder()
                            .vertexCount(8)
                            .bufferCount(1)
                            .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                            .build(*engine);

    centerCubeVb->setBufferAt(*engine, 0, VertexBuffer::BufferDescriptor(centerCubeVertices, 8 * sizeof(filament::math::float3), [](void *buffer, size_t size, void *)
                                                                          { delete[] static_cast<float *>(buffer); }));

    auto centerCubeIb = IndexBuffer::Builder().indexCount(36).bufferType(IndexBuffer::IndexType::USHORT).build(*engine);
    centerCubeIb->setBuffer(*engine, IndexBuffer::BufferDescriptor(
                                          centerCubeIndices, 36 * sizeof(uint16_t),
                                          [](void *buffer, size_t size, void *)
                                          { delete[] static_cast<uint16_t *>(buffer); }));

    RenderableManager::Builder(1)
        .boundingBox({{}, {centerCubeSize, centerCubeSize, centerCubeSize}})
        .material(0, _materialInstances[3])
        .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, centerCubeVb, centerCubeIb, 0, 36)
        .culling(false)
        .build(*engine, _entities[3]);

    auto &rm = engine->getRenderableManager();
    for (int i = 0; i < 4; i++)
    {
        rm.setPriority(rm.getInstance(_entities[i]), 7);
    }

}

void Gizmo::destroy(Engine *const engine) { 

    for (int i = 0; i < 4; i++)
    {
        engine->destroy(_entities[i]);
        engine->destroy(_materialInstances[i]);
    }

    engine->destroy(_material);
}

void Gizmo::updateTransform()
{
    Log("Updating gizmo transform");
    // // Get screen-space position of the entity
    // math::float4 entityScreenPos = _view->getViewProjectionMatrix() * entityWorldPosition;

    // // Convert to NDC space
    // entityScreenPos /= entityScreenPos.w;

    // // Convert to screen space
    // float screenX = (entityScreenPos.x * 0.5f + 0.5f) * viewportWidth;
    // float screenY = (entityScreenPos.y * 0.5f + 0.5f) * viewportHeight;

    // // Set gizmo position
    // gizmo->setPosition({screenX, screenY, 0});

    // // Scale gizmo based on viewport size
    // float scale = viewportHeight * 0.1f; // 10% of screen height, for example
    // gizmo->setScale({scale, scale, 1});
}