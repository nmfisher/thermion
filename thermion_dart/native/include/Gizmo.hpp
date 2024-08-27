#pragma once

#include <utils/Entity.h>
#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/Scene.h>
#include <filament/Camera.h>
#include <filament/View.h>
#include <filament/Viewport.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/ResourceLoader.h>

#include <filament/IndexBuffer.h>
#include <filament/InstanceBuffer.h>

#include "material/gizmo.h"

#include "Aabb2.h"
#include "ThermionDartApi.h"

namespace thermion_filament {

using namespace filament;
using namespace utils;

class Gizmo { 

    enum Axis { X, Y, Z};

    public:
        Gizmo(Engine& engine, View *view, Scene *scene);
        ~Gizmo();

        void destroy();
        Entity x() {
            return _entities[0];
        };
        Entity y() {
            return _entities[1];
        };
        Entity z() {
            return _entities[2];
        };
        Entity center() {
            return _entities[3];
        };
        View* view() { 
            return _view;
        }

        bool isActive() { 
            return _isActive;
        }

        void pick(uint32_t x, uint32_t y, void (*callback)(EntityId entityId, int x, int y));
        bool isGizmoEntity(Entity entity);
        void setVisibility(bool visible);

    private:
        void createTransparentRectangles();
        void highlight(Entity entity);
        void unhighlight();
        Engine &_engine;
        View *_view;
        Scene *_scene;
        Camera *_camera;
        utils::Entity _entities[7] = { utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity() };
        Material* _material;
        MaterialInstance* _materialInstances[7];
        math::float4 inactiveColors[3] {
            math::float4 { 0.75f, 0.0f, 0.0f, 1.0f },
            math::float4 { 0.0f, 0.75f, 0.0f, 1.0f },
            math::float4 { 0.0f, 0.0f, 0.75f, 1.0f },
        };
        math::float4 activeColors[3] {
            math::float4 { 1.0f, 0.0f, 0.0f, 1.0f },
            math::float4 { 0.0f, 1.0f, 0.0f, 1.0f },
            math::float4 { 0.0f, 0.0f, 1.0f, 1.0f },
        };
        bool _isActive = true;
        
};

}