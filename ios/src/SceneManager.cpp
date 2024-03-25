#include <string>
#include <sstream>
#include <thread>
#include <vector>

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

#include "StreamBufferAdapter.hpp"
#include "Log.hpp"
#include "SceneManager.hpp"

#include "gltfio/materials/uberarchive.h"

extern "C"
{
#include "material/image.h"
}


namespace flutter_filament
{

    using namespace std::chrono;
    using namespace image;
    using namespace utils;
    using namespace filament;
    using namespace filament::gltfio;
    using std::unique_ptr;

    SceneManager::SceneManager(const ResourceLoaderWrapper *const resourceLoaderWrapper,
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
        Log("Created ubershader provider.");

        utils::EntityManager &em = utils::EntityManager::get();

        _ncm = new NameComponentManager(em);

        _assetLoader = AssetLoader::create({_engine, _ubershaderProvider, _ncm, &em});
        _gltfResourceLoader->addTextureProvider ("image/ktx2", _ktxDecoder);
        _gltfResourceLoader->addTextureProvider("image/png", _stbDecoder);
        _gltfResourceLoader->addTextureProvider("image/jpeg", _stbDecoder);

        auto& tm = _engine->getTransformManager();

        _collisionComponentManager = new CollisionComponentManager(tm);
        _animationComponentManager = new AnimationComponentManager(tm, _engine->getRenderableManager());

        addGizmo();

    }

    SceneManager::~SceneManager()
    {
        _gltfResourceLoader->asyncCancelLoad();
        _ubershaderProvider->destroyMaterials();
        destroyAll();
        AssetLoader::destroy(&_assetLoader);
    }

    int SceneManager::getInstanceCount(EntityId entityId) {
        auto* asset = getAssetByEntityId(entityId);
        if(!asset) {
            return -1;
        }

        return asset->getAssetInstanceCount();
    }

    void SceneManager::getInstances(EntityId entityId, EntityId* out) {
        auto* asset = getAssetByEntityId(entityId);
        if(!asset) {
            return;
        }
        auto* instances = asset->getAssetInstances();
        for(int i=0; i < asset->getAssetInstanceCount(); i++) {
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
            if (!_gltfResourceLoader->asyncBeginLoad(asset)) {
                Log("Unknown error loading glTF asset");
                _resourceLoaderWrapper->free(rbuf);
                for(auto& rb : resourceBuffers) {
                    _resourceLoaderWrapper->free(rb);
                }
                return 0;
            }
            while(_gltfResourceLoader->asyncGetLoadProgress() < 1.0f) {
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

        _animationComponentManager->addAnimationComponent(inst);

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

    EntityId SceneManager::loadGlbFromBuffer(const uint8_t* data, size_t length, int numInstances) {

        Log("Loading GLB from buffer of length %d", length);

        FilamentAsset *asset = nullptr;
        if(numInstances > 1) {
            std::vector<FilamentInstance*> instances(numInstances);
            asset = _assetLoader->createInstancedAsset((const uint8_t *)data, length, instances.data(), numInstances);
        } else {
            asset = _assetLoader->createAsset(
            (const uint8_t *)data, length);
        }

        if (!asset)
        {
            Log("Unknown error loading GLB asset.");
            return 0;
        }

        size_t entityCount = asset->getEntityCount();

        _scene->addEntities(asset->getEntities(), entityCount);

        #ifdef __EMSCRIPTEN__ 
            if (!_gltfResourceLoader->asyncBeginLoad(asset)) {
                Log("Unknown error loading glb asset");
                _resourceLoaderWrapper->free(rbuf);
                return 0;
            }
            while(_gltfResourceLoader->asyncGetLoadProgress() < 1.0f) {
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

        for(int i =0; i < asset->getAssetInstanceCount(); i++) { 
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

    void SceneManager::addAnimationComponent(EntityId entityId) {

        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return;
            }
        }

        _animationComponentManager->addAnimationComponent(instance);
    }

    EntityId SceneManager::createInstance(EntityId entityId) {
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
        auto entity = loadGlbFromBuffer((const uint8_t*)rbuf.data, rbuf.size, numInstances);
        _resourceLoaderWrapper->free(rbuf);
        return entity;
    }

    bool SceneManager::hide(EntityId entityId, const char *meshName)
    {
        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                // Log("Failed to find glTF instance under entityID %d, hiding as regular entity", entityId);
                _scene->remove(Entity::import(entityId));
                return true;
            }   
        }

        utils::Entity entity;

        if(meshName) {
            entity = findEntityByName(instance, meshName);
            // Log("Hiding child entity under name %s ", meshName);
            if (entity.isNull()) {
                Log("Failed to hide entity; specified mesh name does not exist under the target entity, or the target entity itself is no longer valid.");
                return false;
            }
            _scene->remove(entity);
        } else { 
            // Log("Hiding all child entities");
            auto* entities = instance->getEntities();
            for(int i =0; i < instance->getEntityCount(); i++) { 
                auto entity = entities[i];
                _scene->remove(entity);
            }
        }
        
        return true;
    }

    bool SceneManager::reveal(EntityId entityId, const char *meshName)
    {
        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                // Log("Failed to find glTF instance under entityID %d, revealing as regular entity", entityId);
                _scene->addEntity(Entity::import(entityId));
                return true;
            }
        }

        utils::Entity entity;

        if(meshName) {
            entity = findEntityByName(instance, meshName);
            if (entity.isNull())
            {
                Log("Failed to reveal entity; specified mesh name does not exist under the target entity, or the target entity itself is no longer valid.");
                return false;
            }
            _scene->addEntity(entity);
        } else { 
            // Log("Revealing all child entities");
            auto* entities = instance->getEntities();
            for(int i =0; i < instance->getEntityCount(); i++) { 
                auto entity = entities[i];
                _scene->addEntity(entity);
            }
        }

        return true;
    }

    void SceneManager::destroyAll()
    {
        for (auto &asset : _assets)
        {
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
            // Log("Failed to find FilamentInstance for entity %d", entityId);
            return nullptr;
        }
        return pos->second;
    }

    FilamentAsset *SceneManager::getAssetByEntityId(EntityId entityId)
    {
        const auto &pos = _assets.find(entityId);
        if (pos == _assets.end())
        {
            // Log("Failed to find FilamentAsset for entity %d", entityId);
            return nullptr;
        }
        return pos->second;
    }

    
    // TODO - we really don't want to be looking up the bone index/entity by name every single frame
    // - could use findChildEntityByName 
    // - or is it better to add an option for "streaming" mode where we can just return a reference to a mat4 and then update the values directly?
    bool SceneManager::setBoneTransform(EntityId entityId, const char *entityName, int32_t skinIndex, const char* boneName, math::mat4f localTransform)
    {
        std::lock_guard lock(_mutex);

        auto* instance = getInstanceByEntityId(entityId);

        if(!instance) {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return false;
            }
        }

        const auto &entity = findEntityByName(instance, entityName);

        if(entity.isNull()) {
            Log("Failed to find entity %s.", entityName);
            return false;
        }

        RenderableManager &rm = _engine->getRenderableManager();

        const auto &renderableInstance = rm.getInstance(entity);

        if(!renderableInstance.isValid()) {
            Log("Invalid renderable");
            return false;
        }

        TransformManager &transformManager = _engine->getTransformManager();

        size_t skinCount = instance->getSkinCount();

        if (skinCount > 1)
        {
            Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
        }

        size_t numJoints = instance->getJointCountAt(skinIndex);
        auto joints = instance->getJointsAt(skinIndex);
        int boneIndex = -1;
        for (int i = 0; i < numJoints; i++)
        {
            const char *jointName = _ncm->getName(_ncm->getInstance(joints[i]));
            if (strcmp(jointName, boneName) == 0)
            {
                boneIndex = i;
                break;
            }
        }
        if(boneIndex == -1) {
            Log("Failed to find bone %s", boneName);
            return false;
        }

        utils::Entity joint = instance->getJointsAt(skinIndex)[boneIndex];

        if (joint.isNull())
        {
            Log("ERROR : joint not found");
            return false;
        }

        const auto& inverseBindMatrix = instance->getInverseBindMatricesAt(skinIndex)[boneIndex];

        auto jointTransform = transformManager.getInstance(joint);
        auto globalJointTransform = transformManager.getWorldTransform(jointTransform);

        auto inverseGlobalTransform = inverse(
            transformManager.getWorldTransform(
            transformManager.getInstance(entity)
            )
        );

        const auto boneTransform = inverseGlobalTransform * globalJointTransform * 
        localTransform * inverseBindMatrix;

        rm.setBones(
            renderableInstance,
            &boneTransform,
            1,
            boneIndex);
        return true;
    }   

    void SceneManager::remove(EntityId entityId)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);

        if(_animationComponentManager->hasComponent(entity)) {
            _animationComponentManager->removeComponent(entity);
        }

        if(_collisionComponentManager->hasComponent(entity)) {
            _collisionComponentManager->removeComponent(entity);
        }
    
        _scene->remove(entity);

        const auto* instance = getInstanceByEntityId(entityId);       
    
        if(instance) {
            _instances.erase(entityId);
            _scene->removeEntities(instance->getEntities(), instance->getEntityCount());
            for(int i = 0; i < instance->getEntityCount(); i++) {
                auto childEntity = instance->getEntities()[i];
                if(_collisionComponentManager->hasComponent(childEntity)) {
                    _collisionComponentManager->removeComponent(childEntity);
                }
                if(_animationComponentManager->hasComponent(childEntity)) {
                    _animationComponentManager->removeComponent(childEntity);
                }
            }
        // if this a FilamentAsset Entity
        } else { 
            auto* asset = getAssetByEntityId(entityId);

            if(!asset) {
                Log("ERROR: could not find FilamentInstance or FilamentAsset associated with the given entity id");
                return;
            }
            _assets.erase(entityId);

            _scene->removeEntities(asset->getEntities(), asset->getEntityCount());

            _animationComponentManager->removeComponent(asset->getInstance()->getRoot());

             for(int i = 0; i < asset->getEntityCount(); i++) {
                auto childEntity = asset->getEntities()[i];
                if(_collisionComponentManager->hasComponent(childEntity)) {
                    _collisionComponentManager->removeComponent(childEntity);
                }
                if(_animationComponentManager->hasComponent(childEntity)) {
                    _animationComponentManager->removeComponent(childEntity);
                }
            }

            auto lightCount = asset->getLightEntityCount();
            if(lightCount > 0) {        
                _scene->removeEntities(asset->getLightEntities(),
                                                           asset->getLightEntityCount());
            }
            _assetLoader->destroyAsset(asset);
        }

        // if (sceneAsset.texture)
        // {
        //     _engine->destroy(sceneAsset.texture);
        // }
//
//        utils::EntityManager &em = utils::EntityManager::get();
//        em.destroy(entity);
    }

    void SceneManager::setMorphTargetWeights(EntityId entityId, const char *const entityName, const float *const weights, const int count)
    {
        auto* instance = getInstanceByEntityId(entityId);

        if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(!asset) {
                return;
            }
            instance = asset->getInstance();
        }

        auto entity = findEntityByName(instance, entityName);
        if (!entity)
        {
            Log("Warning: failed to find entity %s", entityName);
            return;
        }

        RenderableManager &rm = _engine->getRenderableManager();

        auto renderableInstance = rm.getInstance(entity);

        if (!renderableInstance.isValid())
        {
            Log("Warning: failed to find renderable instance for entity %s", entityName);
            return;
        }

        rm.setMorphWeights(
            renderableInstance,
            weights,
            count);
    }

    utils::Entity SceneManager::findChildEntityByName(EntityId entityId, const char *entityName) {
        std::lock_guard lock(_mutex);

        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(!asset) {
                return utils::Entity();
            }
            instance = asset->getInstance();
        }
        

        const auto entity = findEntityByName(instance, entityName);

        if(entity.isNull()) {
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
        const char *entityName,
        const float *const morphData,
        const int *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {
        std::lock_guard lock(_mutex);

        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return false;
            }
        }

        auto entity = findEntityByName(instance, entityName);
        if (!entity)
        {
            Log("ERROR: failed to find entity %s", entityName);
            return false;
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
                    frameLengthInMs
                    );

        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());
        auto& animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);
        auto& morphAnimations = animationComponent.morphAnimations;
        
        morphAnimations.emplace_back(morphAnimation);
        return true;
    }

    bool SceneManager::setMaterialColor(EntityId entityId, const char *meshName, int materialIndex, const float r, const float g, const float b, const float a)
    {

         auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
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

    void SceneManager::resetBones(EntityId entityId) {
        std::lock_guard lock(_mutex);

        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return;
            }
        }
        
        instance->getAnimator()->resetBoneMatrices();
        
        auto skinCount = instance->getSkinCount();

        TransformManager &transformManager = _engine->getTransformManager();

        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());
        auto& animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);

        for(int skinIndex = 0; skinIndex < skinCount; skinIndex++) {
            for(int i =0; i < instance->getJointCountAt(skinIndex);i++) {
                const Entity joint = instance->getJointsAt(skinIndex)[i];
                auto restLocalTransform = animationComponent.initialJointTransforms[i];
                auto jointTransform = transformManager.getInstance(joint);
                transformManager.setTransform(jointTransform, restLocalTransform);
            }
        }
        instance->getAnimator()->updateBoneMatrices();
        instance->getAnimator()->resetBoneMatrices();

    }

    bool SceneManager::addBoneAnimation(EntityId entityId,
                                        const float *const frameData,
                                        int numFrames,
                                        const char *const boneName,
                                        const char **const meshNames,
                                        int numMeshTargets,
                                        float frameLengthInMs,
                                        bool isModelSpace)
    {
        std::lock_guard lock(_mutex);

        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return false;
            }
        }

        size_t skinCount = instance->getSkinCount();

        if (skinCount > 1)
        {
            Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
        }

        int skinIndex = 0;
        const utils::Entity *joints = instance->getJointsAt(skinIndex);
        size_t numJoints = instance->getJointCountAt(skinIndex);

        BoneAnimation animation;
        bool found = false;

        for (int i = 0; i < numJoints; i++)
        {
            const char *jointName = _ncm->getName(_ncm->getInstance(joints[i]));
            if (strcmp(jointName, boneName) == 0)
            {
                animation.boneIndex = i;
                found = true;
                break;
            }
        }
        if(!found) {
            Log("Failed to find bone %s", boneName);
            return false;
        }
        
        animation.frameData.clear();

        const auto& inverseBindMatrix = instance->getInverseBindMatricesAt(skinIndex)[animation.boneIndex];
        const auto& bindMatrix = inverse(inverseBindMatrix);
        math::float3 trans;
        math::quatf rot;
        math::float3 scale;
        decomposeMatrix(inverseBindMatrix, &trans, &rot, &scale);
        math::float3 btrans;
        math::quatf brot;
        math::float3 bscale;
        decomposeMatrix(bindMatrix, &btrans, &brot, &bscale);

        for(int i = 0; i < numFrames; i++) {
            math::mat4f frame( 
                frameData[i*16],
                frameData[(i*16)+1],
                frameData[(i*16)+2],
                frameData[(i*16)+3],
                frameData[(i*16)+4],
                frameData[(i*16)+5],
                frameData[(i*16)+6],
                frameData[(i*16)+7],
                frameData[(i*16)+8],
                frameData[(i*16)+9],
                frameData[(i*16)+10],
                frameData[(i*16)+11],
                frameData[(i*16)+12],
                frameData[(i*16)+13],
                frameData[(i*16)+14],
                frameData[(i*16)+15]);
               
                if(isModelSpace) {
                    frame = (math::mat4f(rot) * frame) * math::mat4f(brot);
                }
                animation.frameData.push_back(frame);
       }

        animation.frameLengthInMs = frameLengthInMs;

        animation.meshTargets.clear();
        for (int i = 0; i < numMeshTargets; i++)
        {
            auto entity = findEntityByName(instance, meshNames[i]);
            if (!entity)
            {
                Log("Mesh target %s for bone animation could not be found", meshNames[i]);
                return false;
            }
            animation.meshTargets.push_back(entity);
        }

        animation.start = std::chrono::high_resolution_clock::now();
        animation.reverse = false;
        animation.durationInSecs = (frameLengthInMs * numFrames) / 1000.0f;
        animation.lengthInFrames = numFrames;
        animation.frameLengthInMs = frameLengthInMs;
        animation.skinIndex = 0;


        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());
        auto& animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);
        auto& boneAnimations = animationComponent.boneAnimations;
        
        boneAnimations.emplace_back(animation);

        return true;
    }

    void SceneManager::playAnimation(EntityId entityId, int index, bool loop, bool reverse, bool replaceActive, float crossfade)
    {
        std::lock_guard lock(_mutex);

        if (index < 0)
        {
            Log("ERROR: glTF animation index must be greater than zero.");
            return;
        }
        
        auto* instance = getInstanceByEntityId(entityId);
        if (!instance)
        {
            auto* asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return;
            }
        }

        if(!_animationComponentManager->hasComponent(instance->getRoot())) {
            Log("ERROR: specified entity is not animatable (has no animation component attached).");
            return;
        }

        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());


        auto& animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);

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
        animation.index = index;
        animation.start = std::chrono::high_resolution_clock::now();
        animation.loop = loop;
        animation.reverse = reverse;
        animation.durationInSecs = instance->getAnimator()->getAnimationDuration(index);

        animationComponent.gltfAnimations.push_back(animation);

    }

    void SceneManager::stopAnimation(EntityId entityId, int index) {
        std::lock_guard lock(_mutex);

        const auto *instance = getInstanceByEntityId(entityId);
        if(!instance) {
            return;
        }

        auto animationComponentInstance = _animationComponentManager->getInstance(instance->getRoot());
        auto& animationComponent = _animationComponentManager->elementAt<0>(animationComponentInstance);

        animationComponent.gltfAnimations.erase(std::remove_if(animationComponent.gltfAnimations.begin(),
                                               animationComponent.gltfAnimations.end(),
                                               [=](GltfAnimation &anim)
                                               { return anim.index == index; }),
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
        auto* instance = getInstanceByEntityId(entityId);
        auto offset = 60 * animationFrame * 1000; // TODO - don't hardcore 60fps framerate
        instance->getAnimator()->applyAnimation(animationIndex, offset);
        instance->getAnimator()->updateBoneMatrices();
    }

    float SceneManager::getAnimationDuration(EntityId entity, int animationIndex)
    {
        auto* instance = getInstanceByEntityId(entity);

        if (!instance)
        {
            auto* asset = getAssetByEntityId(entity);
            if(!asset) {
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

        FilamentInstance* instance;

        if (pos != _instances.end())
        {
            instance = pos->second;
        } else {
            const auto& assetPos = _assets.find(entity);
            if(assetPos != _assets.end()) {
                instance = assetPos->second->getInstance();
            } else {
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

    unique_ptr<std::vector<std::string>> SceneManager::getMorphTargetNames(EntityId entityId, const char *meshName)
    {

        unique_ptr<std::vector<std::string>> names = std::make_unique<std::vector<std::string>>();

        const auto *instance = getInstanceByEntityId(entityId);
         if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(!asset) {         
                return names;
            } 
            instance = asset->getInstance();
        }

        const auto *asset = instance->getAsset();

        const utils::Entity *entities = asset->getEntities();

        for (int i = 0; i < asset->getEntityCount(); i++)
        {
            utils::Entity e = entities[i];
            const char *name = asset->getName(e);

            if (name && strcmp(name, meshName) == 0)
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

    void SceneManager::transformToUnitCube(EntityId entityId)
    {
        const auto *instance = getInstanceByEntityId(entityId);
         if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else { 
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

    void SceneManager::setParent(EntityId childEntityId, EntityId parentEntityId) {
        auto& tm = _engine->getTransformManager();
        const auto child = Entity::import(childEntityId);
        const auto parent = Entity::import(parentEntityId);

        const auto& parentInstance = tm.getInstance(parent);
        const auto& childInstance = tm.getInstance(child);
        tm.setParent(childInstance, parentInstance);
    }

    void SceneManager::addCollisionComponent(EntityId entityId, void(*onCollisionCallback)(const EntityId entityId1, const EntityId entityId2), bool affectsTransform) {
        std::lock_guard lock(_mutex);
        const auto *instance = getInstanceByEntityId(entityId);
         if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(!asset) {
                return;
            } else {
                instance = asset->getInstance();
            }         
        }
        auto collisionInstance = _collisionComponentManager->addComponent(instance->getRoot());
        _collisionComponentManager->elementAt<0>(collisionInstance) = instance->getBoundingBox();
        _collisionComponentManager->elementAt<1>(collisionInstance) = onCollisionCallback;
        _collisionComponentManager->elementAt<2>(collisionInstance) = affectsTransform;
    }

    void SceneManager::removeCollisionComponent(EntityId entityId) {
        std::lock_guard lock(_mutex);
        const auto *instance = getInstanceByEntityId(entityId);
         if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(!asset) {
                return;
            } else {
                instance = asset->getInstance();
            }         
        }
        _collisionComponentManager->removeComponent(instance->getRoot());
    }

    void SceneManager::testCollisions(EntityId entityId) { 
        const auto *instance = getInstanceByEntityId(entityId);
         if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else { 
                return;
            }          
        }

        const auto& tm = _engine->getTransformManager();

        auto transformInstance = tm.getInstance(instance->getRoot());
        auto worldTransform = tm.getWorldTransform(transformInstance);
        auto aabb = instance->getBoundingBox();
        aabb = aabb.transform(worldTransform);
        _collisionComponentManager->collides(instance->getRoot(), aabb);
    }

    void SceneManager::updateAnimations() { 
        std::lock_guard lock(_mutex);
        _animationComponentManager->update();
    }

    void SceneManager::updateTransforms() { 
        std::lock_guard lock(_mutex);

        auto &tm = _engine->getTransformManager();

        for ( const auto &[entityId, transformUpdate]: _transformUpdates ) {
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
            } else { 
                const auto *instance = pos->second;  
                entity =  instance->getRoot();
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

            if(newRotationRelative) {
                rotation = normalize(rotation * newRotation);
            } else {
                rotation = newRotation;
            }

            math::float3 relativeTranslation;

            if(newTranslationRelative) {
                math::mat3f rotationMatrix(rotation);
                relativeTranslation = rotationMatrix * newTranslation;
                translation += relativeTranslation; 
            } else { 
                relativeTranslation = newTranslation - translation;
                translation = newTranslation;
            }

            transform = composeMatrix(translation, rotation, scale);

            if(isCollidable) {
                auto transformedBB = boundingBox.transform(transform);
                
                auto collisionAxes = _collisionComponentManager->collides(entity, transformedBB);

                if(collisionAxes.size() == 1) {
                    auto globalAxis = collisionAxes[0];
                    globalAxis *= norm(relativeTranslation);
                    auto newRelativeTranslation = relativeTranslation + globalAxis;
                    translation -= relativeTranslation;
                    translation += newRelativeTranslation;
                    transform = composeMatrix(translation, rotation, scale);
                } else if(collisionAxes.size() > 1) {
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
        if(entity.isNull()) {
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
        if(entity.isNull()) {
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
        translation = math::float3(x,y,z);
        auto newTransform = composeMatrix(translation, rotation, scale);
        tm.setTransform(transformInstance, newTransform);
    }

    void SceneManager::setRotation(EntityId entityId, float rads, float x, float y, float z, float w)
    {
        std::lock_guard lock(_mutex);

        auto entity = Entity::import(entityId);
        if(entity.isNull()) {
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
        rotation = math::quatf(w,x,y,z);
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
        auto& trans = std::get<0>(curr);
        trans.x = x;
        trans.y = y;
        trans.z = z;
         
        auto& isRelative = std::get<1>(curr);
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
        auto& rot = std::get<2>(curr);
        rot.w = w;
        rot.x = x;
        rot.y = y;
        rot.z = z;
        auto& isRelative = std::get<3>(curr);
        isRelative = relative;
        _transformUpdates[entity] = curr;
    }

    const utils::Entity *SceneManager::getCameraEntities(EntityId entityId)
    {
        const auto *instance = getInstanceByEntityId(entityId);
         if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else { 
                return nullptr;
            }         
        }
        return instance->getAsset()->getCameraEntities();
    }

    size_t SceneManager::getCameraEntityCount(EntityId entityId)
    {
        const auto *instance = getInstanceByEntityId(entityId);
         if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else { 
                return -1;
            }          
        }
        return instance->getAsset()->getCameraEntityCount();
    }

    const utils::Entity *SceneManager::getLightEntities(EntityId entityId) noexcept
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return nullptr;
            }          
        }
        return instance->getAsset()->getLightEntities();
    }

    size_t SceneManager::getLightEntityCount(EntityId entityId) noexcept
    {
        const auto *instance = getInstanceByEntityId(entityId);
        if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
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

    int SceneManager::getEntityCount(EntityId entityId, bool renderableOnly) {
        const auto *instance = getInstanceByEntityId(entityId);
        if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return 0;
            }
        }
        if(renderableOnly) {
            int count = 0;
            const auto& rm = _engine->getRenderableManager();
            const Entity *entities = instance->getEntities();
            for(int i=0; i < instance->getEntityCount(); i++) {
                if(rm.hasComponent(entities[i])) { 
                    count++;
                }
            }
            return count;
        } 
        return instance->getEntityCount();
    }

    const char* SceneManager::getEntityNameAt(EntityId entityId, int index, bool renderableOnly) {
        const auto *instance = getInstanceByEntityId(entityId);
        if(!instance) {
            auto asset = getAssetByEntityId(entityId);
            if(asset) {
                instance = asset->getInstance();
            } else {
                return nullptr;
            }
        }
        int found = -1;

        if(renderableOnly) {
            int count = 0;
            const auto& rm = _engine->getRenderableManager();
            const Entity *entities = instance->getEntities();
            for(int i=0; i < instance->getEntityCount(); i++) {
                if(rm.hasComponent(entities[i])) { 
                    if(count == index) {
                        found = i;
                        break;
                    }
                    count++;
                }
            }
        } else { 
            found = index;
        }

        if(found >= instance->getEntityCount()) { 
            Log("ERROR: index %d greater than number of child entities.", found);
            return nullptr;
        }
        
        const utils::Entity entity = instance->getEntities()[found];    
        auto inst = _ncm->getInstance(entity);
        return _ncm->getName(inst);
    }

    void SceneManager::setPriority(EntityId entityId, int priority) {
        auto& rm = _engine->getRenderableManager();
        auto renderableInstance = rm.getInstance(Entity::import(entityId));
        if(!renderableInstance.isValid()) {
            Log("Error: invalid renderable, did you pass the correct entity?", priority);    
            return;
        }
        rm.setPriority(renderableInstance, priority); 
        Log("Set instance renderable priority to %d", priority);
    }

    EntityId SceneManager::addGizmo() {
        _gizmoMaterial =
          Material::Builder()
              .package(GIZMO_GIZMO_DATA, GIZMO_GIZMO_SIZE)
              .build(*_engine);

        auto vertexCount = 9;

        float* vertices = new float[vertexCount * 3] { 
            -0.05, 0.0f, 0.05f, 
            0.05f, 0.0f, 0.05f, 
            0.05f, 0.0f, -0.05f,
            -0.05f, 0.0f, -0.05f,
            -0.05f, 1.0f, 0.05f,
            0.05f, 1.0f, 0.05f,
            0.05f, 1.0f, -0.05f,
            -0.05f, 1.0f, -0.05f,
            0.00f, 1.1f, 0.0f
        };
           
        VertexBuffer::BufferDescriptor::Callback vertexCallback = [](void *buf, size_t,
                                                                void *data)
        {
        free((void*)buf);
        };

        auto indexCount = 42;
        uint16_t* indices = new uint16_t[indexCount] { 
            //bottom quad
            0,1,2,
            0,2,3,
            // top "cone"
            4,5,8,
            5,6,8,
            4,7,8,
            6,7,8,
            // front 
            0,1,4,
            1,5,4,
            // right
            1,2,5,
            2,6,5,
            // back
            2,6,7,
            7,3,2,
            // left
            0,4,7,
            7,3,0
            
        };
        
        IndexBuffer::BufferDescriptor::Callback indexCallback = [](void *buf, size_t,
                                                                void *data)
        {
        free((void*)buf);
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
            VertexBuffer::BufferDescriptor(vertices, vb->getVertexCount() * sizeof(filament::math::float3), 0, vertexCallback)
        );
        
        auto ib = IndexBuffer::Builder().indexCount(indexCount).bufferType(IndexBuffer::IndexType::USHORT).build(*_engine);
        ib->setBuffer(*_engine, IndexBuffer::BufferDescriptor(indices, ib->getIndexCount() * sizeof(uint16_t), 0, indexCallback));
        
        auto &entityManager = EntityManager::get();

        _gizmoY = entityManager.create();
        auto materialY = _gizmoMaterial->createInstance();
        materialY->setParameter("color", math::float3 { 1.0f, 0.0f, 0.0f });
        RenderableManager::Builder(1)
            .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
            .material(0, materialY)
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb,
                    ib, 0, indexCount)
            .culling(false)
            .build(*_engine, _gizmoY);   

        _gizmoX = entityManager.create();
        auto materialX = _gizmoMaterial->createInstance();
        materialX->setParameter("color", math::float3 { 0.0f, 1.0f, 0.0f });
        auto xTransform  = math::mat4f::translation(math::float3 { 0.0f, 0.05f, -0.05f}) * math::mat4f::rotation(-math::F_PI_2, math::float3 { 0, 0, 1 });
        auto* instanceBufferX = InstanceBuffer::Builder(1).localTransforms(&xTransform).build(*_engine);
        RenderableManager::Builder(1)
            .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
            .instances(1, instanceBufferX)
            .material(0, materialX)
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb,
                    ib, 0, indexCount)
            .culling(false)
            .build(*_engine, _gizmoX);   

        _gizmoZ = entityManager.create();
        auto materialZ = _gizmoMaterial->createInstance();
        materialZ->setParameter("color", math::float3 { 0.0f, 0.0f, 1.0f });
        auto zTransform = math::mat4f::translation(math::float3 { 0.0f, 0.05f, -0.05f}) * math::mat4f::rotation(3 * math::F_PI_2, math::float3 { 1, 0, 0 });
        auto* instanceBufferZ = InstanceBuffer::Builder(1).localTransforms(&zTransform).build(*_engine);
        RenderableManager::Builder(1)
            .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
            .instances(1, instanceBufferZ)
            .material(0, materialZ)
            .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb,
                    ib, 0, indexCount)
            .culling(false)
            .build(*_engine, _gizmoZ);   
        
        
        // auto localTransforms = math::mat4f[3] {
        //     math::mat4f(),
        //     math::mat4f::translation(math::float3 { 0.0f, 0.05f, -0.05f}) * math::mat4f::rotation(3 * math::F_PI_2, math::float3 { 1, 0, 0 }) ,
        //     math::mat4f::translation(math::float3 { 0.0f, 0.05f, -0.05f}) * math::mat4f::rotation(math::F_PI_2, math::float3 { 0, 0, 1 })
        // };


        // RenderableManager::Builder(1)
        //     .boundingBox({{}, {1.0f, 1.0f, 1.0f}})
        //     .instances(3, instanceBuffer)
        //     .material(0, _gizmoMaterial->getDefaultInstance())
        //     .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, vb,
        //             ib, 0, indexCount)
        //     .culling(false)
        //     .build(*_engine, _gizmo);   
            
        auto& rm = _engine->getRenderableManager();
        rm.setPriority(rm.getInstance(_gizmoX), 7);
        rm.setPriority(rm.getInstance(_gizmoY), 7);
        rm.setPriority(rm.getInstance(_gizmoZ), 7);
        return Entity::smuggle(_gizmoX);
    }

    void SceneManager::getGizmo(EntityId* out) { 
        out[0] = Entity::smuggle(_gizmoX);
        out[1] = Entity::smuggle(_gizmoY);
        out[2] = Entity::smuggle(_gizmoZ);    
    }

} // namespace flutter_filament
