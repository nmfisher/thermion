#include "scene/GridOverlay.hpp"
#include "scene/SceneManager.hpp"
#include "material/grid.h"
#include "Log.hpp"

namespace thermion
{

    GridOverlay::GridOverlay(Engine &engine) : _engine(engine)
    {
        createGrid();
        createSphere();
        _childEntities[0] = _gridEntity;
        _childEntities[1] = _sphereEntity;
    }

    GridOverlay::~GridOverlay()
    {
        auto &rm = _engine.getRenderableManager();
        auto &tm = _engine.getTransformManager();

        rm.destroy(_sphereEntity);
        rm.destroy(_gridEntity);
        tm.destroy(_sphereEntity);
        tm.destroy(_gridEntity);
        _engine.destroy(_sphereEntity);
        _engine.destroy(_gridEntity);
        _engine.destroy(_materialInstance);
        _engine.destroy(_material);
    }

    void GridOverlay::createGrid()
    {
        const int gridSize = 100;
        const float gridSpacing = 1.0f;
        int vertexCount = (gridSize + 1) * 4; // 2 axes, 2 vertices per line

        float *gridVertices = new float[vertexCount * 3];
        int index = 0;

        // Create grid lines
        for (int i = 0; i <= gridSize; ++i)
        {
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
                      .build(_engine);

        vb->setBufferAt(_engine, 0, VertexBuffer::BufferDescriptor(gridVertices, vertexCount * sizeof(math::float3), [](void *buffer, size_t size, void *)
                                                                   { delete[] static_cast<float *>(buffer); }));

        uint32_t *gridIndices = new uint32_t[vertexCount];
        for (uint32_t i = 0; i < vertexCount; ++i)
        {
            gridIndices[i] = i;
        }

        auto ib = IndexBuffer::Builder()
                      .indexCount(vertexCount)
                      .bufferType(IndexBuffer::IndexType::UINT)
                      .build(_engine);

        ib->setBuffer(_engine, IndexBuffer::BufferDescriptor(
                                   gridIndices,
                                   vertexCount * sizeof(uint32_t),
                                   [](void *buffer, size_t size, void *)
                                   { delete[] static_cast<uint32_t *>(buffer); }));

        _gridEntity = utils::EntityManager::get().create();
        _material = Material::Builder()
                        .package(GRID_PACKAGE, GRID_GRID_SIZE)
                        .build(_engine);

        _materialInstance = _material->createInstance();
        _materialInstance->setParameter("maxDistance", 50.0f);
        _materialInstance->setParameter("color", math::float3{0.05f, 0.05f, 0.05f});

        RenderableManager::Builder(1)
            .boundingBox({{-gridSize * gridSpacing / 2, 0, -gridSize * gridSpacing / 2},
                          {gridSize * gridSpacing / 2, 0, gridSize * gridSpacing / 2}})
            .material(0, _materialInstance)
            .geometry(0, RenderableManager::PrimitiveType::LINES, vb, ib, 0, vertexCount)
            .priority(7)
            .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
            .culling(true)
            .receiveShadows(false)
            .castShadows(false)
            .build(_engine, _gridEntity);
    }

    void GridOverlay::createSphere()
    {
        const float sphereRadius = 0.05f;
        const int sphereSegments = 16;
        const int sphereRings = 16;

        int vertexCount = (sphereRings + 1) * (sphereSegments + 1);
        int indexCount = sphereRings * sphereSegments * 6;

        math::float3 *vertices = new math::float3[vertexCount];
        uint32_t *indices = new uint32_t[indexCount];

        int vertexIndex = 0;
        // Generate sphere vertices
        for (int ring = 0; ring <= sphereRings; ++ring)
        {
            float theta = ring * M_PI / sphereRings;
            float sinTheta = std::sin(theta);
            float cosTheta = std::cos(theta);

            for (int segment = 0; segment <= sphereSegments; ++segment)
            {
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
        for (int ring = 0; ring < sphereRings; ++ring)
        {
            for (int segment = 0; segment < sphereSegments; ++segment)
            {
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
                            .build(_engine);

        sphereVb->setBufferAt(_engine, 0, VertexBuffer::BufferDescriptor(vertices, vertexCount * sizeof(math::float3), [](void *buffer, size_t size, void *)
                                                                         { delete[] static_cast<math::float3 *>(buffer); }));

        auto sphereIb = IndexBuffer::Builder()
                            .indexCount(indexCount)
                            .bufferType(IndexBuffer::IndexType::UINT)
                            .build(_engine);

        sphereIb->setBuffer(_engine, IndexBuffer::BufferDescriptor(
                                         indices,
                                         indexCount * sizeof(uint32_t),
                                         [](void *buffer, size_t size, void *)
                                         { delete[] static_cast<uint32_t *>(buffer); }));

        _sphereEntity = utils::EntityManager::get().create();

        RenderableManager::Builder(1)
            .boundingBox({{-sphereRadius, -sphereRadius, -sphereRadius},
                          {sphereRadius, sphereRadius, sphereRadius}})
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, sphereVb, sphereIb, 0, indexCount)
            .priority(7)
            .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
            .culling(true)
            .receiveShadows(false)
            .castShadows(false)
            .build(_engine, _sphereEntity);
    }

    SceneAsset *GridOverlay::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {
        auto instance = std::make_unique<GridOverlay>(_engine);
        auto *raw = instance.get();
        _instances.push_back(std::move(instance));
        return reinterpret_cast<SceneAsset*>(raw);
    }

    void GridOverlay::addAllEntities(Scene *scene)
    {
        scene->addEntity(_gridEntity);
        scene->addEntity(_sphereEntity);
    }

    void GridOverlay::removeAllEntities(Scene *scene)
    {
        scene->remove(_gridEntity);
        scene->remove(_sphereEntity);
    }

    void GridOverlay::setPriority(RenderableManager &rm, int priority)
    {
        auto gridInstance = rm.getInstance(_gridEntity);
        rm.setPriority(gridInstance, priority);
        auto sphereInstance = rm.getInstance(_sphereEntity);
        rm.setPriority(sphereInstance, priority);
    }

    void GridOverlay::setLayer(RenderableManager &rm, int layer)
    {
        auto gridInstance = rm.getInstance(_gridEntity);
        rm.setLayerMask(gridInstance, 0xFF, 1u << (uint8_t)layer);
        auto sphereInstance = rm.getInstance(_sphereEntity);
        rm.setLayerMask(sphereInstance, 0xFF, 1u << (uint8_t)layer);
    }

    SceneAsset *GridOverlay::getInstanceByEntity(utils::Entity entity)
    {
        for (auto &instance : _instances)
        {
            if (instance->_gridEntity == entity || instance->_sphereEntity == entity)
            {
                return instance.get();
            }
        }
        return nullptr;
    }

    SceneAsset *GridOverlay::getInstanceAt(size_t index)
    {
        return _instances[index].get();
    }

    const Entity *GridOverlay::getChildEntities()
    {
        return _childEntities;
    }

    Entity GridOverlay::findEntityByName(const char *name)
    {
        return Entity(); // Not implemented
    }

} // namespace thermion