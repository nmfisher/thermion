#include "scene/GltfSceneAssetInstance.hpp"
#include "scene/GltfSceneAsset.hpp"


namespace thermion
{

    GltfSceneAssetInstance::~GltfSceneAssetInstance()
    {
        
    }

    SceneAsset *GltfSceneAssetInstance::getInstanceOwner() { 
        return static_cast<SceneAsset *>(_instanceOwner);
    }

    
}