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

    uint32_t GltfSceneAssetInstance::getGeometryCapabilities() const
    {
        return _instanceOwner->getGeometryCapabilities();
    }

    bool GltfSceneAssetInstance::supportsFlatShading() const
    {
        return _instanceOwner->supportsFlatShading();
    }

    TVertexBufferStorageMode GltfSceneAssetInstance::getVertexBufferStorageMode(size_t primitiveIndex) const
    {
        return _instanceOwner->getVertexBufferStorageMode(primitiveIndex);
    }

    size_t GltfSceneAssetInstance::getBoneCount(size_t skinIndex) const
    {
        return _instance->getJointCountAt(skinIndex);
    }

    const utils::Entity *GltfSceneAssetInstance::getBones(size_t skinIndex) const
    {
        return _instance->getJointsAt(skinIndex);
    }

    const char *GltfSceneAssetInstance::getBoneName(size_t skinIndex, size_t boneIndex) const {
        auto boneCount = getBoneCount(skinIndex);
        if(boneIndex >= boneCount) {
            ERROR("Requested bone index %d greater than bone count %d", boneIndex, boneCount);
            return nullptr;
        }
        auto bone = _instance->getJointsAt(skinIndex)[boneIndex];
        auto ci = _ncm->getInstance(bone);
        if(!ci.isValid()) {
            ERROR("Requested bone at index %d has no name component", boneIndex);
            return nullptr;
        }
        return _ncm->getName(ci);
    }

}
