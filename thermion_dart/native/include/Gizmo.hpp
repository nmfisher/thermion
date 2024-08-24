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

namespace thermion_filament {

using namespace filament;
using namespace utils;

class Gizmo { 

    enum Axis { X, Y, Z};

    public:
        Gizmo(Engine& engine);
        void updateTransform(Camera& camera, const Viewport& vp);
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

        void highlight(Entity entity);
        void unhighlight();
    private:
        Engine &_engine;
        utils::Entity _entities[4];
        Material* _material;
        MaterialInstance* _materialInstances[4];
        math::float3 inactiveColors[3] {
            math::float3 { 0.75f, 0.0f, 0.0f },
            math::float3 { 0.0f, 0.75f, 0.0f },
            math::float3 { 0.0f, 0.0f, 0.75f },
        };
        math::float3 activeColors[3] {
            math::float3 { 1.0f, 0.0f, 0.0f },
            math::float3 { 0.0f, 1.0f, 0.0f },
            math::float3 { 0.0f, 0.0f, 1.0f },
        };
};

}