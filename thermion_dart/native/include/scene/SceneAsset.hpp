#pragma once

#include <memory>

#include <filament/Scene.h>
#include <gltfio/FilamentAsset.h>
#include <math.h>
#include <utils/Entity.h>

#include "CustomGeometry.hpp"
#include "Log.hpp"

namespace thermion {

using namespace filament;
using namespace utils;

class SceneAsset {

    public:
        enum SceneAssetType { Gltf, Geometry, Light, Skybox, Ibl, Image, Gizmo };
        
        virtual ~SceneAsset() {
            
        }

        virtual SceneAssetType getType() = 0;
        
        virtual utils::Entity getEntity() {
            return utils::Entity::import(0);
        }
        
        virtual bool isInstance() = 0;
        virtual SceneAsset* getInstanceOwner() = 0;
        virtual void destroyInstance(SceneAsset *instance) = 0;

        virtual SceneAsset* createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount) = 0;

        virtual MaterialInstance **getMaterialInstances() = 0;
        virtual size_t getMaterialInstanceCount() = 0;
        virtual void addAllEntities(Scene *scene) = 0;
        virtual void removeAllEntities(Scene *scene) = 0;

        virtual size_t getInstanceCount() = 0;
        virtual SceneAsset *getInstanceByEntity(utils::Entity entity) = 0;
        virtual SceneAsset *getInstanceAt(size_t index) = 0;
        virtual size_t getChildEntityCount() = 0;
        virtual const Entity* getChildEntities() = 0;
        virtual Entity findEntityByName(const char* name) = 0;

        virtual const filament::Aabb getBoundingBox() const = 0;


    
};
}