#pragma once

#include <memory>

#include <utils/Entity.h>
#include <gltfio/FilamentAsset.h>
#include <filament/Scene.h>

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

        virtual const Aabb getBoundingBox() const = 0;

        virtual SceneAssetType getType() = 0;
        
        virtual utils::Entity getEntity() {
            return utils::Entity::import(0);
        }
        
        virtual bool isInstance() = 0;
        
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

        virtual void setPriority(RenderableManager& rm, int mask) = 0;
        virtual void setLayer(RenderableManager& rm, int layer) = 0;


    
};
}