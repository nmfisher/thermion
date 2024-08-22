#pragma once

#include <utils/Entity.h>
#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/Scene.h>
#include <filament/Camera.h>
#include <filament/View.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/ResourceLoader.h>

#include <filament/IndexBuffer.h>
#include <filament/InstanceBuffer.h>

#include "material/gizmo.h"

#include "Aabb2.h"

using namespace filament;
using namespace utils;


class Gizmo { 
    public:
        Gizmo(Engine* const engine);
        void updateTransform();
        void destroy(Engine* const engine);
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
    private:
        utils::Entity _entities[4];
        Material* _material;
        MaterialInstance* _materialInstances[4];
};