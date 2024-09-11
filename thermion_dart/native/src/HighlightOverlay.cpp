#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <utils/EntityManager.h>

#include "SceneManager.hpp"

namespace thermion_filament {

    SceneManager::HighlightOverlay::HighlightOverlay(
        EntityId entityId, 
        SceneManager* const sceneManager, 
        Engine* engine,
        float r, 
        float g, 
        float b) : _sceneManager(sceneManager), _engine(engine) {
        
        auto& rm = engine->getRenderableManager();
        
        auto& tm = engine->getTransformManager();

        // Create the outline/highlight material instance
        filament::gltfio::MaterialKey dummyKey;  // We're not using the key for this simple material
        filament::gltfio::UvMap dummyUvMap;      // We're not using UV mapping for this simple material

        auto materialProvider = sceneManager->unlitMaterialProvider();
        
        _highlightMaterialInstance = materialProvider->createMaterialInstance(&dummyKey, &dummyUvMap);
        
        _highlightMaterialInstance->setStencilOpStencilFail(filament::backend::StencilOperation::KEEP);
        _highlightMaterialInstance->setStencilOpDepthFail(filament::backend::StencilOperation::KEEP);
        _highlightMaterialInstance->setStencilOpDepthStencilPass(filament::backend::StencilOperation::KEEP);
        _highlightMaterialInstance->setStencilCompareFunction(filament::backend::SamplerCompareFunc::NE);
        _highlightMaterialInstance->setStencilReferenceValue(1);
        _highlightMaterialInstance->setParameter("color", filament::math::float3 { r, g, b });
        _highlightMaterialInstance->setParameter("scale", 1.05f);

        auto scene = sceneManager->getScene();

        _isGeometryEntity = sceneManager->isGeometryEntity(entityId);
        _isGltfAsset = sceneManager->isGltfAsset(entityId);

        if(!(_isGeometryEntity || _isGltfAsset)) {
            Log("Failed to set stencil outline for entity %d: the entity is a child of another entity. "
            "Currently, we only support outlining top-level entities."
            "Call getAncestor() to get the ancestor of this entity, then set on that", entityId);
            return;
        }

        if(_isGeometryEntity) {

            Log("Entity %d is geometry", entityId);

            auto geometryEntity = Entity::import(entityId);
            auto renderable = rm.getInstance(geometryEntity); 

            auto materialInstance = rm.getMaterialInstanceAt(renderable, 0);

            // set stencil write on the existing material
            materialInstance->setStencilWrite(true);
            materialInstance->setDepthWrite(true);
            materialInstance->setStencilReferenceValue(1);
            materialInstance->setStencilOpStencilFail(filament::backend::StencilOperation::KEEP);
            materialInstance->setStencilOpDepthFail(filament::backend::StencilOperation::REPLACE);
            materialInstance->setStencilOpDepthStencilPass(filament::backend::StencilOperation::REPLACE);
            materialInstance->setStencilCompareFunction(filament::backend::SamplerCompareFunc::A);

            auto geometry = sceneManager->getGeometry(entityId);

            _entity = utils::EntityManager::get().create();
            RenderableManager::Builder builder(1);
            builder.boundingBox(geometry->getBoundingBox())
                    .geometry(0, geometry->primitiveType, geometry->vertexBuffer(), geometry->indexBuffer(), 0, geometry->numIndices)
                    .culling(true)
                    .material(0, _highlightMaterialInstance)
                    .receiveShadows(false)
                    .castShadows(false);

            builder.build(*engine, _entity);

            scene->addEntity(_entity);
            auto outlineTransformInstance = tm.getInstance(_entity);
            auto entityTransformInstance = tm.getInstance(geometryEntity);
            tm.setParent(outlineTransformInstance, entityTransformInstance);            
        } else if(_isGltfAsset) {
            Log("Entity %d is gltf", entityId);
            auto *asset = sceneManager->getAssetByEntityId(entityId);
            
            if (asset)
            {

                Log("Found glTF FilamentAsset with %d material instances", asset->getInstance()->getMaterialInstanceCount());


                auto materialInstance = asset->getInstance()->getMaterialInstances()[0];

                // set stencil write on the existing material
                materialInstance->setStencilWrite(true);
                materialInstance->setDepthWrite(true);
                materialInstance->setStencilReferenceValue(1);
                materialInstance->setStencilOpStencilFail(filament::backend::StencilOperation::KEEP);
                materialInstance->setStencilOpDepthFail(filament::backend::StencilOperation::REPLACE);
                materialInstance->setStencilOpDepthStencilPass(filament::backend::StencilOperation::REPLACE);
                materialInstance->setStencilCompareFunction(filament::backend::SamplerCompareFunc::A);

                _newInstance = sceneManager->createGltfAssetInstance(asset);

                _entity = _newInstance->getRoot();

                auto newTransformInstance = tm.getInstance(_entity);

                auto entityTransformInstance = tm.getInstance(asset->getRoot());                
                tm.setParent(newTransformInstance, entityTransformInstance);      
                if(!_newInstance) {
                    Log("Couldn't create new instance");
                } else {
                    for(int i = 0; i < _newInstance->getEntityCount(); i++) {
                        auto entity = _newInstance->getEntities()[i];
                        auto renderableInstance = rm.getInstance(entity);
                        rm.setPriority(renderableInstance, 7);
                        if(renderableInstance.isValid()) {
                            for(int primitiveIndex = 0; primitiveIndex < rm.getPrimitiveCount(renderableInstance); primitiveIndex++) {
                                rm.setMaterialInstanceAt(renderableInstance, primitiveIndex, _highlightMaterialInstance);
                            }
                        } else { 
                            Log("Not renderable, ignoring");
                        }
                    }                
                    scene->addEntities(_newInstance->getEntities(), _newInstance->getEntityCount());                   
                }
            } else { 
                Log("Not FilamentAsset");
            }
        }


}

SceneManager::HighlightOverlay::~HighlightOverlay() { 
    Log("Destructor");
      if (_entity.isNull()) {
        Log("Null entity");
        return;
      }

       if (_isGltfAsset)
        {
            Log("Erasing new instance");
            _sceneManager->getScene()->removeEntities(_newInstance->getEntities(), _newInstance->getEntityCount());
            _newInstance->detachMaterialInstances();
            _engine->destroy(_highlightMaterialInstance);
        } else if(_isGeometryEntity) {
            Log("Erasing new geometry");
            auto& tm = _engine->getTransformManager();
            auto transformInstance = tm.getInstance(_entity);
            _sceneManager->getScene()->remove(_entity);
            utils::EntityManager::get().destroy(_entity);
            _engine->destroy(_entity);
            _engine->destroy(_highlightMaterialInstance);
        } else { 
            Log("FATAL: Unknown highlight overlay entity type");
        }
    }
}