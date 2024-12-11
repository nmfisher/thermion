
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
    }

    SceneAsset *GltfSceneAsset::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {
        auto instanceNumber = _instances.size();
        
        if (instanceNumber > _asset->getAssetInstanceCount() - 1)
        {
            Log("No instances available for reuse. When loading the asset, you must pre-allocate the number of instances you wish to make available for use. Try increasing this number.");
            return std::nullptr_t();
        }
        Log("Creating instance %d", instanceNumber);
        auto instance = _asset->getAssetInstances()[instanceNumber];
        instance->recomputeBoundingBoxes();
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
            instance,
            _engine,
            materialInstances, 
            materialInstanceCount
        );

        auto *raw = sceneAssetInstance.get();

        _instances.push_back(std::move(sceneAssetInstance));
        return raw;
    }

    


}