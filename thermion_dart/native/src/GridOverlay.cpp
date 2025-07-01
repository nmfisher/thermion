#include "scene/GridOverlay.hpp"
#include "Log.hpp"

namespace thermion
{

    GridOverlay::GridOverlay(Engine &engine, Material *material) : _engine(engine), _material(material)
    {
        createGrid();
        //createSphere();
    }

    GridOverlay::~GridOverlay()
    {
        auto &rm = _engine.getRenderableManager();
        auto &tm = _engine.getTransformManager();

        
        rm.destroy(_gridEntity);
        tm.destroy(_gridEntity);
        _engine.destroy(_gridEntity);
        
        // rm.destroy(_sphereEntity);
        // tm.destroy(_sphereEntity);
        // _engine.destroy(_sphereEntity);
        
        _engine.destroy(_materialInstance);
        _engine.destroy(_material);
    }

    void GridOverlay::createGrid()
    {
        const float stepSize = 0.25f;                    
        const int gridSize = 8;                          // Number of grid cells in each direction (-1 to 1 with 0.25 step = 8 cells)
        const int vertexCount = gridSize * gridSize * 4; // 4 vertices per grid cell
        const int indexCount = gridSize * gridSize * 6;  // 6 indices (2 triangles) per grid cell

        std::vector<math::float3> *vertices = new std::vector<math::float3>();
        std::vector<uint32_t> *indices = new std::vector<uint32_t>();
        vertices->reserve(vertexCount);
        indices->reserve(indexCount);

        // Generate grid vertices and indices
        for (float x = -1.0f; x < 1.0f; x += stepSize)
        {
            for (float z = -1.0f; z < 1.0f; z += stepSize)
            {
                uint32_t baseIndex = vertices->size();

                // Add four vertices for this grid cell
                vertices->push_back({x, 0.0f, z});                       // Bottom-left
                vertices->push_back({x, 0.0f, z + stepSize});            // Top-left
                vertices->push_back({x + stepSize, 0.0f, z + stepSize}); // Top-right
                vertices->push_back({x + stepSize, 0.0f, z});            // Bottom-right

                // Add indices for two triangles
                indices->push_back(baseIndex);
                indices->push_back(baseIndex + 1);
                indices->push_back(baseIndex + 2);
                indices->push_back(baseIndex + 2);
                indices->push_back(baseIndex + 3);
                indices->push_back(baseIndex);
            }
        }

        auto vb = VertexBuffer::Builder()
                      .vertexCount(vertices->size())
                      .bufferCount(1)
                      .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                      .build(_engine);

        vb->setBufferAt(_engine, 0,
                        VertexBuffer::BufferDescriptor(
                            vertices->data(),
                            vertices->size() * sizeof(math::float3),
                            [](void *buffer, size_t size, void *user) {
                                delete static_cast<std::vector<math::float3>*>(user);
                            }, vertices));

        auto ib = IndexBuffer::Builder()
                      .indexCount(indices->size())
                      .bufferType(IndexBuffer::IndexType::UINT)
                      .build(_engine);

        ib->setBuffer(_engine,
                      IndexBuffer::BufferDescriptor(
                          indices->data(),
                          indices->size() * sizeof(uint32_t),
                          [](void *buffer, size_t size, void *user) {
                            delete static_cast<std::vector<uint32_t>*>(user);
                           }, indices));

        _gridEntity = utils::EntityManager::get().create();

        _materialInstance = _material->createInstance();

        _materialInstance->setParameter("distance", 10000.0f);
        _materialInstance->setParameter("lineSize", 0.01f);
        _materialInstance->setParameter("gridColor", filament::math::float3 { 0.15f, 0.15f, 0.15f});

        RenderableManager::Builder(1)
            .boundingBox({{-1.0f, -1.0f, -1.0f}, // Min point
                          {1.0f, 1.0f, 1.0f}})   // Max point
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb, ib, 0, indices->size())
            .material(0, _materialInstance)
            .priority(0x7)
            .layerMask(0xFF, 1u << SceneLayer::Overlay)
            /*  
                We disable culling here because we calculate the quad's world-space coordinates
                manually in the shader (see grid.mat). Without this, the quad would be culled before
                rendered.
            */ 
           
            .culling(false) 
            .receiveShadows(false)
            .castShadows(false)
            .build(_engine, _gridEntity);

        _childEntities[0] = _gridEntity;
    }

    void GridOverlay::createSphere()
    {
        const float sphereRadius = 1.05f;
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
            .layerMask(0xFF, 1u << SceneLayer::Overlay)
            .culling(true)
            .receiveShadows(false)
            .castShadows(false)
            .build(_engine, _sphereEntity);
        _childEntities[1] = _sphereEntity;
    }

    SceneAsset *GridOverlay::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {
        auto instance = std::make_unique<GridOverlay>(_engine, _material);
        auto *raw = instance.get();
        _instances.push_back(std::move(instance));
        return reinterpret_cast<SceneAsset *>(raw);
    }

    void GridOverlay::addAllEntities(Scene *scene)
    {
        scene->addEntity(_gridEntity);
        // scene->addEntity(_sphereEntity);
    }

    void GridOverlay::removeAllEntities(Scene *scene)
    {
        scene->remove(_gridEntity);
        // scene->remove(_sphereEntity);
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

    size_t GridOverlay::getChildEntityCount() { 
        return 1; 
    }

    Entity GridOverlay::findEntityByName(const char *name)
    {
        return Entity(); // Not implemented
    }

} // namespace thermion