#include "Gizmo.hpp"

#include <filament/Engine.h>
#include <utils/Entity.h>
#include <utils/EntityManager.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>
#include <gltfio/math.h>
#include "SceneManager.hpp"
#include "material/gizmo.h"
#include "Log.hpp"

namespace thermion {

using namespace filament::gltfio;

Gizmo::Gizmo(Engine *engine, View *view, Scene* scene) : _engine(engine), _view(view), _scene(scene)
{
        
    auto &entityManager = EntityManager::get();

    auto &transformManager = _engine->getTransformManager();

    _material =
        Material::Builder()
            .package(GIZMO_GIZMO_DATA, GIZMO_GIZMO_SIZE)
            .build(*_engine);

    // First, create the black cube at the center
    // The axes widgets will be parented to this entity 
    _entities[3] = entityManager.create();

    _materialInstances[3] = _material->createInstance();
    _materialInstances[3]->setParameter("color", math::float4{0.0f, 0.0f, 0.0f, 1.0f}); // Black color

    // Create center cube vertices
    float centerCubeSize = 0.01f;
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
        .boundingBox({{-centerCubeSize, -centerCubeSize, -centerCubeSize}, 
                      {centerCubeSize, centerCubeSize, centerCubeSize}})
        .material(0, _materialInstances[3])
        .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
        .priority(7)
        .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, centerCubeVb, centerCubeIb, 0, 36)
        .culling(false)
        .build(*engine, _entities[3]);

    auto cubeTransformInstance = transformManager.getInstance(_entities[3]);
    math::mat4f cubeTransform;
    transformManager.setTransform(cubeTransformInstance, cubeTransform);

    // Line and arrow vertices
    float lineLength = 0.6f;
    float lineWidth = 0.004f;
    float arrowLength = 0.06f;
    float arrowWidth = 0.02f;
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

    // Create the three axes
    for (int i = 0; i < 3; i++)
    {
        _entities[i] = entityManager.create();
        _materialInstances[i] = _material->createInstance();

        auto baseColor = inactiveColors[i];

        math::mat4f transform;

        switch (i)
        {
        case Axis::X: 
            // _materialInstances[i]->setParameter("axisDirection", math::float3 { 1.0f, 0.0f, 0.0f});
            transform = math::mat4f::rotation(math::F_PI_2, math::float3{0, 1, 0});
            break;
        case 1: 
            // _materialInstances[i]->setParameter("axisDirection", math::float3 { 0.0f, 1.0f, 0.0f});
            transform = math::mat4f::rotation(-math::F_PI_2, math::float3{1, 0, 0});
            break;
        case 2: 
            // _materialInstances[i]->setParameter("axisDirection", math::float3 { 0.0f, 0.0f, 1.0f});
            break;
        }

        _materialInstances[i]->setParameter("color", baseColor);

        RenderableManager::Builder(1)
             .boundingBox({{-arrowWidth, -arrowWidth, 0}, 
                          {arrowWidth, arrowWidth, lineLength + arrowLength}})
            .material(0, _materialInstances[i])
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb, ib, 0, 54)
            .priority(6)
            .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
            .culling(false)
            .receiveShadows(false)
            .castShadows(false)
            .build(*engine, _entities[i]);


        auto instance = transformManager.getInstance(_entities[i]);
        transformManager.setTransform(instance, transform);

        // parent the axis to the center cube
        transformManager.setParent(instance, cubeTransformInstance);

    }

    createTransparentRectangles();
}

Gizmo::~Gizmo() {
    _scene->removeEntities(_entities, 7);
    
    for(int i = 0; i < 7; i++) {
        _engine->destroy(_entities[i]);    
    }
    
    for(int i = 0; i < 7; i++) {
        _engine->destroy(_materialInstances[i]);    
    }
    
    _engine->destroy(_material);
    
}

void Gizmo::createTransparentRectangles()
{
    auto &entityManager = EntityManager::get();
    auto &transformManager = _engine->getTransformManager();

    float volumeWidth = 0.2f;
    float volumeLength = 1.2f;
    float volumeDepth = 0.2f;

    float *volumeVertices = new float[8 * 3]{
        -volumeWidth / 2, -volumeDepth / 2, 0,
        volumeWidth / 2, -volumeDepth / 2, 0,
        volumeWidth / 2, -volumeDepth / 2, volumeLength,
        -volumeWidth / 2, -volumeDepth / 2, volumeLength,
        -volumeWidth / 2, volumeDepth / 2, 0,
        volumeWidth / 2, volumeDepth / 2, 0,
        volumeWidth / 2, volumeDepth / 2, volumeLength,
        -volumeWidth / 2, volumeDepth / 2, volumeLength
    };

    uint16_t *volumeIndices = new uint16_t[36]{
        0, 1, 2, 2, 3, 0,  // Bottom face
        4, 5, 6, 6, 7, 4,  // Top face
        0, 4, 7, 7, 3, 0,  // Left face
        1, 5, 6, 6, 2, 1,  // Right face
        0, 1, 5, 5, 4, 0,  // Front face
        3, 2, 6, 6, 7, 3   // Back face
    };

    auto volumeVb = VertexBuffer::Builder()
        .vertexCount(8)
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
        .build(*_engine);

    volumeVb->setBufferAt(*_engine, 0, VertexBuffer::BufferDescriptor(
        volumeVertices, 8 * sizeof(filament::math::float3),
        [](void *buffer, size_t size, void *) { delete[] static_cast<float *>(buffer); }
    ));

    auto volumeIb = IndexBuffer::Builder()
        .indexCount(36)
        .bufferType(IndexBuffer::IndexType::USHORT)
        .build(*_engine);

    volumeIb->setBuffer(*_engine, IndexBuffer::BufferDescriptor(
        volumeIndices, 36 * sizeof(uint16_t),
        [](void *buffer, size_t size, void *) { delete[] static_cast<uint16_t *>(buffer); }
    ));

    for (int i = 4; i < 7; i++)
    {
        _entities[i] = entityManager.create();
        _materialInstances[i] = _material->createInstance();

        _materialInstances[i]->setParameter("color", math::float4{0.0f, 0.0f, 0.0f, 0.0f});  

        math::mat4f transform;
        switch (i-4)
        {
        case Axis::X:
            transform = math::mat4f::rotation(math::F_PI_2, math::float3{0, 1, 0});
            break;
        case Axis::Y:
            transform = math::mat4f::rotation(-math::F_PI_2, math::float3{1, 0, 0});
            break;
        case Axis::Z:
            break;
        }

        RenderableManager::Builder(1)
            .boundingBox({{-volumeWidth / 2, -volumeDepth / 2, 0}, {volumeWidth / 2, volumeDepth / 2, volumeLength}})
            .material(0, _materialInstances[i])
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, volumeVb, volumeIb, 0, 36)
            .priority(7)
            .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
            .culling(false)
            .receiveShadows(false)
            .castShadows(false)
            .build(*_engine, _entities[i]);

        auto instance = transformManager.getInstance(_entities[i]);
        transformManager.setTransform(instance, transform);

        // Parent the picking volume to the center cube
        transformManager.setParent(instance, transformManager.getInstance(_entities[3]));
    }
}

void Gizmo::highlight(Entity entity) {
    auto &rm = _engine->getRenderableManager();
    auto renderableInstance = rm.getInstance(entity);
    auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);

    math::float4 baseColor;
    if(entity == x()) {
        baseColor = activeColors[Axis::X];
    } else if(entity == y()) {
        baseColor = activeColors[Axis::Y];
    } else if(entity == z()) {
        baseColor = activeColors[Axis::Z];
    } else {
        baseColor = math::float4 { 1.0f, 1.0f, 1.0f, 1.0f };
    }

    materialInstance->setParameter("color", baseColor);
    
}

void Gizmo::unhighlight() {
    auto &rm = _engine->getRenderableManager();
    
    for(int i = 0; i < 3; i++) { 
        auto renderableInstance = rm.getInstance(_entities[i]);
        auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);

        math::float4 baseColor = inactiveColors[i];
        materialInstance->setParameter("color", baseColor);
    }
}

void Gizmo::pick(uint32_t x, uint32_t y, PickCallback callback)
  {
    auto handler = new Gizmo::PickCallbackHandler(this, callback);
    _view->pick(x, y,  [=](filament::View::PickingQueryResult const &result) { 
        handler->handle(result);
    });
  }

bool Gizmo::isGizmoEntity(Entity e) {
    for(int i = 0; i < 7; i++) {
        if(e == _entities[i]) {
            return true;
        }
    }
    return false;
}

void Gizmo::setVisibility(bool visible) {
    if(visible) {
        _scene->addEntities(_entities, 7);
    } else { 
        _scene->removeEntities(_entities, 7);
    }
}
}

