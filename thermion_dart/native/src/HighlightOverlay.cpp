#include  <filament/Material.h>
#include  <filament/MaterialInstance.h>

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

        if(sceneManager->isGeometryEntity(entityId)) {

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
            return;
        }

        if(sceneManager->isGltfAsset(entityId)) {

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

                auto newInstance = sceneManager->createGltfAssetInstance(asset);

                _entity = newInstance->getRoot();

                auto newTransformInstance = tm.getInstance(_entity);

                auto entityTransformInstance = tm.getInstance(asset->getRoot());                
                tm.setParent(newTransformInstance, entityTransformInstance);      
                if(!newInstance) {
                    Log("Couldn't create new instance");
                } else {
                    for(int i = 0; i < newInstance->getEntityCount(); i++) {
                        auto entity = newInstance->getEntities()[i];
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
                    scene->addEntities(newInstance->getEntities(), newInstance->getEntityCount());                   
                }
                return;
            } else { 
                Log("Not FilamentAsset");
            }
        }

        Log("Looking for parent");

        auto renderable = rm.getInstance(Entity::import(entityId));
        auto transformInstance = tm.getInstance(Entity::import(entityId));
        if(!transformInstance.isValid()) {
            Log("Unknown entity type");
            return;
        } 

        Entity parent;
        while(true) {
            auto newParent = tm.getParent(transformInstance);
            if(newParent.isNull()) {
                break;
            }
            parent = newParent;
            transformInstance = tm.getInstance(parent);
        }
        if(parent.isNull()) {
            Log("Unknown entity type");
            return;
        }
        
        sceneManager->setStencilHighlight(Entity::smuggle(parent), r, g, b);
}

SceneManager::HighlightOverlay::~HighlightOverlay() { 
      if (_entity.isNull()) {
        return;
      }
      
      auto& rm = _engine->getRenderableManager();
      auto& tm = _engine->getTransformManager();

      _sceneManager->getScene()->remove(_entity);


        // If this was a glTF asset instance, we need to destroy it
        if (_newInstance) {
            for(int i =0 ; i < _newInstance->getEntityCount(); i++) {
                auto entity =_newInstance->getEntities()[i];
                _sceneManager->getScene()->remove(entity);
                rm.destroy(entity);
            }
        } 

        tm.destroy(_entity);

        _engine->destroy(_highlightMaterialInstance);

      // Destroy the entity
      utils::EntityManager::get().destroy(_entity);


    }


}