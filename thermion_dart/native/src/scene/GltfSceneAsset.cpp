
#include "scene/GltfSceneAsset.hpp"
#include "scene/GltfSceneAssetInstance.hpp"
#include "gltfio/FilamentInstance.h"
#include "Log.hpp"

#include <memory>
#include <vector>

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/Animator.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/MaterialProvider.h>

#include <utils/NameComponentManager.h>

#include "scene/GltfSceneAssetInstance.hpp"
#include "components/CollisionComponentManager.hpp"

#include "scene/SceneAsset.hpp"

namespace thermion
{

    GltfSceneAsset::GltfSceneAsset(
        gltfio::FilamentAsset *asset,
        gltfio::AssetLoader *assetLoader,
        Engine *engine,
        utils::NameComponentManager* ncm,
        MaterialInstance **materialInstances,
        size_t materialInstanceCount,
        int instanceIndex) : _asset(asset),
                                  _assetLoader(assetLoader),
                                  _engine(engine),
                                  _ncm(ncm),
                                  _materialInstances(materialInstances),
                                  _materialInstanceCount(materialInstanceCount)
    {
        createInstance();
        TRACE("Created GltfSceneAsset from FilamentAsset %d with %d reserved instances", asset, asset->getAssetInstanceCount());
    }

    GltfSceneAsset::~GltfSceneAsset()
    {
        _instances.clear();
        _asset->releaseSourceData();
        _assetLoader->destroyAsset(_asset);    
    }

    void GltfSceneAsset::destroyInstance(SceneAsset *asset) {
        for(auto& instance : _instances) {
            if(instance.get() == asset) {
                instance->inUse = false;      
                return;  
            }
        }
    };


    SceneAsset *GltfSceneAsset::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {

        // first, see if we can recycled any "unused" instances.
        for(auto &instance : _instances) {
            if(!instance->inUse) {
                instance->inUse = true;
                return instance.get();
            }
        }

        if(_instances.size() == _asset->getAssetInstanceCount())
        {
            TRACE("Warning: %d pre-allocated instances already consumed. A new instance will be allocated internally, but in future you may wish to pre-allocate a larger number.",
                _asset->getAssetInstanceCount() 
            );
            _assetLoader->createInstance(_asset);
        } else {
            TRACE("Returning pre-allocated instance at index %d", _instances.size());
        }
        
        auto instance = _asset->getAssetInstances()[_instances.size()];
        
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
                    for(int j = 0; j < materialInstanceCount; j++) {
                        rm.setMaterialInstanceAt(renderableInstance, i, materialInstances[j]);
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