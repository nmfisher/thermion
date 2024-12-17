#pragma once

#include <memory>
#include <vector>

#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <utils/Entity.h>
#include "scene/SceneAsset.hpp"
#include "material/grid.h"


namespace thermion {

using namespace filament;

class GridOverlay : public SceneAsset {
public:
    GridOverlay(Engine& engine, Material* material);
    ~GridOverlay();

    SceneAssetType getType() override { return SceneAsset::SceneAssetType::Gizmo; }
    bool isInstance() override { return false; }
    
    SceneAsset* createInstance(MaterialInstance** materialInstances = nullptr, 
                              size_t materialInstanceCount = 0) override;
                              
    MaterialInstance** getMaterialInstances() override { return &_materialInstance; }
    size_t getMaterialInstanceCount() override { return 1; }
    
    void addAllEntities(Scene* scene) override;
    void removeAllEntities(Scene* scene) override;
    
    void setPriority(RenderableManager& rm, int priority) override;
    void setLayer(RenderableManager& rm, int layer) override;


    const Aabb getBoundingBox() const override
    {
        return Aabb { };
    }

    size_t getInstanceCount() override { return _instances.size(); }
    SceneAsset* getInstanceByEntity(utils::Entity entity) override;
    SceneAsset* getInstanceAt(size_t index) override;
    size_t getChildEntityCount() override;
    const Entity* getChildEntities() override;
    Entity findEntityByName(const char* name) override;

private:
    Engine& _engine;
    utils::Entity _gridEntity;
    utils::Entity _sphereEntity;
    Entity _childEntities[2];
    Material* _material;
    MaterialInstance* _materialInstance;
    std::vector<std::unique_ptr<GridOverlay>> _instances;
    
    void createGrid();
    void createSphere();
};

} // namespace thermion