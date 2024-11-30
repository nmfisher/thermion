#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>

#include <utils/Entity.h>
#include <utils/EntityManager.h>

#include <gltfio/math.h>

#include "scene/Gizmo.hpp"
#include "scene/SceneManager.hpp"

#include "material/unlit_fixed_size.h"

#include "Log.hpp"

namespace thermion
{

    using namespace filament::gltfio;

    // First, create the black cube at the center
    // The axes widgets will be parented to this entity
    Entity Gizmo::createParentEntity()
    {
        auto &transformManager = _engine->getTransformManager();
        auto &entityManager = _engine->getEntityManager();

        auto parent = entityManager.create();

        // auto *parentMaterialInstance = _material->createInstance();
        // parentMaterialInstance->setParameter("baseColorFactor", math::float4{1.0f, 1.0f, 1.0f, 0.0f});
        // parentMaterialInstance->setParameter("scale", 4.0f);
        // parentMaterialInstance->setDoubleSided(false);

        // _materialInstances.push_back(parentMaterialInstance);

        // Create center cube vertices
        float centerCubeSize = 0.1f;
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
                                .build(*_engine);

        centerCubeVb->setBufferAt(*_engine, 0, VertexBuffer::BufferDescriptor(centerCubeVertices, 8 * sizeof(filament::math::float3), [](void *buffer, size_t size, void *)
                                                                              { delete[] static_cast<float *>(buffer); }));

        auto centerCubeIb = IndexBuffer::Builder().indexCount(36).bufferType(IndexBuffer::IndexType::USHORT).build(*_engine);
        centerCubeIb->setBuffer(*_engine, IndexBuffer::BufferDescriptor(
                                              centerCubeIndices, 36 * sizeof(uint16_t),
                                              [](void *buffer, size_t size, void *)
                                              { delete[] static_cast<uint16_t *>(buffer); }));

        RenderableManager::Builder(1)
            .boundingBox({{-centerCubeSize, -centerCubeSize, -centerCubeSize},
                          {centerCubeSize, centerCubeSize, centerCubeSize}})
            // .material(0, parentMaterialInstance)
            .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
            .priority(0)
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, centerCubeVb, centerCubeIb, 0, 36)
            .culling(true)
            .build(*_engine, parent);

        auto parentTransformInstance = transformManager.getInstance(parent);
        math::mat4f cubeTransform;
        transformManager.setTransform(parentTransformInstance, cubeTransform);
        return parent;
    }

    Gizmo::Gizmo(Engine *engine, View *view, Scene *scene, Material *material) : _engine(engine), _view(view), _scene(scene), _material(material)
    {
        auto parent = createParentEntity();
        auto x = createAxisEntity(Gizmo::Axis::X, parent);
        auto y = createAxisEntity(Gizmo::Axis::Y, parent);
        auto z = createAxisEntity(Gizmo::Axis::Z, parent);

        auto xHitTest = createHitTestEntity(Gizmo::Axis::X, parent);
        auto yHitTest = createHitTestEntity(Gizmo::Axis::Y, parent);
        auto zHitTest = createHitTestEntity(Gizmo::Axis::Z, parent);

        _entities = std::vector{parent, x, y, z, xHitTest, yHitTest, zHitTest};
        _parent = parent;
        _x = x;
        _y = y;
        _z = z;
        _xHitTest = xHitTest;
        _yHitTest = yHitTest;
        _zHitTest = zHitTest;
    }

    Entity Gizmo::createAxisEntity(Gizmo::Axis axis, Entity parent)
    {
        auto &entityManager = _engine->getEntityManager();
        auto &transformManager = _engine->getTransformManager();
        auto *materialInstance = _material->createInstance();
        _materialInstances.push_back(materialInstance);
        auto entity = entityManager.create();

        auto baseColor = inactiveColors[axis];

        // Line and arrow vertices
        float lineLength = 0.6f;
        float lineWidth = 0.008f;
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
        uint16_t *indices = new uint16_t[24 + 18]{
            // Line indices (24 indices)
            0, 1, 5, 5, 4, 0,
            1, 2, 6, 6, 5, 1,
            2, 3, 7, 7, 6, 2,
            3, 0, 4, 4, 7, 3,
            // // Arrow indices (18 indices)
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
                      .build(*_engine);

        vb->setBufferAt(*_engine, 0, VertexBuffer::BufferDescriptor(vertices, 13 * sizeof(filament::math::float3), [](void *buffer, size_t size, void *)
                                                                    { delete[] static_cast<float *>(buffer); }));

        auto ib = IndexBuffer::Builder().indexCount(42).bufferType(IndexBuffer::IndexType::USHORT).build(*_engine);
        ib->setBuffer(*_engine, IndexBuffer::BufferDescriptor(
                                    indices, 42 * sizeof(uint16_t),
                                    [](void *buffer, size_t size, void *)
                                    { delete[] static_cast<uint16_t *>(buffer); }));

        materialInstance->setParameter("baseColorFactor", baseColor);
        materialInstance->setParameter("scale", 4.0f);
                materialInstance->setDepthCulling(false);
        materialInstance->setDepthFunc(MaterialInstance::DepthFunc::A);

        RenderableManager::Builder(1)
            .boundingBox({{-arrowWidth, -arrowWidth, 0},
                          {arrowWidth, arrowWidth, lineLength + arrowLength}})
            .material(0, materialInstance)
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb, ib, 0, 42)
            .priority(6)
            .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
            .culling(false)
            .receiveShadows(false)
            .castShadows(false)
            .build(*_engine, entity);

        auto transformInstance = transformManager.getInstance(entity);

        transformManager.setTransform(transformInstance, getRotationForAxis(axis));

        // parent the axis to the center cube
        auto parentTransformInstance = transformManager.getInstance(parent);
        transformManager.setParent(transformInstance, parentTransformInstance);
        return entity;
    }

    Gizmo::~Gizmo()
    {
        _scene->removeEntities(_entities.data(), _entities.size());

        for (auto entity : _entities)
        {
            _engine->destroy(entity);
        }

        for (auto *materialInstance : _materialInstances)
        {
            _engine->destroy(materialInstance);
        }
    }

    Entity Gizmo::createHitTestEntity(Gizmo::Axis axis, Entity parent)
    {
        auto &entityManager = EntityManager::get();
        auto &transformManager = _engine->getTransformManager();

        auto parentTransformInstance = transformManager.getInstance(parent);

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
            -volumeWidth / 2, volumeDepth / 2, volumeLength};

        uint16_t *volumeIndices = new uint16_t[36]{
            0, 1, 2, 2, 3, 0, // Bottom face
            4, 5, 6, 6, 7, 4, // Top face
            0, 4, 7, 7, 3, 0, // Left face
            1, 5, 6, 6, 2, 1, // Right face
            0, 1, 5, 5, 4, 0, // Front face
            3, 2, 6, 6, 7, 3  // Back face
        };

        auto volumeVb = VertexBuffer::Builder()
                            .vertexCount(8)
                            .bufferCount(1)
                            .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                            .build(*_engine);

        volumeVb->setBufferAt(*_engine, 0, VertexBuffer::BufferDescriptor(volumeVertices, 8 * sizeof(filament::math::float3), [](void *buffer, size_t size, void *)
                                                                          { delete[] static_cast<float *>(buffer); }));

        auto volumeIb = IndexBuffer::Builder()
                            .indexCount(36)
                            .bufferType(IndexBuffer::IndexType::USHORT)
                            .build(*_engine);

        volumeIb->setBuffer(*_engine, IndexBuffer::BufferDescriptor(
                                          volumeIndices, 36 * sizeof(uint16_t),
                                          [](void *buffer, size_t size, void *)
                                          { delete[] static_cast<uint16_t *>(buffer); }));

        auto entity = entityManager.create();
        auto *materialInstance = _material->createInstance();
        _materialInstances.push_back(materialInstance);
        materialInstance->setParameter("baseColorFactor", math::float4{0.0f, 0.0f, 0.0f, 0.0f});
        materialInstance->setParameter("scale", 4.0f);
        materialInstance->setDepthFunc(MaterialInstance::DepthFunc::A);

        RenderableManager::Builder(1)
            .boundingBox({{-volumeWidth / 2, -volumeDepth / 2, 0}, {volumeWidth / 2, volumeDepth / 2, volumeLength}})
            .material(0, materialInstance)
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, volumeVb, volumeIb, 0, 36)
            .priority(7)
            .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
            .culling(false)
            .receiveShadows(false)
            .castShadows(false)
            .build(*_engine, entity);

        auto transformInstance = transformManager.getInstance(entity);
        transformManager.setTransform(transformInstance, getRotationForAxis(axis));
        // Parent the picking volume to the center cube
        transformManager.setParent(transformInstance, parentTransformInstance);
        return entity;
    }

    void Gizmo::highlight(Gizmo::Axis axis)
    {
        auto &rm = _engine->getRenderableManager();
        auto entity = getEntityForAxis(axis);
        if (entity.isNull())
        {
            return;
        }
        auto renderableInstance = rm.getInstance(entity);

        if (!renderableInstance.isValid())
        {
            Log("Invalid renderable for axis");
            return;
        }
        auto *materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);
        math::float4 baseColor = activeColors[axis];
        materialInstance->setParameter("baseColorFactor", baseColor);
    }

    void Gizmo::unhighlight(Gizmo::Axis axis)
    {
        auto &rm = _engine->getRenderableManager();
        auto entity = getEntityForAxis(axis);
        if (entity.isNull())
        {
            return;
        }
        auto renderableInstance = rm.getInstance(entity);
        if (!renderableInstance.isValid())
        {
            Log("Invalid renderable for axis");
            return;
        }
        auto *materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);
        math::float4 baseColor = inactiveColors[axis];
        materialInstance->setParameter("baseColorFactor", baseColor);
    }

    void Gizmo::pick(uint32_t x, uint32_t y, GizmoPickCallback callback)
    {

        auto handler = new Gizmo::PickCallbackHandler(this, callback);
        _view->pick(x, y, [=](filament::View::PickingQueryResult const &result)
                    { 
                        handler->handle(result); 
                        delete handler; });
    }

    bool Gizmo::isGizmoEntity(Entity e)
    {
        for (int i = 0; i < 7; i++)
        {
            if (e == _entities[i])
            {
                return true;
            }
        }
        return false;
    }

    math::mat4f Gizmo::getRotationForAxis(Gizmo::Axis axis)
    {

        math::mat4f transform;

        switch (axis)
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
        return transform;
    }

}
