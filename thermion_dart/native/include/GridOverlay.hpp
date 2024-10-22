#pragma once

#include <vector> 

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


namespace thermion {

using namespace filament;
using namespace utils;

class GridOverlay { 
    public:
        GridOverlay(Engine& engine);
        void destroy();

        utils::Entity sphere() {
            return _sphereEntity;
        }

        utils::Entity grid() {
            return _gridEntity;
        }
        
    private:
        Engine &_engine;
        utils::Entity _gridEntity;
        utils::Entity _sphereEntity;
        Material* _material;
        MaterialInstance* _materialInstance;
        MaterialInstance* _sphereMaterialInstance;
};

}