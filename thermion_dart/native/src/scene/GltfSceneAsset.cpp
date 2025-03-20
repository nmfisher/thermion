
#include "scene/GltfSceneAsset.hpp"
#include "scene/GltfSceneAssetInstance.hpp"
#include "gltfio/FilamentInstance.h"
#include "Log.hpp"
namespace thermion
{

    GltfSceneAsset::~GltfSceneAsset()
    {
        _instances.clear();
        _asset->releaseSourceData();
        _assetLoader->destroyAsset(_asset);    
        TRACE("Destroyed");
    }

    SceneAsset *GltfSceneAsset::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {
        auto instanceNumber = _instances.size();
        
        if (instanceNumber > _asset->getAssetInstanceCount() - 1)
        {
            Log("glTF asset was created with %d instances reserved, and %d instances have been used. Increase the number of instances pre-allocated when the asset is loaded.",
            _asset->getAssetInstanceCount(), _instances.size()
            );
            return std::nullptr_t();
        }
        TRACE("Creating instance %d", instanceNumber);
        auto instance = _asset->getAssetInstances()[instanceNumber];
        
        instance->recomputeBoundingBoxes();
        auto bb = instance->getBoundingBox();
        TRACE("Instance bounding box center (%f,%f,%f), extent (%f,%f,%f)", bb.center().x, bb.center().y, bb.center().z, bb.extent().x,bb.extent().y,bb.extent().z);
        instance->getAnimator()->updateBoneMatrices();

        auto& rm = _engine->getRenderableManager();

        if(materialInstanceCount > 0) {
            
            TRACE("Instance entity count : %d", instance->getEntityCount());

            for(int i = 0; i < instance->getEntityCount(); i++) {
                auto renderableInstance = rm.getInstance(instance->getEntities()[i]);
                if(!renderableInstance.isValid()) {
                    TRACE("Instance child entity %d not renderable", i);
                } else {
                    TRACE("Instance child entity %d renderable", i);
                    for(int i = 0; i < materialInstanceCount; i++) {
                        rm.setMaterialInstanceAt(renderableInstance, i, materialInstances[i]);
                    }
                }                
            }
        }

        std::unique_ptr<GltfSceneAssetInstance> sceneAssetInstance = std::make_unique<GltfSceneAssetInstance>(
            this,
            instance,
            _engine,
            _ncm,
            materialInstances, 
            materialInstanceCount
        );

        auto *raw = sceneAssetInstance.get();

        _instances.push_back(std::move(sceneAssetInstance));
        return raw;
    }

    


}