#include <string>
#include <sstream>
#include <thread>
#include <vector>
#include <unordered_set>
#include <stack>

#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>
#include <filament/RenderableManager.h>

#include <utils/EntityManager.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>
#include <gltfio/math.h>

#include <imageio/ImageDecoder.h>

#include "material/FileMaterialProvider.hpp"
#include "StreamBufferAdapter.hpp"
#include "Log.hpp"
#include "SceneManager.hpp"

#include "gltfio/materials/uberarchive.h"

extern "C"
{
#include "material/image.h"
}

namespace thermion_filament
{

    using namespace std::chrono;
    using namespace image;
    using namespace utils;
    using namespace filament;
    using namespace filament::gltfio;
    using std::unique_ptr;

    SceneManager::SceneManager(const ResourceLoaderWrapperImpl *const resourceLoaderWrapper,
                               Engine *engine,
                               Scene *scene,
                               const char *uberArchivePath)
        : _resourceLoaderWrapper(resourceLoaderWrapper),
          _engine(engine),
          _scene(scene)
    {

        _stbDecoder = createStbProvider(_engine);
        _ktxDecoder = createKtx2Provider(_engine);

        _gltfResourceLoader = new ResourceLoader({.engine = _engine,
                                                  .normalizeSkinningWeights = true});
        if (uberArchivePath)
        {
            auto uberdata = resourceLoaderWrapper->load(uberArchivePath);
            if (!uberdata.data)
            {
                Log("Failed to load ubershader material. This is fatal.");
            }
            _ubershaderProvider = gltfio::createUbershaderProvider(_engine, uberdata.data, uberdata.size);
            resourceLoaderWrapper->free(uberdata);
        }
        else
        {
            _ubershaderProvider = gltfio::createUbershaderProvider(
                _engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);
        }

        utils::EntityManager &em = utils::EntityManager::get();

        _ncm = new NameComponentManager(em);
        
        _assetLoader = AssetLoader::create({_engine, _ubershaderProvider, _ncm, &em});
    
        _gltfResourceLoader->addTextureProvider("image/ktx2", _ktxDecoder);
        _gltfResourceLoader->addTextureProvider("image/png", _stbDecoder);
        _gltfResourceLoader->addTextureProvider("image/jpeg", _stbDecoder);

        auto &tm = _engine->getTransformManager();

        _collisionComponentManager = new CollisionComponentManager(tm);
        _animationComponentManager = new AnimationComponentManager(tm, _engine->getRenderableManager());
        
        addGizmo();
    }

    SceneManager::~SceneManager()
    {
        
        destroyAll();
        
        for(int i =0; i < 3; i++) {
            _engine->destroy(_gizmo[i]);
            _engine->destroy(_gizmoMaterialInstances[i]);
        }
        
        _engine->destroy(_gizmoMaterial);
        _gltfResourceLoader->asyncCancelLoad();
        _ubershaderProvider->destroyMaterials();
        
        delete _animationComponentManager;
        delete _collisionComponentManager;
        delete _ncm;

        delete _gltfResourceLoader;
        delete _stbDecoder;
        delete _ktxDecoder;
        delete _ubershaderProvider;
        AssetLoader::destroy(&_assetLoader);
        
    }

    int SceneManager::getInstanceCount(EntityId entityId)
    {
        auto *asset = getAssetByEntityId(entityId);
        if (!asset)
        {
            return -1;
        }

        return asset->getAssetInstanceCount();
    }

    void SceneManager::getInstances(EntityId entityId, EntityId *out)
    {
        auto *asset = getAssetByEntityId(entityId);
        if (!asset)
        {
            return;
        }
        auto *instances = asset->getAssetInstances();
        for (int i = 0; i < asset->getAssetInstanceCount(); i++)
        {
            auto instanceEntity = instances[i]->getRoot();
            out[i] = Entity::smuggle(instanceEntity);
        }
    }

    EntityId SceneManager::loadGltf(const char *uri,
                                    const char *relativeResourcePath)
    {
        ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);

        FilamentAsset *asset = _assetLoader->createAsset((uint8_t *)rbuf.data, rbuf.size);

        if (!asset)
        {
            Log("Unable to parse asset");
            return 0;
        }

        const char *const *const resourceUris = asset->getResourceUris();
        const size_t resourceUriCount = asset->getResourceUriCount();

        std::vector<ResourceBuffer> resourceBuffers;

        for (size_t i = 0; i < resourceUriCount; i++)
        {
            std::string uri = std::string(relativeResourcePath) + std::string("/") + std::string(resourceUris[i]);
            Log("Loading resource URI from relative path %s", resourceUris[i], uri.c_str());
            ResourceBuffer buf = _resourceLoaderWrapper->load(uri.c_str());

            resourceBuffers.push_back(buf);

            ResourceLoader::BufferDescriptor b(buf.data, buf.size);
            _gltfResourceLoader->addResourceData(resourceUris[i], std::move(b));
        }

#ifdef __EMSCRIPTEN__
        if (!_gltfResourceLoader->asyncBeginLoad(asset))
        {
            Log("Unknown error loading glTF asset");
            _resourceLoaderWrapper->free(rbuf);
            for (auto &rb : resourceBuffers)
            {
                _resourceLoaderWrapper->free(rb);
            }
            return 0;
        }
        while (_gltfResourceLoader->asyncGetLoadProgress() < 1.0f)
        {
            _gltfResourceLoader->asyncUpdateLoad();
        }
#else
        // load resources synchronously
        if (!_gltfResourceLoader->loadResources(asset))
        {
            Log("Unknown error loading glTF asset");
            _resourceLoaderWrapper->free(rbuf);
            for (auto &rb : resourceBuffers)
            {
                _resourceLoaderWrapper->free(rb);
            }
            return 0;
        }
#endif

        _scene->addEntities(asset->getEntities(), asset->getEntityCount());

        FilamentInstance *inst = asset->getInstance();
        inst->getAnimator()->updateBoneMatrices();
        inst->recomputeBoundingBoxes();

        asset->releaseSourceData();

        EntityId eid = Entity::smuggle(asset->getRoot());

        _assets.emplace(eid, asset);

        for (auto &rb : resourceBuffers)
        {
            _resourceLoaderWrapper->free(rb);
        }
        _resourceLoaderWrapper->free(rbuf);

        Log("Finished loading glTF from %s", uri);

        return eid;
    }

    EntityId SceneManager::loadGlbFromBuffer(const uint8_t *data, size_t length, int numInstances)
    {

        Log("Loading GLB from buffer of length %d", length);

        FilamentAsset *asset = nullptr;
        if (numInstances > 1)
        {
            std::vector<FilamentInstance *> instances(numInstances);
            asset = _assetLoader->createInstancedAsset((const uint8_t *)data, length, instances.data(), numInstances);
        }
        else
        {
            asset = _assetLoader->createAsset(data, length);
        }

        if (!asset)
        {
            Log("Unknown error loading GLB asset.");
            return 0;
        }

        size_t entityCount = asset->getEntityCount();

        _scene->addEntities(asset->getEntities(), entityCount);

#ifdef __EMSCRIPTEN__
        if (!_gltfResourceLoader->asyncBeginLoad(asset))
        {
            Log("Unknown error loading glb asset");
            return 0;
        }
        while (_gltfResourceLoader->asyncGetLoadProgress() < 1.0f)
        {
            _gltfResourceLoader->asyncUpdateLoad();
        }
#else
        if (!_gltfResourceLoader->loadResources(asset))
        {
            Log("Unknown error loading glb asset");
            return 0;
        }
#endif

        auto lights = asset->getLightEntities();
        _scene->addEntities(lights, asset->getLightEntityCount());

        for (int i = 0; i < asset->getAssetInstanceCount(); i++)
        {
            FilamentInstance *inst = asset->getAssetInstances()[i];
            inst->getAnimator()->updateBoneMatrices();
            inst->recomputeBoundingBoxes();
            auto instanceEntity = inst->getRoot();
            auto instanceEntityId = Entity::smuggle(instanceEntity);
            _instances.emplace(instanceEntityId, inst);
        }

        asset->releaseSourceData();

        EntityId eid = Entity::smuggle(asset->getRoot());
        _assets.emplace(eid, asset);
        return eid;
    }

    void SceneManager::removeAnimationComponent(EntityId entityId)
    {

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
        }

        if (instance)
        {
            _animationComponentManager->removeAnimationComponent(instance);
        }
        else
        {
            _animationComponentManager->removeAnimationComponent(Entity::import(entityId));
        }
    }

    bool SceneManager::addAnimationComponent(EntityId entityId)
    {

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
        }

        if (instance)
        {
            _animationComponentManager->addAnimationComponent(instance);
        }
        else
        {
            _animationComponentManager->addAnimationComponent(Entity::import(entityId));
        }
        return true;
    }

    EntityId SceneManager::createInstance(EntityId entityId)
    {
        std::lock_guard lock(_mutex);

        const auto &pos = _assets.find(entityId);
        if (pos == _assets.end())
        {
            Log("Couldn't find asset under specified entity id.");
            return false;
        }
        const auto asset = pos->second;
        auto instance = _assetLoader->createInstance(asset);

        return Entity::smuggle(instance->getRoot());
    }

    EntityId SceneManager::loadGlb(const char *uri, int numInstances)
    {
        ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);
        auto entity = loadGlbFromBuffer((const uint8_t *)rbuf.data, rbuf.size, numInstances);
        _resourceLoaderWrapper->free(rbuf);
        return entity;
    }

    bool SceneManager::hide(EntityId entityId, const char *meshName)
    {
        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                // Log("Failed to find glTF instance under entityID %d, hiding as regular entity", entityId);
                _scene->remove(Entity::import(entityId));
                return true;
            }
        }

        utils::Entity entity;

        if (meshName)
        {
            entity = findEntityByName(instance, meshName);
            if (entity.isNull())
            {
                Log("Failed to hide entity; specified mesh name does not exist under the target entity, or the target entity itself is no longer valid.");
                return false;
            }
            _scene->remove(entity);
        }
        else
        {
            auto *entities = instance->getEntities();
            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                auto entity = entities[i];
                _scene->remove(entity);
            }
        }

        return true;
    }

    bool SceneManager::reveal(EntityId entityId, const char *meshName)
    {
        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                // Log("Failed to find glTF instance under entityID %d, revealing as regular entity", entityId);
                _scene->addEntity(Entity::import(entityId));
                return true;
            }
        }

        utils::Entity entity;

        if (meshName)
        {
            entity = findEntityByName(instance, meshName);
            if (entity.isNull())
            {
                Log("Failed to reveal entity; specified mesh name does not exist under the target entity, or the target entity itself is no longer valid.");
                return false;
            }
            _scene->addEntity(entity);
        }
        else
        {
            // Log("Revealing all child entities");
            auto *entities = instance->getEntities();
            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                auto entity = entities[i];
                _scene->addEntity(entity);
            }
        }

        return true;
    }

    void SceneManager::destroyAll()
    {
        std::lock_guard lock(_mutex);

        for (auto &asset : _assets)
        {
            auto numInstances = asset.second->getAssetInstanceCount();
            for(int i = 0; i < numInstances; i++) {
                auto instance = asset.second->getAssetInstances()[i];
                for (int j = 0; j < instance->getEntityCount(); j++)
                {
                    auto childEntity = instance->getEntities()[j];
                    if (_collisionComponentManager->hasComponent(childEntity))
                    {
                        _collisionComponentManager->removeComponent(childEntity);
                    }
                    if (_animationComponentManager->hasComponent(childEntity))
                    {
                        _animationComponentManager->removeComponent(childEntity);
                    }
                }
            }

            _scene->removeEntities(asset.second->getEntities(),
                                   asset.second->getEntityCount());
            _scene->removeEntities(asset.second->getLightEntities(),
                                   asset.second->getLightEntityCount());
            _assetLoader->destroyAsset(asset.second);
        }
        _assets.clear();
    }

    FilamentInstance *SceneManager::getInstanceByEntityId(EntityId entityId)
    {
        const auto &pos = _instances.find(entityId);
        if (pos == _instances.end())
        {
            return nullptr;
        }
        return pos->second;
    }

    FilamentAsset *SceneManager::getAssetByEntityId(EntityId entityId)
    {
        const auto &pos = _assets.find(entityId);
        if (pos == _assets.end())
        {
            return nullptr;
        }
        return pos->second;
    }

    math::mat4f SceneManager::getLocalTransform(EntityId entityId) {
        auto entity = Entity::import(entityId);
        auto& tm = _engine->getTransformManager();
        auto transformInstance = tm.getInstance(entity);        
        return tm.getTransform(transformInstance);
    }

    math::mat4f SceneManager::getWorldTransform(EntityId entityId) {
        auto entity = Entity::import(entityId);
        auto& tm = _engine->getTransformManager();
        auto transformInstance = tm.getInstance(entity);        
        return tm.getWorldTransform(transformInstance);
    }

    EntityId SceneManager::getBone(EntityId entityId, int skinIndex, int boneIndex) { 
        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                Log("Failed to find glTF instance under entityID %d, revealing as regular entity", entityId);
                return false;
            }
        }
        auto joints = instance->getJointsAt(skinIndex);
        auto joint = joints[boneIndex];
        return Entity::smuggle(joint);
    }

    math::mat4f SceneManager::getInverseBindMatrix(EntityId entityId, int skinIndex, int boneIndex) { 
        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                Log("Failed to find glTF instance under entityID %d, revealing as regular entity", entityId);
                return math::mat4f();
            }
        }
        auto inverseBindMatrix = instance->getInverseBindMatricesAt(skinIndex)[boneIndex];
        return inverseBindMatrix;
    }


    bool SceneManager::setBoneTransform(EntityId entityId, int32_t skinIndex, int boneIndex, math::mat4f transform)
    {
        std::lock_guard lock(_mutex);

        const auto &entity = Entity::import(entityId);

        RenderableManager &rm = _engine->getRenderableManager();

        const auto &renderableInstance = rm.getInstance(entity);

        if (!renderableInstance.isValid())
        {
            Log("Specified entity is not a renderable. You probably provided the ultimate parent entity of a glTF asset, which is non-renderable. ");
            return false;
        }

        rm.setBones(
            renderableInstance,
            &transform,
            1,
            boneIndex);
        return true;
    }

    void SceneManager::remove(EntityId entityId)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);

        if (_animationComponentManager->hasComponent(entity))
        {
            _animationComponentManager->removeComponent(entity);
        }

        if (_collisionComponentManager->hasComponent(entity))
        {
            _collisionComponentManager->removeComponent(entity);
        }

        _scene->remove(entity);

        const auto *instance = getInstanceByEntityId(entityId);

        if (instance)
        {
            _instances.erase(entityId);
            _scene->removeEntities(instance->getEntities(), instance->getEntityCount());
            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                auto childEntity = instance->getEntities()[i];
                if (_collisionComponentManager->hasComponent(childEntity))
                {
                    _collisionComponentManager->removeComponent(childEntity);
                }
                if (_animationComponentManager->hasComponent(childEntity))
                {
                    _animationComponentManager->removeComponent(childEntity);
                }
            }
        }
        else
        {
            auto *asset = getAssetByEntityId(entityId);

            if (!asset)
            {
                Log("ERROR: could not find FilamentInstance or FilamentAsset associated with the given entity id");
                return;
            }
            _assets.erase(entityId);

            _scene->removeEntities(asset->getEntities(), asset->getEntityCount());

            _animationComponentManager->removeComponent(asset->getInstance()->getRoot());

            for (int i = 0; i < asset->getEntityCount(); i++)
            {
                auto childEntity = asset->getEntities()[i];
                if (_collisionComponentManager->hasComponent(childEntity))
                {
                    _collisionComponentManager->removeComponent(childEntity);
                }
                if (_animationComponentManager->hasComponent(childEntity))
                {
                    _animationComponentManager->removeComponent(childEntity);
                }
            }

            auto lightCount = asset->getLightEntityCount();
            if (lightCount > 0)
            {
                _scene->removeEntities(asset->getLightEntities(),
                                       asset->getLightEntityCount());
            }
            _assetLoader->destroyAsset(asset);
        }
    }

    bool SceneManager::setMorphTargetWeights(EntityId entityId, const float *const weights, const int count)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);
        if (entity.isNull())
        {
            Log("Warning: null entity %d", entityId);
            return false;
        }

        RenderableManager &rm = _engine->getRenderableManager();

        auto renderableInstance = rm.getInstance(entity);

        if (!renderableInstance.isValid())
        {
            Log("Warning: failed to find a valid renderable instance for child entity %d", entityId);
            return false;
        }

        rm.setMorphWeights(
            renderableInstance,
            weights,
            count);
        return true;
    }

    utils::Entity SceneManager::findChildEntityByName(EntityId entityId, const char *entityName)
    {
        std::lock_guard lock(_mutex);

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (!asset)
            {
                return utils::Entity();
            }
            instance = asset->getInstance();
        }

        const auto entity = findEntityByName(instance, entityName);

        if (entity.isNull())
        {
            Log("Failed to find entity %s.", entityName);
        }

        return entity;
    }

    utils::Entity SceneManager::findEntityByName(const FilamentInstance *instance, const char *entityName)
    {
        utils::Entity entity;
        for (size_t i = 0, c = instance->getEntityCount(); i != c; ++i)
        {
            auto entity = instance->getEntities()[i];
            auto nameInstance = _ncm->getInstance(entity);
            if (!nameInstance.isValid())
            {
                continue;
            }
            auto name = _ncm->getName(nameInstance);
            if (!name)
            {
                continue;
            }
            if (strcmp(entityName, name) == 0)
            {
                return entity;
            }
        }
        return entity;
    }

    bool SceneManager::setMorphAnimationBuffer(
        EntityId entityId,
        const float *const morphData,
        const int *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);

        if (entity.isNull())
        {
            Log("ERROR: invalid entity %d.", entityId);
            return false;
        }

        if (!_animationComponentManager->hasComponent(entity))
        {
            _animationComponentManager->addAnimationComponent(entity);
        }

        MorphAnimation morphAnimation;

        morphAnimation.meshTarget = entity;
        morphAnimation.frameData.clear();
        morphAnimation.frameData.insert(
            morphAnimation.frameData.begin(),
            morphData,
            morphData + (numFrames * numMorphTargets));
        morphAnimation.frameLengthInMs = frameLengthInMs;
        morphAnimation.morphIndices.resize(numMorphTargets);
        for (int i = 0; i < numMorphTargets; i++)
        {
            morphAnimation.morphIndices[i] = morphIndices[i];
        }
        morphAnimation.durationInSecs = (frameLengthInMs * numFrames) / 1000.0f;

        morphAnimation.start = high_resolution_clock::now();
        morphAnimation.lengthInFrames = static_cast<int>(
            morphAnimation.durationInSecs * 1000.0f /
            frameLengthInMs);

        auto animationComponentInstance = _animationComponentManager->getInstance(entity);
        auto &animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);
        auto &morphAnimations = animationComponent.morphAnimations;

        morphAnimations.emplace_back(morphAnimation);
        return true;
    }

     void SceneManager::clearMorphAnimationBuffer(
        EntityId entityId)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);

        if (entity.isNull())
        {
            Log("ERROR: invalid entity %d.", entityId);
            return;
        }

        auto animationComponentInstance = _animationComponentManager->getInstance(entity);
        auto &animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);
        auto &morphAnimations = animationComponent.morphAnimations;

        morphAnimations.clear();
        return;
    }

    bool SceneManager::setMaterialColor(EntityId entityId, const char *meshName, int materialIndex, const float r, const float g, const float b, const float a)
    {

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return false;
            }
        }

        auto entity = findEntityByName(instance, meshName);

        RenderableManager &rm = _engine->getRenderableManager();

        auto renderable = rm.getInstance(entity);

        if (!renderable.isValid())
        {
            Log("Renderable not valid, was the entity id correct?");
            return false;
        }

        MaterialInstance *mi = rm.getMaterialInstanceAt(renderable, materialIndex);

        if (!mi)
        {
            Log("ERROR: material index must be less than number of material instances");
            return false;
        }
        mi->setParameter("baseColorFactor", RgbaType::sRGB, math::float4(r, g, b, a));
        Log("Set baseColorFactor for entity %d to %f %f %f %f", entityId, r, g, b, a);
        return true;
    }

    void SceneManager::resetBones(EntityId entityId)
    {
        std::lock_guard lock(_mutex);

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return;
            }
        }
        auto skinCount = instance->getSkinCount();

        TransformManager &transformManager = _engine->getTransformManager();

        //
        // To reset the skeleton to its rest pose, we could just call animator->resetBoneMatrices(), 
        // which sets all bone matrices to the identity matrix. However, any subsequent calls to animator->updateBoneMatrices() 
        // may result in unexpected poses, because that method uses each bone's transform to calculate 
        // the bone matrices (and resetBoneMatrices does not affect this transform).
        // To "fully" reset the bone, we need to set its local transform (i.e. relative to its parent)
        // to its original orientation in rest pose. 
        //
        // This can be calculated as:
        //
        //   auto rest = inverse(parentTransformInModelSpace) * bindMatrix
        //
        // (where bindMatrix is the inverse of the inverseBindMatrix).
        //
        // The only requirement is that parent bone transforms are reset before child bone transforms.
        // glTF/Filament does not guarantee that parent bones are listed before child bones under a FilamentInstance. 
        // We ensure that parents are reset before children by:
        // - pushing all bones onto a stack
        // - iterate over the stack
        //      - look at the bone at the top of the stack
        //      - if the bone already been reset, pop and continue iterating over the stack
        //      - otherwise
        //          - if the bone has a parent that has not been reset, push the parent to the top of the stack and continue iterating
        //          - otherwise
        //              - pop the bone, reset its transform and mark it as completed
        for (int skinIndex = 0; skinIndex < skinCount; skinIndex++)
        {
            std::unordered_set<Entity,Entity::Hasher> joints;
            std::unordered_set<Entity,Entity::Hasher> completed;
            std::stack<Entity> stack;

            auto transforms = getBoneRestTranforms(entityId, skinIndex);
            
            for (int i = 0; i < instance->getJointCountAt(skinIndex); i++)
            {
                auto restTransform = transforms->at(i);
                const auto& joint = instance->getJointsAt(skinIndex)[i];
                auto transformInstance = transformManager.getInstance(joint);
                transformManager.setTransform(transformInstance, restTransform);
            }
        }
        instance->getAnimator()->updateBoneMatrices();
    }

    std::unique_ptr<std::vector<math::mat4f>> SceneManager::getBoneRestTranforms(EntityId entityId, int skinIndex) {

        auto transforms = std::make_unique<std::vector<math::mat4f>>();

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return transforms;
            }
        }

        auto skinCount = instance->getSkinCount();

        TransformManager &transformManager = _engine->getTransformManager();

        transforms->resize(instance->getJointCountAt(skinIndex));

        //
        // To reset the skeleton to its rest pose, we could just call animator->resetBoneMatrices(), 
        // which sets all bone matrices to the identity matrix. However, any subsequent calls to animator->updateBoneMatrices() 
        // may result in unexpected poses, because that method uses each bone's transform to calculate 
        // the bone matrices (and resetBoneMatrices does not affect this transform).
        // To "fully" reset the bone, we need to set its local transform (i.e. relative to its parent)
        // to its original orientation in rest pose. 
        //
        // This can be calculated as:
        //
        //   auto rest = inverse(parentTransformInModelSpace) * bindMatrix
        //
        // (where bindMatrix is the inverse of the inverseBindMatrix).
        //
        // The only requirement is that parent bone transforms are reset before child bone transforms.
        // glTF/Filament does not guarantee that parent bones are listed before child bones under a FilamentInstance. 
        // We ensure that parents are reset before children by:
        // - pushing all bones onto a stack
        // - iterate over the stack
        //      - look at the bone at the top of the stack
        //      - if the bone already been reset, pop and continue iterating over the stack
        //      - otherwise
        //          - if the bone has a parent that has not been reset, push the parent to the top of the stack and continue iterating
        //          - otherwise
        //              - pop the bone, reset its transform and mark it as completed
        std::vector<Entity> joints;
        std::unordered_set<Entity,Entity::Hasher> completed;
        std::stack<Entity> stack;
        
        for (int i = 0; i < instance->getJointCountAt(skinIndex); i++)
        {
            const auto& joint = instance->getJointsAt(skinIndex)[i];
            joints.push_back(joint);
            stack.push(joint);
        }

        while(!stack.empty())
        {
            const auto& joint = stack.top();

            // if we've already handled this node previously (e.g. when we encountered it as a parent), then skip
            if(completed.find(joint) != completed.end()) {
                stack.pop();
                continue;
            }

            const auto transformInstance = transformManager.getInstance(joint);
            auto parent = transformManager.getParent(transformInstance);

            // we need to handle parent joints before handling their children 
            // therefore, if this joint has a parent that hasn't been handled yet, 
            // push the parent to the top of the stack and start the loop again
            const auto& jointIter = std::find(joints.begin(), joints.end(), joint);
            auto parentIter = std::find(joints.begin(), joints.end(), parent);

            if(parentIter != joints.end() && completed.find(parent) == completed.end()) {
                stack.push(parent);
                continue;
            }
            
            // otherwise let's get the inverse bind matrix for the joint 
            math::mat4f inverseBindMatrix;
            bool found = false;
            for (int i = 0; i < instance->getJointCountAt(skinIndex); i++)
            {
                if(instance->getJointsAt(skinIndex)[i] == joint) { 
                    inverseBindMatrix = instance->getInverseBindMatricesAt(skinIndex)[i];
                    found = true;
                    break;
                }
            }
            ASSERT_PRECONDITION(found, "Failed to find inverse bind matrix for joint %d", joint);

            // now we need to ascend back up the hierarchy to calculate the modelSpaceTransform
            math::mat4f modelSpaceTransform;
            while(parentIter != joints.end()) {
                const auto transformInstance = transformManager.getInstance(parent);
                const auto parentIndex = distance(joints.begin(), parentIter);
                const auto transform = transforms->at(parentIndex);
                modelSpaceTransform = transform * modelSpaceTransform;
                parent = transformManager.getParent(transformInstance);
                parentIter = std::find(joints.begin(), joints.end(), parent);
            }

            const auto bindMatrix = inverse(inverseBindMatrix);              
            
            const auto inverseModelSpaceTransform = inverse(modelSpaceTransform);   

            const auto jointIndex = distance(joints.begin(), jointIter);
            transforms->at(jointIndex) = inverseModelSpaceTransform * bindMatrix;
            completed.insert(joint);
            stack.pop();
        }
        return transforms;
    }

    bool SceneManager::updateBoneMatrices(EntityId entityId) {
        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return false;
            }
        }
        instance->getAnimator()->updateBoneMatrices();
        return true;
    }

    bool SceneManager::setTransform(EntityId entityId, math::mat4f transform) {
        auto& tm = _engine->getTransformManager();
        const auto& entity = Entity::import(entityId);
        auto transformInstance = tm.getInstance(entity);
        if(!transformInstance) { 
            return false;
        }
        tm.setTransform(transformInstance, transform);
        return true;
    }

    bool SceneManager::addBoneAnimation(EntityId parentEntity,
                                        int skinIndex,
                                        int boneIndex,                      
                                        const float *const frameData,
                                        int numFrames,
                                        float frameLengthInMs,
                                        float fadeOutInSecs, 
                                        float fadeInInSecs,
                                        float maxDelta)
    {
        std::lock_guard lock(_mutex);

        auto *instance = getInstanceByEntityId(parentEntity);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(parentEntity);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return false;
            }
        }

        BoneAnimation animation;
        animation.boneIndex = boneIndex;
        animation.frameData.clear();

        const auto &inverseBindMatrix = instance->getInverseBindMatricesAt(skinIndex)[boneIndex];

        for (int i = 0; i < numFrames; i++)
        {
            math::mat4f frame(
                frameData[i * 16],
                frameData[(i * 16) + 1],
                frameData[(i * 16) + 2],
                frameData[(i * 16) + 3],
                frameData[(i * 16) + 4],
                frameData[(i * 16) + 5],
                frameData[(i * 16) + 6],
                frameData[(i * 16) + 7],
                frameData[(i * 16) + 8],
                frameData[(i * 16) + 9],
                frameData[(i * 16) + 10],
                frameData[(i * 16) + 11],
                frameData[(i * 16) + 12],
                frameData[(i * 16) + 13],
                frameData[(i * 16) + 14],
                frameData[(i * 16) + 15]);

            animation.frameData.push_back(frame);
        }

        animation.frameLengthInMs = frameLengthInMs;
        animation.start = std::chrono::high_resolution_clock::now();
        animation.reverse = false;
        animation.durationInSecs = (frameLengthInMs * numFrames) / 1000.0f;
        animation.lengthInFrames = numFrames;
        animation.frameLengthInMs = frameLengthInMs;
        animation.fadeOutInSecs = fadeOutInSecs;
        animation.fadeInInSecs = fadeInInSecs;
        animation.maxDelta = maxDelta;
        animation.skinIndex = skinIndex;
        if(!_animationComponentManager->hasComponent(instance->getRoot())) { 
            Log("ERROR: specified entity is not animatable (has no animation component attached).");
            return false;
        }
        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());

        auto &animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);
        auto &boneAnimations = animationComponent.boneAnimations;

        boneAnimations.emplace_back(animation);

        return true;
    }
 
    void SceneManager::playAnimation(EntityId entityId, int index, bool loop, bool reverse, bool replaceActive, float crossfade, float startOffset)
    {
        std::lock_guard lock(_mutex);

        if (index < 0)
        {
            Log("ERROR: glTF animation index must be greater than zero.");
            return;
        }

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return;
            }
        }

    if (!_animationComponentManager->hasComponent(instance->getRoot()))
        {
            Log("ERROR: specified entity is not animatable (has no animation component attached).");
            return;
        }

        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());

        auto &animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);

        if (replaceActive)
        {
            if (animationComponent.gltfAnimations.size() > 0)
            {
                auto &last = animationComponent.gltfAnimations.back();
                animationComponent.fadeGltfAnimationIndex = last.index;
                animationComponent.fadeDuration = crossfade;
                auto now = high_resolution_clock::now();
                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last.start).count()) / 1000.0f;
                animationComponent.fadeOutAnimationStart = elapsedInSecs;
                animationComponent.gltfAnimations.clear();
            }
            else
            {
                animationComponent.fadeGltfAnimationIndex = -1;
                animationComponent.fadeDuration = 0.0f;
            }
        }
        else if (crossfade > 0)
        {
            Log("ERROR: crossfade only supported when replaceActive is true.");
            return;
        }
        else
        {
            animationComponent.fadeGltfAnimationIndex = -1;
            animationComponent.fadeDuration = 0.0f;
        }

        GltfAnimation animation;
        animation.startOffset = startOffset;
        animation.index = index;
        animation.start = std::chrono::high_resolution_clock::now();
        animation.loop = loop;
        animation.reverse = reverse;
        animation.durationInSecs = instance->getAnimator()->getAnimationDuration(index);

        bool found = false;

        // don't play the animation if it's already running
        for(int i=0; i < animationComponent.gltfAnimations.size(); i++) {
            if(animationComponent.gltfAnimations[i].index == index) { 
                found = true;
                break;
            }
        }
        if(!found) {
            animationComponent.gltfAnimations.push_back(animation);
        }
    }

    void SceneManager::stopAnimation(EntityId entityId, int index)
    {
        std::lock_guard lock(_mutex);

        auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto *asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                Log("Failed to find instance for entity");
                return;
            }
        }

        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());
        auto &animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);

        auto erased = std::remove_if(animationComponent.gltfAnimations.begin(),
                                                               animationComponent.gltfAnimations.end(),
                                                               [=](GltfAnimation &anim)
                                                               { return anim.index == index; });
        animationComponent.gltfAnimations.erase(erased,
                                                animationComponent.gltfAnimations.end());
    }

    void SceneManager::loadTexture(EntityId entity, const char *resourcePath, int renderableIndex)
    {

        // const auto &pos = _instances.find(entity);
        // if (pos == _instances.end())
        // {
        //     Log("ERROR: asset not found for entity.");
        //     return;
        // }
        // const auto *instance = pos->second;

        // Log("Loading texture at %s for renderableIndex %d", resourcePath, renderableIndex);

        // string rp(resourcePath);

        // if (asset.texture)
        // {
        //     _engine->destroy(asset.texture);
        //     asset.texture = nullptr;
        // }

        // ResourceBuffer imageResource = _resourceLoaderWrapper->load(rp.c_str());

        // StreamBufferAdapter sb((char *)imageResource.data, (char *)imageResource.data + imageResource.size);

        // istream *inputStream = new std::istream(&sb);

        // LinearImage *image = new LinearImage(ImageDecoder::decode(
        //     *inputStream, rp.c_str(), ImageDecoder::ColorSpace::SRGB));

        // if (!image->isValid())
        // {
        //     Log("Invalid image : %s", rp.c_str());
        //     delete inputStream;
        //     _resourceLoaderWrapper->free(imageResource);
        //     return;
        // }

        // uint32_t channels = image->getChannels();
        // uint32_t w = image->getWidth();
        // uint32_t h = image->getHeight();
        // asset.texture = Texture::Builder()
        //                      .width(w)
        //                      .height(h)
        //                      .levels(0xff)
        //                      .format(channels == 3 ? Texture::InternalFormat::RGB16F
        //                                            : Texture::InternalFormat::RGBA16F)
        //                      .sampler(Texture::Sampler::SAMPLER_2D)
        //                      .build(*_engine);

        // Texture::PixelBufferDescriptor::Callback freeCallback = [](void *buf, size_t,
        //                                                            void *data)
        // {
        //     delete reinterpret_cast<LinearImage *>(data);
        // };

        // Texture::PixelBufferDescriptor buffer(
        //     image->getPixelRef(), size_t(w * h * channels * sizeof(float)),
        //     channels == 3 ? Texture::Format::RGB : Texture::Format::RGBA,
        //     Texture::Type::FLOAT, freeCallback);

        // asset.texture->setImage(*_engine, 0, std::move(buffer));
        // MaterialInstance *const *inst = instance->getMaterialInstances();
        // size_t mic = instance->getMaterialInstanceCount();
        // Log("Material instance count : %d", mic);

        // auto sampler = TextureSampler();
        // inst[0]->setParameter("baseColorIndex", 0);
        // inst[0]->setParameter("baseColorMap", asset.texture, sampler);
        // delete inputStream;

        // _resourceLoaderWrapper->free(imageResource);
    }

    void SceneManager::setAnimationFrame(EntityId entityId, int animationIndex, int animationFrame)
    {
        auto *instance = getInstanceByEntityId(entityId);
        auto offset = 60 * animationFrame * 1000; // TODO - don't hardcore 60fps framerate
        instance->getAnimator()->applyAnimation(animationIndex, offset);
        instance->getAnimator()->updateBoneMatrices();
    }

    float SceneManager::getAnimationDuration(EntityId entity, int animationIndex)
    {
        auto *instance = getInstanceByEntityId(entity);

        if (!instance)
        {
            auto *asset = getAssetByEntityId(entity);
            if (!asset)
            {
                return -1.0f;
            }
            instance = asset->getInstance();
        }
        return instance->getAnimator()->getAnimationDuration(animationIndex);
    }

    unique_ptr<std::vector<std::string>> SceneManager::getAnimationNames(EntityId entity)
    {

        const auto &pos = _instances.find(entity);

        unique_ptr<std::vector<std::string>> names = std::make_unique<std::vector<std::string>>();

        FilamentInstance *instance;

        if (pos != _instances.end())
        {
            instance = pos->second;
        }
        else
        {
            const auto &assetPos = _assets.find(entity);
            if (assetPos != _assets.end())
            {
                instance = assetPos->second->getInstance();
            }
            else
            {
                Log("Could not resolve entity ID %d to FilamentInstance or FilamentAsset");
                return names;
            }
        }

        size_t count = instance->getAnimator()->getAnimationCount();

        for (size_t i = 0; i < count; i++)
        {
            names->push_back(instance->getAnimator()->getAnimationName(i));
        }

        return names;
    }

    unique_ptr<std::vector<std::string>> SceneManager::getMorphTargetNames(EntityId assetEntityId, EntityId child)
    {
        unique_ptr<std::vector<std::string>> names = std::make_unique<std::vector<std::string>>();

        const auto *instance = getInstanceByEntityId(assetEntityId);
        
        if (!instance)
        {
            auto asset = getAssetByEntityId(assetEntityId);
            if (!asset)
            {
                Log("Warning - failed to find specified asset. This is unexpected and probably indicates you are passing the wrong entity");
                return names;
            }
            instance = asset->getInstance();
            if(!instance) {
                Log("Warning - failed to find instance for specified asset. This is unexpected and probably indicates you are passing the wrong entity");
                return names;
            }
        }

        const auto *asset = instance->getAsset();

        const utils::Entity *entities = asset->getEntities();

        const utils::Entity target = Entity::import(child);

        for (int i = 0; i < asset->getEntityCount(); i++)
        {
            
            utils::Entity e = entities[i];
            if (e == target)
            {
                size_t count = asset->getMorphTargetCountAt(e);
                for (int j = 0; j < count; j++)
                {
                    const char *morphName = asset->getMorphTargetNameAt(e, j);
                    names->push_back(morphName);
                }
                break;
            }
        }
        return names;
    }

    unique_ptr<vector<string>> SceneManager::getBoneNames(EntityId assetEntityId, int skinIndex) {

        unique_ptr<std::vector<std::string>> names = std::make_unique<std::vector<std::string>>();

        auto *instance = getInstanceByEntityId(assetEntityId);

        if (!instance)
        {
            auto *asset = getAssetByEntityId(assetEntityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                Log("ERROR: failed to find instance for entity %d", assetEntityId);
                return names;
            }
        }

        size_t skinCount = instance->getSkinCount();

        if (skinCount > 1)
        {
            Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
        }

        size_t numJoints = instance->getJointCountAt(skinIndex);
        auto joints = instance->getJointsAt(skinIndex);
        for (int i = 0; i < numJoints; i++)
        {
            const char *jointName = _ncm->getName(_ncm->getInstance(joints[i]));
            names->push_back(jointName);
        }
        return names;
    }


    void SceneManager::transformToUnitCube(EntityId entityId)
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return;
            }
        }
        auto &tm = _engine->getTransformManager();

        auto aabb = instance->getBoundingBox();
        auto center = aabb.center();
        auto halfExtent = aabb.extent();
        auto maxExtent = max(halfExtent) * 2;
        auto scaleFactor = 2.0f / maxExtent;
        auto transform =
            math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
        tm.setTransform(tm.getInstance(instance->getRoot()), transform);
    }

    EntityId SceneManager::getParent(EntityId childEntityId) {
        auto &tm = _engine->getTransformManager();
        const auto child = Entity::import(childEntityId);
        const auto &childInstance = tm.getInstance(child);
        auto parent = tm.getParent(childInstance);
        return Entity::smuggle(parent);
    }

    void SceneManager::setParent(EntityId childEntityId, EntityId parentEntityId)
    {
        auto &tm = _engine->getTransformManager();
        const auto child = Entity::import(childEntityId);
        const auto parent = Entity::import(parentEntityId);

        const auto &parentInstance = tm.getInstance(parent);
        const auto &childInstance = tm.getInstance(child);
        tm.setParent(childInstance, parentInstance);
    }

    void SceneManager::addCollisionComponent(EntityId entityId, void (*onCollisionCallback)(const EntityId entityId1, const EntityId entityId2), bool affectsTransform)
    {
        std::lock_guard lock(_mutex);
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (!asset)
            {
                return;
            }
            else
            {
                instance = asset->getInstance();
            }
        }
        auto collisionInstance = _collisionComponentManager->addComponent(instance->getRoot());
        _collisionComponentManager->elementAt<0>(collisionInstance) = instance->getBoundingBox();
        _collisionComponentManager->elementAt<1>(collisionInstance) = onCollisionCallback;
        _collisionComponentManager->elementAt<2>(collisionInstance) = affectsTransform;
    }

    void SceneManager::removeCollisionComponent(EntityId entityId)
    {
        std::lock_guard lock(_mutex);
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (!asset)
            {
                return;
            }
            else
            {
                instance = asset->getInstance();
            }
        }
        _collisionComponentManager->removeComponent(instance->getRoot());
    }

    void SceneManager::testCollisions(EntityId entityId)
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return;
            }
        }

        const auto &tm = _engine->getTransformManager();

        auto transformInstance = tm.getInstance(instance->getRoot());
        auto worldTransform = tm.getWorldTransform(transformInstance);
        auto aabb = instance->getBoundingBox();
        aabb = aabb.transform(worldTransform);
        _collisionComponentManager->collides(instance->getRoot(), aabb);
    }

    void SceneManager::updateAnimations()
    {
        std::lock_guard lock(_mutex);
        _animationComponentManager->update();
    }

    void SceneManager::updateTransforms()
    {
        std::lock_guard lock(_mutex);

        auto &tm = _engine->getTransformManager();

        for (const auto &[entityId, transformUpdate] : _transformUpdates)
        {
            const auto &pos = _instances.find(entityId);

            bool isCollidable = true;
            Entity entity;
            filament::TransformManager::Instance transformInstance;
            filament::math::mat4f transform;
            Aabb boundingBox;
            if (pos == _instances.end())
            {
                isCollidable = false;
                entity = Entity::import(entityId);
            }
            else
            {
                const auto *instance = pos->second;
                entity = instance->getRoot();
                boundingBox = instance->getBoundingBox();
            }

            transformInstance = tm.getInstance(entity);
            transform = tm.getTransform(transformInstance);

            math::float3 newTranslation = std::get<0>(transformUpdate);
            bool newTranslationRelative = std::get<1>(transformUpdate);
            math::quatf newRotation = std::get<2>(transformUpdate);
            bool newRotationRelative = std::get<3>(transformUpdate);
            float newScale = std::get<4>(transformUpdate);

            math::float3 translation;
            math::quatf rotation;
            math::float3 scale;

            decomposeMatrix(transform, &translation, &rotation, &scale);

            if (newRotationRelative)
            {
                rotation = normalize(rotation * newRotation);
            }
            else
            {
                rotation = newRotation;
            }

            math::float3 relativeTranslation;

            if (newTranslationRelative)
            {
                math::mat3f rotationMatrix(rotation);
                relativeTranslation = rotationMatrix * newTranslation;
                translation += relativeTranslation;
            }
            else
            {
                relativeTranslation = newTranslation - translation;
                translation = newTranslation;
            }

            transform = composeMatrix(translation, rotation, scale);

            if (isCollidable)
            {
                auto transformedBB = boundingBox.transform(transform);

                auto collisionAxes = _collisionComponentManager->collides(entity, transformedBB);

                if (collisionAxes.size() == 1)
                {
                    auto globalAxis = collisionAxes[0];
                    globalAxis *= norm(relativeTranslation);
                    auto newRelativeTranslation = relativeTranslation + globalAxis;
                    translation -= relativeTranslation;
                    translation += newRelativeTranslation;
                    transform = composeMatrix(translation, rotation, scale);
                }
                else if (collisionAxes.size() > 1)
                {
                    translation -= relativeTranslation;
                    transform = composeMatrix(translation, rotation, scale);
                }
            }
            tm.setTransform(transformInstance, transform);
        }
        _transformUpdates.clear();
    }

    void SceneManager::setScale(EntityId entityId, float newScale)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);
        if (entity.isNull())
        {
            Log("Failed to find entity under ID %d", entityId);
            return;
        }
        auto &tm = _engine->getTransformManager();

        auto transformInstance = tm.getInstance(entity);
        auto transform = tm.getTransform(transformInstance);
        math::float3 translation;
        math::quatf rotation;
        math::float3 scale;

        decomposeMatrix(transform, &translation, &rotation, &scale);
        auto newTransform = composeMatrix(translation, rotation, newScale);
        tm.setTransform(transformInstance, newTransform);
    }

    void SceneManager::setPosition(EntityId entityId, float x, float y, float z)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);
        if (entity.isNull())
        {
            Log("Failed to find entity under ID %d", entityId);
            return;
        }
        auto &tm = _engine->getTransformManager();

        auto transformInstance = tm.getInstance(entity);
        auto transform = tm.getTransform(transformInstance);
        math::float3 translation;
        math::quatf rotation;
        math::float3 scale;

        decomposeMatrix(transform, &translation, &rotation, &scale);
        translation = math::float3(x, y, z);
        auto newTransform = composeMatrix(translation, rotation, scale);
        tm.setTransform(transformInstance, newTransform);
    }

    void SceneManager::setRotation(EntityId entityId, float rads, float x, float y, float z, float w)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);
        if (entity.isNull())
        {
            Log("Failed to find entity under ID %d", entityId);
            return;
        }
        auto &tm = _engine->getTransformManager();

        auto transformInstance = tm.getInstance(entity);
        auto transform = tm.getTransform(transformInstance);
        math::float3 translation;
        math::quatf rotation;
        math::float3 scale;

        decomposeMatrix(transform, &translation, &rotation, &scale);
        rotation = math::quatf(w, x, y, z);
        auto newTransform = composeMatrix(translation, rotation, scale);
        tm.setTransform(transformInstance, newTransform);
    }

    void SceneManager::queuePositionUpdate(EntityId entity, float x, float y, float z, bool relative)
    {
        std::lock_guard lock(_mutex);

        const auto &pos = _transformUpdates.find(entity);
        if (pos == _transformUpdates.end())
        {
            _transformUpdates.emplace(entity, std::make_tuple(math::float3(), true, math::quatf(1.0f), true, 1.0f));
        }
        auto curr = _transformUpdates[entity];
        auto &trans = std::get<0>(curr);
        trans.x = x;
        trans.y = y;
        trans.z = z;

        auto &isRelative = std::get<1>(curr);
        isRelative = relative;
        _transformUpdates[entity] = curr;
    }

    void SceneManager::queueRotationUpdate(EntityId entity, float rads, float x, float y, float z, float w, bool relative)
    {
        std::lock_guard lock(_mutex);
        const auto &pos = _transformUpdates.find(entity);
        if (pos == _transformUpdates.end())
        {
            _transformUpdates.emplace(entity, std::make_tuple(math::float3(), true, math::quatf(1.0f), true, 1.0f));
        }
        auto curr = _transformUpdates[entity];
        auto &rot = std::get<2>(curr);
        rot.w = w;
        rot.x = x;
        rot.y = y;
        rot.z = z;
        auto &isRelative = std::get<3>(curr);
        isRelative = relative;
        _transformUpdates[entity] = curr;
    }

    const utils::Entity *SceneManager::getCameraEntities(EntityId entityId)
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return nullptr;
            }
        }
        return instance->getAsset()->getCameraEntities();
    }

    size_t SceneManager::getCameraEntityCount(EntityId entityId)
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return -1;
            }
        }
        return instance->getAsset()->getCameraEntityCount();
    }

    const utils::Entity *SceneManager::getLightEntities(EntityId entityId) noexcept
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return nullptr;
            }
        }
        return instance->getAsset()->getLightEntities();
    }

    size_t SceneManager::getLightEntityCount(EntityId entityId) noexcept
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return -1;
            }
        }
        return instance->getAsset()->getLightEntityCount();
    }

    const char *SceneManager::getNameForEntity(EntityId entityId)
    {
        const auto &entity = Entity::import(entityId);
        auto nameInstance = _ncm->getInstance(entity);
        if (!nameInstance.isValid())
        {
            Log("Failed to find name instance for entity ID %d", entityId);
            return nullptr;
        }
        return _ncm->getName(nameInstance);
    }

    int SceneManager::getEntityCount(EntityId entityId, bool renderableOnly)
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return 0;
            }
        }
        if (renderableOnly)
        {
            int count = 0;
            const auto &rm = _engine->getRenderableManager();
            const Entity *entities = instance->getEntities();
            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                if (rm.hasComponent(entities[i]))
                {
                    count++;
                }
            }
            return count;
        }
        return instance->getEntityCount();
    }

    void SceneManager::getEntities(EntityId entityId, bool renderableOnly, EntityId *out)
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return;
            }
        }

        if (renderableOnly)
        {
            int count = 0;
            const auto &rm = _engine->getRenderableManager();
            const Entity *entities = instance->getEntities();
            int offset = 0;
            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                if (rm.hasComponent(entities[i]))
                {
                    out[offset] = Entity::smuggle(entities[i]);
                    offset++;
                }
            }
        }
        else
        {
            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                out[i] = Entity::smuggle(instance->getEntities()[i]);
            }
        }
    }

    const char *SceneManager::getEntityNameAt(EntityId entityId, int index, bool renderableOnly)
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto asset = getAssetByEntityId(entityId);
            if (asset)
            {
                instance = asset->getInstance();
            }
            else
            {
                return nullptr;
            }
        }
        int found = -1;

        if (renderableOnly)
        {
            int count = 0;
            const auto &rm = _engine->getRenderableManager();
            const Entity *entities = instance->getEntities();
            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                if (rm.hasComponent(entities[i]))
                {
                    if (count == index)
                    {
                        found = i;
                        break;
                    }
                    count++;
                }
            }
        }
        else
        {
            found = index;
        }

        if (found >= instance->getEntityCount())
        {
            Log("ERROR: index %d greater than number of child entities.", found);
            return nullptr;
        }

        const utils::Entity entity = instance->getEntities()[found];
        auto inst = _ncm->getInstance(entity);
        auto name = _ncm->getName(inst);
        return name;
    }

    void SceneManager::setPriority(EntityId entityId, int priority)
    {
        auto &rm = _engine->getRenderableManager();
        auto renderableInstance = rm.getInstance(Entity::import(entityId));
        if (!renderableInstance.isValid())
        {
            Log("Error: invalid renderable, did you pass the correct entity?", priority);
            return;
        }
        rm.setPriority(renderableInstance, priority);
        Log("Set instance renderable priority to %d", priority);
    }

    EntityId SceneManager::addGizmo()
    {
        _gizmoMaterial =
            Material::Builder()
                .package(GIZMO_GIZMO_DATA, GIZMO_GIZMO_SIZE)
                .build(*_engine);

        auto vertexCount = 9;

        float *vertices = new float[vertexCount * 3]{
            -0.05, 0.0f, 0.05f,
            0.05f, 0.0f, 0.05f,
            0.05f, 0.0f, -0.05f,
            -0.05f, 0.0f, -0.05f,
            -0.05f, 1.0f, 0.05f,
            0.05f, 1.0f, 0.05f,
            0.05f, 1.0f, -0.05f,
            -0.05f, 1.0f, -0.05f,
            0.00f, 1.1f, 0.0f};

        VertexBuffer::BufferDescriptor::Callback vertexCallback = [](void *buf, size_t,
                                                                     void *data)
        {
            free((void *)buf);
        };

        auto indexCount = 42;
        uint16_t *indices = new uint16_t[indexCount]{
            // bottom quad
            0, 1, 2,
            0, 2, 3,
            // top "cone"
            4, 5, 8,
            5, 6, 8,
            4, 7, 8,
            6, 7, 8,
            // front
            0, 1, 4,
            1, 5, 4,
            // right
            1, 2, 5,
            2, 6, 5,
            // back
            2, 6, 7,
            7, 3, 2,
            // left
            0, 4, 7,
            7, 3, 0

        };

        IndexBuffer::BufferDescriptor::Callback indexCallback = [](void *buf, size_t,
                                                                   void *data)
        {
            free((void *)buf);
        };

        auto vb = VertexBuffer::Builder()
                      .vertexCount(vertexCount)
                      .bufferCount(1)
                      .attribute(
                          VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                      .build(*_engine);

        vb->setBufferAt(
            *_engine,
            0,
            VertexBuffer::BufferDescriptor(vertices, vb->getVertexCount() * sizeof(filament::math::float3), 0, vertexCallback));

        auto ib = IndexBuffer::Builder().indexCount(indexCount).bufferType(IndexBuffer::IndexType::USHORT).build(*_engine);
        ib->setBuffer(*_engine, IndexBuffer::BufferDescriptor(indices, ib->getIndexCount() * sizeof(uint16_t), 0, indexCallback));

        auto &entityManager = EntityManager::get();

        _gizmo[1] = entityManager.create();
        _gizmoMaterialInstances[1] = _gizmoMaterial->createInstance();
        _gizmoMaterialInstances[1]->setParameter("color", math::float3{1.0f, 0.0f, 0.0f});
        RenderableManager::Builder(1)
            .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
            .material(0, _gizmoMaterialInstances[1])
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb,
                      ib, 0, indexCount)
            .culling(false)
            .build(*_engine, _gizmo[1]);

        _gizmo[0] = entityManager.create();
        _gizmoMaterialInstances[0] = _gizmoMaterial->createInstance();
        _gizmoMaterialInstances[0]->setParameter("color", math::float3{0.0f, 1.0f, 0.0f});
        auto xTransform = math::mat4f::translation(math::float3{0.0f, 0.05f, -0.05f}) * math::mat4f::rotation(-math::F_PI_2, math::float3{0, 0, 1});
        auto *instanceBufferX = InstanceBuffer::Builder(1).localTransforms(&xTransform).build(*_engine);
        RenderableManager::Builder(1)
            .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
            .instances(1, instanceBufferX)
            .material(0, _gizmoMaterialInstances[0])
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb,
                      ib, 0, indexCount)
            .culling(false)
            .build(*_engine, _gizmo[0]);

        _gizmo[2] = entityManager.create();
        _gizmoMaterialInstances[2] = _gizmoMaterial->createInstance();
        _gizmoMaterialInstances[2]->setParameter("color", math::float3{0.0f, 0.0f, 1.0f});
        auto zTransform = math::mat4f::translation(math::float3{0.0f, 0.05f, -0.05f}) * math::mat4f::rotation(3 * math::F_PI_2, math::float3{1, 0, 0});
        auto *instanceBufferZ = InstanceBuffer::Builder(1).localTransforms(&zTransform).build(*_engine);
        RenderableManager::Builder(1)
            .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
            .instances(1, instanceBufferZ)
            .material(0, _gizmoMaterialInstances[2])
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb,
                      ib, 0, indexCount)
            .culling(false)
            .build(*_engine, _gizmo[2]);

        auto &rm = _engine->getRenderableManager();
        rm.setPriority(rm.getInstance(_gizmo[0]), 7);
        rm.setPriority(rm.getInstance(_gizmo[1]), 7);
        rm.setPriority(rm.getInstance(_gizmo[2]), 7);
        return Entity::smuggle(_gizmo[0]);
    }

    void SceneManager::getGizmo(EntityId *out)
    {
        out[0] = Entity::smuggle(_gizmo[0]);
        out[1] = Entity::smuggle(_gizmo[1]);
        out[2] = Entity::smuggle(_gizmo[2]);
    }

} // namespace thermion_filament
