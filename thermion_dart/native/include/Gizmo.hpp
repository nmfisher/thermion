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

#include "ThermionDartApi.h"

namespace thermion_filament {

using namespace filament;
using namespace utils;

class Gizmo { 

    enum Axis { X, Y, Z};

    class PickCallbackHandler {
        public: 
            PickCallbackHandler(Gizmo* gizmo, void (*callback)(EntityId entityId, int x, int y)) : _gizmo(gizmo), _callback(callback) {};
            void handle(filament::View::PickingQueryResult const &result) { 
                auto x = static_cast<int32_t>(result.fragCoords.x);
                auto y= static_cast<int32_t>(result.fragCoords.y);
                for(int i = 0; i < 7; i++) {
                    if(_gizmo->_entities[i] == result.renderable) {
                        if(i < 4) {
                            return;    
                        }
                        _gizmo->highlight(_gizmo->_entities[i - 4]);
                        _callback(Entity::smuggle(_gizmo->_entities[i - 4]), x, y);
                        return;
                    }
                }
                _gizmo->unhighlight();
                _callback(0, x, y);
                delete(this);
            }

        private:
            Gizmo* _gizmo;
            void (*_callback)(EntityId entityId, int x, int y);

    };

    public:
        Gizmo(Engine& engine, View *view, Scene *scene);
        ~Gizmo();

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
        filament::Camera *_camera;
        utils::Entity _entities[7] = { utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity(), utils::Entity() };
        Material* _material;
        MaterialInstance* _materialInstances[7];
        math::float4 inactiveColors[3] {
            math::float4 { 1.0f, 0.0f, 0.0f, 0.5f },
            math::float4 { 0.0f, 1.0f, 0.0f, 0.5f },
            math::float4 { 0.0f, 0.0f, 1.0f, 0.5f },
        };
        math::float4 activeColors[3] {
            math::float4 { 1.0f, 0.0f, 0.0f, 1.0f },
            math::float4 { 0.0f, 1.0f, 0.0f, 1.0f },
            math::float4 { 0.0f, 0.0f, 1.0f, 1.0f },
        };
        bool _isActive = true;
        
};

}