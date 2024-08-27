#include "Gizmo.hpp"

#include <filament/Engine.h>
#include <utils/Entity.h>
#include <utils/EntityManager.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>
#include <gltfio/math.h>

#include "material/gizmo.h"
#include "Log.hpp"

namespace thermion_filament {

using namespace filament::gltfio;

Gizmo::Gizmo(Engine &engine, View* view, Scene* scene) : _engine(engine)
{
    if(scene) {
        _scene = scene;
        _view = view;
        _camera = &(_view->getCamera());
    } else {
        _scene = _engine.createScene();
        _view = _engine.createView();
        _view->setBlendMode(BlendMode::TRANSLUCENT);
        
        utils::Entity camera = EntityManager::get().create();
        _camera = engine.createCamera(camera);
        _camera->setProjection(Camera::Projection::ORTHO, -1.0, 1.0, -1.0, 1.0, 1.0, 5.0);
        _view->setScene(_scene);
        _view->setCamera(_camera);

    }

    auto &entityManager = EntityManager::get();

    auto &transformManager = engine.getTransformManager();

    _material =
        Material::Builder()
            .package(GIZMO_GIZMO_DATA, GIZMO_GIZMO_SIZE)
            .build(engine);

    // First, create the black cube at the center
    // The axes widgets will be parented to this entity 
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
                            .build(engine);

    centerCubeVb->setBufferAt(engine, 0, VertexBuffer::BufferDescriptor(centerCubeVertices, 8 * sizeof(filament::math::float3), [](void *buffer, size_t size, void *)
                                                                        { delete[] static_cast<float *>(buffer); }));

    auto centerCubeIb = IndexBuffer::Builder().indexCount(36).bufferType(IndexBuffer::IndexType::USHORT).build(engine);
    centerCubeIb->setBuffer(engine, IndexBuffer::BufferDescriptor(
                                        centerCubeIndices, 36 * sizeof(uint16_t),
                                        [](void *buffer, size_t size, void *)
                                        { delete[] static_cast<uint16_t *>(buffer); }));

    RenderableManager::Builder(1)
        .boundingBox({{-centerCubeSize, -centerCubeSize, -centerCubeSize}, 
                      {centerCubeSize, centerCubeSize, centerCubeSize}})
        .material(0, _materialInstances[3])
        .layerMask(0xFF, 2)
        .priority(7)
        .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, centerCubeVb, centerCubeIb, 0, 36)
        .culling(false)
        .build(engine, _entities[3]);

    auto cubeTransformInstance = transformManager.getInstance(_entities[3]);
    math::mat4f cubeTransform;
    transformManager.setTransform(cubeTransformInstance, cubeTransform);

    // Line and arrow vertices
    float lineLength = 0.8f;
    float lineWidth = 0.005f;
    float arrowLength = 0.1f;
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
                  .build(engine);

    vb->setBufferAt(engine, 0, VertexBuffer::BufferDescriptor(vertices, 13 * sizeof(filament::math::float3), [](void *buffer, size_t size, void *)
                                                              { delete[] static_cast<float *>(buffer); }));

    auto ib = IndexBuffer::Builder().indexCount(54).bufferType(IndexBuffer::IndexType::USHORT).build(engine);
    ib->setBuffer(engine, IndexBuffer::BufferDescriptor(
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
            .layerMask(0xFF, 2)
            .culling(false)
            .receiveShadows(false)
            .castShadows(false)
            .build(engine, _entities[i]);


        auto instance = transformManager.getInstance(_entities[i]);
        transformManager.setTransform(instance, transform);

        // parent the axis to the center cube
        transformManager.setParent(instance, cubeTransformInstance);

    }
    
    _scene->addEntities(_entities,4);

    _view->setLayerEnabled(0, true);  // scene assets
    _view->setLayerEnabled(1, true);  // gizmo
    _view->setLayerEnabled(2, true); // world grid
}

Gizmo::~Gizmo() {
    _scene->removeEntities(_entities, 4);
    for(int i = 0; i < 4; i++) {
        _engine.destroy(_materialInstances[i]);    
    }
    _engine.destroy(_material);
    for(int i = 0; i < 4; i++) {
        _engine.destroy(_entities[i]);    
    }
    
    _view->setScene(nullptr);
    _engine.destroy(_scene);
    _engine.destroy(_view);

}

void Gizmo::highlight(Entity entity) {
    auto &rm = _engine.getRenderableManager();
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
    auto &rm = _engine.getRenderableManager();
    
    for(int i = 0; i < 3; i++) { 
        auto renderableInstance = rm.getInstance(_entities[i]);
        auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);

        math::float4 baseColor = inactiveColors[i];
        materialInstance->setParameter("color", baseColor);
    }
}

void Gizmo::destroy()
{
    auto& rm = _engine.getRenderableManager();
    auto& tm = _engine.getTransformManager();
        
    for (int i = 0; i < 4; i++)
    {
        rm.destroy(_entities[i]);
        tm.destroy(_entities[i]);
        _engine.destroy(_entities[i]);
        _engine.destroy(_materialInstances[i]);
    }

    _engine.destroy(_material);
}


void Gizmo::updateTransform()
{
    return;
    // auto & transformManager = _engine.getTransformManager();
    // auto transformInstance = transformManager.getInstance(_entities[3]);

    // if(!transformInstance.isValid()) {
    //     Log("No valid gizmo transform");
    //     return;
    // }

    // auto worldTransform = transformManager.getWorldTransform(transformInstance);
    // math::float4 worldPosition { 0.0f, 0.0f, 0.0f, 1.0f };
    // worldPosition = worldTransform * worldPosition;

    // // Calculate distance
    // float distance = length(worldPosition.xyz - camera.getPosition());

    // const float desiredScreenSize = 3.0f;  // Desired height in pixels
    // const float baseSize = 0.1f;  // Base size in world units

    // // Get the vertical field of view of the camera (assuming it's in radians)
    // float fovY = camera.getFieldOfViewInDegrees(filament::Camera::Fov::VERTICAL);

    // // Calculate the scale needed to maintain the desired screen size
    // float newScale = (2.0f * distance * tan(fovY * 0.5f) * desiredScreenSize) / (baseSize * vp.height);

    // if(std::isnan(newScale)) { 
    //     newScale = 1.0f;
    // }

    // // Log("Distance %f, newscale %f", distance, newScale);
    
    // auto localTransform = transformManager.getTransform(transformInstance);
    
    // // Apply scale to gizmo
    // math::float3 translation;
    // math::quatf rotation;
    // math::float3 scale;

    // decomposeMatrix(localTransform, &translation, &rotation, &scale);

    // scale = math::float3 { newScale, newScale, newScale };

    // auto scaledTransform = composeMatrix(translation, rotation, scale);

    // transformManager.setTransform(transformInstance, scaledTransform);

    // auto viewSpacePos = camera.getViewMatrix() * worldPosition;
    // math::float4 entityScreenPos = camera.getProjectionMatrix() * viewSpacePos;
    // entityScreenPos /= entityScreenPos.w;
    // float screenX = (entityScreenPos.x * 0.5f + 0.5f) * vp.width;
    // float screenY = (entityScreenPos.y * 0.5f + 0.5f) * vp.height;
}

void Gizmo::pick(uint32_t x, uint32_t y, void (*callback)(EntityId entityId, int x, int y))
  {
    auto * gizmo = this;
    _view->pick(x, y, [=](filament::View::PickingQueryResult const &result) { 
      if(result.renderable == gizmo->x() || result.renderable == gizmo->y() || result.renderable == gizmo->z()) {
        gizmo->highlight(result.renderable);
        callback(Entity::smuggle(result.renderable), x, y);
      } else { 
        gizmo->unhighlight();
      }
    });
  }


}