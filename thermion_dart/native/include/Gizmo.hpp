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

namespace thermion {

using namespace filament;
using namespace utils;

class Gizmo { 

    enum Axis { X, Y, Z};
    
    public:
        Gizmo(Engine *engine, View *view, Scene *scene);
        ~Gizmo();

        typedef void (*PickCallback)(EntityId entityId, uint32_t x, uint32_t y, View *view);

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

        bool isActive() { 
            return _isActive;
        }

        void pick(uint32_t x, uint32_t y, PickCallback callback);
        bool isGizmoEntity(Entity entity);
        void setVisibility(bool visible);

    private:

        class PickCallbackHandler {
            public: 
                PickCallbackHandler(Gizmo* gizmo, PickCallback callback) : _gizmo(gizmo), _callback(callback) {};
                void handle(filament::View::PickingQueryResult const &result) { 
                    auto x = static_cast<int32_t>(result.fragCoords.x);
                    auto y= static_cast<int32_t>(result.fragCoords.y);
                    for(int i = 0; i < 7; i++) {
                        if(_gizmo->_entities[i] == result.renderable) {
                            if(i < 4) {
                                return;    
                            }
                            _gizmo->highlight(_gizmo->_entities[i - 4]);
                            _callback(Entity::smuggle(_gizmo->_entities[i - 4]), x, y, _gizmo->_view);
                            return;
                        }
                    }
                    _gizmo->unhighlight();
                    _callback(0, x, y, _gizmo->_view);
                    delete(this);
                }

            private:
                Gizmo* _gizmo;
                PickCallback _callback;

        };
        void createTransparentRectangles();
        void highlight(Entity entity);
        void unhighlight();
        Engine *_engine;
        Scene *_scene;
        View *_view;
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