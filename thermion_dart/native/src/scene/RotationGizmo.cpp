// #include <filament/Engine.h>
// #include <filament/RenderableManager.h>
// #include <filament/TransformManager.h>

// #include <gltfio/math.h>

// #include <utils/Entity.h>
// #include <utils/EntityManager.h>

// #include <math.h>

// #include "scene/SceneManager.hpp"

// namespace thermion {

// using namespace filament::gltfio;

// RotationGizmo::RotationGizmo(Engine* engine, View* view, Scene* scene, Material* material)
//     : _engine(engine), _view(view), _scene(scene), _material(material) {
    
//     auto& entityManager = EntityManager::get();
//     auto& transformManager = _engine->getTransformManager();

//     // Create center cube
//     auto parentEntity = entityManager.create();
//     auto* parentMaterialInstance = _material->createInstance();
//     parentMaterialInstance->setParameter("baseColorFactor", math::float4{0.0f, 0.0f, 0.0f, 1.0f});
//     parentMaterialInstance->setParameter("scale", 4.0f);

//     _entities[0] = parentEntity;
//     _materialInstances[0] = parentMaterialInstance;

//     // Create center cube geometry
//     float centerCubeSize = 0.01f;
//     float* centerCubeVertices = new float[8 * 3]{
//         -centerCubeSize, -centerCubeSize, -centerCubeSize,
//         centerCubeSize, -centerCubeSize, -centerCubeSize,
//         centerCubeSize, centerCubeSize, -centerCubeSize,
//         -centerCubeSize, centerCubeSize, -centerCubeSize,
//         -centerCubeSize, -centerCubeSize, centerCubeSize,
//         centerCubeSize, -centerCubeSize, centerCubeSize,
//         centerCubeSize, centerCubeSize, centerCubeSize,
//         -centerCubeSize, centerCubeSize, centerCubeSize
//     };

//     uint16_t* centerCubeIndices = new uint16_t[36]{
//         0, 1, 2, 2, 3, 0,
//         1, 5, 6, 6, 2, 1,
//         5, 4, 7, 7, 6, 5,
//         4, 0, 3, 3, 7, 4,
//         3, 2, 6, 6, 7, 3,
//         4, 5, 1, 1, 0, 4
//     };

//     auto centerCubeVb = VertexBuffer::Builder()
//         .vertexCount(8)
//         .bufferCount(1)
//         .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
//         .build(*engine);

//     centerCubeVb->setBufferAt(*engine, 0,
//         VertexBuffer::BufferDescriptor(centerCubeVertices, 8 * sizeof(filament::math::float3),
//             [](void* buffer, size_t size, void*) { delete[] static_cast<float*>(buffer); }));

//     auto centerCubeIb = IndexBuffer::Builder()
//         .indexCount(36)
//         .bufferType(IndexBuffer::IndexType::USHORT)
//         .build(*engine);

//     centerCubeIb->setBuffer(*engine,
//         IndexBuffer::BufferDescriptor(centerCubeIndices, 36 * sizeof(uint16_t),
//             [](void* buffer, size_t size, void*) { delete[] static_cast<uint16_t*>(buffer); }));

//     RenderableManager::Builder(1)
//         .boundingBox({{-centerCubeSize, -centerCubeSize, -centerCubeSize},
//                       {centerCubeSize, centerCubeSize, centerCubeSize}})
//         .material(0, parentMaterialInstance)
//         .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
//         .priority(7)
//         .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, centerCubeVb, centerCubeIb, 0, 36)
//         .culling(false)
//         .build(*engine, parentEntity);

//     // Create rotation circles
//     constexpr int segments = 32;
//     float radius = 0.5f;
//     float* vertices;
//     uint16_t* indices;
//     int vertexCount, indexCount;
    
//     createCircle(radius, segments, vertices, indices, vertexCount, indexCount);

//     auto vb = VertexBuffer::Builder()
//         .vertexCount(vertexCount)
//         .bufferCount(1)
//         .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
//         .build(*engine);

//     vb->setBufferAt(*engine, 0,
//         VertexBuffer::BufferDescriptor(vertices, vertexCount * sizeof(filament::math::float3),
//             [](void* buffer, size_t size, void*) { delete[] static_cast<float*>(buffer); }));

//     auto ib = IndexBuffer::Builder()
//         .indexCount(indexCount)
//         .bufferType(IndexBuffer::IndexType::USHORT)
//         .build(*engine);

//     ib->setBuffer(*engine,
//         IndexBuffer::BufferDescriptor(indices, indexCount * sizeof(uint16_t),
//             [](void* buffer, size_t size, void*) { delete[] static_cast<uint16_t*>(buffer); }));

//     // Create the three circular rotation handles
//     for (int i = 0; i < 3; i++) {
//         auto* materialInstance = _material->createInstance();
//         auto entity = entityManager.create();
//         _entities[i + 1] = entity;
//         _materialInstances[i + 1] = materialInstance;

//         auto baseColor = inactiveColors[i];
//         math::mat4f transform;

//         switch (i) {
//             case Axis::X:
//                 transform = math::mat4f::rotation(math::F_PI_2, math::float3{0, 1, 0});
//                 break;
//             case Axis::Y:
//                 transform = math::mat4f::rotation(math::F_PI_2, math::float3{1, 0, 0});
//                 break;
//             case Axis::Z:
//                 break;
//         }

//         materialInstance->setParameter("baseColorFactor", baseColor);
//         materialInstance->setParameter("scale", 4.0f);

//         RenderableManager::Builder(1)
//             .boundingBox({{-radius, -radius, -0.01f}, {radius, radius, 0.01f}})
//             .material(0, materialInstance)
//             .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb, ib, 0, indexCount)
//             .priority(6)
//             .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
//             .culling(false)
//             .receiveShadows(false)
//             .castShadows(false)
//             .build(*engine, entity);

//         auto transformInstance = transformManager.getInstance(entity);
//         transformManager.setTransform(transformInstance, transform);
//         transformManager.setParent(transformInstance, transformManager.getInstance(parentEntity));
//     }

//     createHitTestEntities();
//     setVisibility(true);
// }

// void RotationGizmo::createCircle(float radius, int segments, float*& vertices, uint16_t*& indices, int& vertexCount, int& indexCount) {
//     vertexCount = segments * 2;
//     indexCount = segments * 6;
    
//     vertices = new float[vertexCount * 3];
//     indices = new uint16_t[indexCount];

//     float thickness = 0.01f;
    
//     // Generate vertices for inner and outer circles
//     for (int i = 0; i < segments; i++) {
//         float angle = (2.0f * M_PI * i) / segments;
//         float x = cosf(angle);
//         float y = sinf(angle);
        
//         // Inner circle vertex
//         vertices[i * 6] = x * (radius - thickness);
//         vertices[i * 6 + 1] = y * (radius - thickness);
//         vertices[i * 6 + 2] = 0.0f;
        
//         // Outer circle vertex
//         vertices[i * 6 + 3] = x * (radius + thickness);
//         vertices[i * 6 + 4] = y * (radius + thickness);
//         vertices[i * 6 + 5] = 0.0f;
//     }

//     // Generate indices for triangles
//     for (int i = 0; i < segments; i++) {
//         int next = (i + 1) % segments;
        
//         // First triangle
//         indices[i * 6] = i * 2;
//         indices[i * 6 + 1] = i * 2 + 1;
//         indices[i * 6 + 2] = next * 2 + 1;
        
//         // Second triangle
//         indices[i * 6 + 3] = i * 2;
//         indices[i * 6 + 4] = next * 2 + 1;
//         indices[i * 6 + 5] = next * 2;
//     }
// }

// void RotationGizmo::createHitTestEntities() {
//     auto& entityManager = EntityManager::get();
//     auto& transformManager = _engine->getTransformManager();

//     float radius = 0.5f;
//     float thickness = 0.1f;

//     // Create hit test volumes for each rotation circle
//     for (int i = 4; i < 7; i++) {
//         _entities[i] = entityManager.create();
//         _materialInstances[i] = _material->createInstance();
        
//         _materialInstances[i]->setParameter("baseColorFactor", math::float4{0.0f, 0.0f, 0.0f, 0.0f});
//         _materialInstances[i]->setParameter("scale", 4.0f);

//         math::mat4f transform;
//         switch (i - 4) {
//             case Axis::X:
//                 transform = math::mat4f::rotation(math::F_PI_2, math::float3{0, 1, 0});
//                 break;
//             case Axis::Y:
//                 transform = math::mat4f::rotation(math::F_PI_2, math::float3{1, 0, 0});
//                 break;
//             case Axis::Z:
//                 break;
//         }

//         // Create a thicker invisible volume aroun

// // Create a thicker invisible volume around each rotation circle for hit testing
//         float* volumeVertices;
//         uint16_t* volumeIndices;
//         int volumeVertexCount, volumeIndexCount;
//         createCircle(radius, 32, volumeVertices, volumeIndices, volumeVertexCount, volumeIndexCount);

//         auto volumeVb = VertexBuffer::Builder()
//             .vertexCount(volumeVertexCount)
//             .bufferCount(1)
//             .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
//             .build(*_engine);

//         volumeVb->setBufferAt(*_engine, 0,
//             VertexBuffer::BufferDescriptor(volumeVertices, volumeVertexCount * sizeof(filament::math::float3),
//                 [](void* buffer, size_t size, void*) { delete[] static_cast<float*>(buffer); }));

//         auto volumeIb = IndexBuffer::Builder()
//             .indexCount(volumeIndexCount)
//             .bufferType(IndexBuffer::IndexType::USHORT)
//             .build(*_engine);

//         volumeIb->setBuffer(*_engine,
//             IndexBuffer::BufferDescriptor(volumeIndices, volumeIndexCount * sizeof(uint16_t),
//                 [](void* buffer, size_t size, void*) { delete[] static_cast<uint16_t*>(buffer); }));

//         RenderableManager::Builder(1)
//             .boundingBox({{-radius, -radius, -thickness/2}, {radius, radius, thickness/2}})
//             .material(0, _materialInstances[i])
//             .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, volumeVb, volumeIb, 0, volumeIndexCount)
//             .priority(7)
//             .layerMask(0xFF, 1u << SceneManager::LAYERS::OVERLAY)
//             .culling(false)
//             .receiveShadows(false)
//             .castShadows(false)
//             .build(*_engine, _entities[i]);

//         auto instance = transformManager.getInstance(_entities[i]);
//         transformManager.setTransform(instance, transform);
//         transformManager.setParent(instance, transformManager.getInstance(_entities[0]));
//     }
// }

// RotationGizmo::~RotationGizmo() {
//     _scene->removeEntities(_entities, 7);

//     for (int i = 0; i < 7; i++) {
//         _engine->destroy(_entities[i]);
//         _engine->destroy(_materialInstances[i]);
//     }
// }

// void RotationGizmo::highlight(Entity entity) {
//     auto& rm = _engine->getRenderableManager();
//     auto renderableInstance = rm.getInstance(entity);
//     auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);

//     math::float4 baseColor;
//     if (entity == x()) {
//         baseColor = activeColors[Axis::X];
//     } else if (entity == y()) {
//         baseColor = activeColors[Axis::Y];
//     } else if (entity == z()) {
//         baseColor = activeColors[Axis::Z];
//     } else {
//         baseColor = math::float4{1.0f, 1.0f, 1.0f, 1.0f};
//     }

//     materialInstance->setParameter("baseColorFactor", baseColor);
// }

// void RotationGizmo::unhighlight() {
//     auto& rm = _engine->getRenderableManager();

//     for (int i = 0; i < 3; i++) {
//         auto renderableInstance = rm.getInstance(_entities[i + 1]);
//         auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);
//         materialInstance->setParameter("baseColorFactor", inactiveColors[i]);
//     }
// }

// void RotationGizmo::pick(uint32_t x, uint32_t y, PickCallback callback) {
//     auto handler = new RotationGizmo::PickCallbackHandler(this, callback);
//     _view->pick(x, y, [=](filament::View::PickingQueryResult const& result) {
//         handler->handle(result);
//         delete handler;
//     });
// }

// void RotationGizmo::PickCallbackHandler::handle(filament::View::PickingQueryResult const& result) {
//     auto x = static_cast<int32_t>(result.fragCoords.x);
//     auto y = static_cast<int32_t>(result.fragCoords.y);
    
//     for (int i = 0; i < 7; i++) {
//         if (_gizmo->_entities[i] == result.renderable) {
//             if (i < 4) {
//                 return;
//             }
//             _gizmo->highlight(_gizmo->_entities[i - 4]);
//             _callback(static_cast<Axis>(i - 4), x, y, _gizmo->_view);
//             return;
//         }
//     }
//     _gizmo->unhighlight();
// }

// bool RotationGizmo::isGizmoEntity(Entity e) {
//     for (int i = 0; i < 7; i++) {
//         if (e == _entities[i]) {
//             return true;
//         }
//     }
//     return false;
// }

// void RotationGizmo::setVisibility(bool visible) {
//     if (visible) {
//         _scene->addEntities(_entities, 7);
//     } else {
//         _scene->removeEntities(_entities, 7);
//     }
// }

// }