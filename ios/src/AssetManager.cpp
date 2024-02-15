#include <string>
#include <sstream>
#include <thread>
#include <vector>

#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>
#include <filament/RenderableManager.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>
#include <gltfio/math.h>

#include <imageio/ImageDecoder.h>

#include "StreamBufferAdapter.hpp"
#include "SceneAsset.hpp"
#include "Log.hpp"
#include "AssetManager.hpp"

#include "material/FileMaterialProvider.hpp"
#include "gltfio/materials/uberarchive.h"

extern "C"
{
#include "material/image.h"
}

namespace polyvox
{

    using namespace std;
    using namespace std::chrono;
    using namespace image;
    using namespace utils;
    using namespace filament;
    using namespace filament::gltfio;

    AssetManager::AssetManager(const ResourceLoaderWrapper *const resourceLoaderWrapper,
                               NameComponentManager *ncm,
                               Engine *engine,
                               Scene *scene,
                               const char *uberArchivePath)
        : _resourceLoaderWrapper(resourceLoaderWrapper),
          _ncm(ncm),
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

        EntityManager &em = EntityManager::get();

        _assetLoader = AssetLoader::create({_engine, _ubershaderProvider, _ncm, &em});
        _gltfResourceLoader->addTextureProvider ("image/ktx2", _ktxDecoder);
        _gltfResourceLoader->addTextureProvider("image/png", _stbDecoder);
        _gltfResourceLoader->addTextureProvider("image/jpeg", _stbDecoder);

        const auto& tm = _engine->getTransformManager();

        _collisionComponentManager = new CollisionComponentManager(tm);
    }

    AssetManager::~AssetManager()
    {
        _gltfResourceLoader->asyncCancelLoad();
        _ubershaderProvider->destroyMaterials();
        destroyAll();
        AssetLoader::destroy(&_assetLoader);
    }

    EntityId AssetManager::loadGltf(const char *uri,
                                    const char *relativeResourcePath)
    {
        ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);

        // Parse the glTF file and create Filament entities.
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
            string uri = string(relativeResourcePath) + string("/") + string(resourceUris[i]);
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

        asset->releaseSourceData();

        SceneAsset sceneAsset(asset);
        
        const auto joints = inst->getJointsAt(0);

        TransformManager &transformManager = _engine->getTransformManager();

        for(int i = 0; i < inst->getJointCountAt(0); i++) {
            const auto joint = joints[i];
            const auto& jointTransformInstance = transformManager.getInstance(joint);
            const auto& jointTransform = transformManager.getTransform(jointTransformInstance);
            sceneAsset.initialJointTransforms.push_back(jointTransform);
        }
        
        EntityId eid = Entity::smuggle(asset->getRoot());

        _entityIdLookup.emplace(eid, _assets.size());
        _assets.push_back(sceneAsset);

        for (auto &rb : resourceBuffers)
        {
            _resourceLoaderWrapper->free(rb);
        }
        _resourceLoaderWrapper->free(rbuf);

        Log("Finished loading glTF from %s", uri);

        return eid;
    }

    EntityId AssetManager::loadGlb(const char *uri, bool unlit)
    {

        ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);

        Log("Loaded GLB data (%d bytes) from URI %s", rbuf.size, uri);

        FilamentAsset *asset = _assetLoader->createAsset(
            (const uint8_t *)rbuf.data, rbuf.size);

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
                _resourceLoaderWrapper->free(rbuf);
                return 0;
            }
        #endif

        auto lights = asset->getLightEntities();
        _scene->addEntities(lights, asset->getLightEntityCount());

        FilamentInstance *inst = asset->getInstance();

        inst->getAnimator()->updateBoneMatrices();

        inst->recomputeBoundingBoxes();
        auto box = inst->getBoundingBox();
        auto verts = box.extent();
        Log("AABB extent for %s is %f %f %f", uri, verts.x, verts.y, verts.z);

        asset->releaseSourceData();

        _resourceLoaderWrapper->free(rbuf);

        SceneAsset sceneAsset(asset);
        
        const auto joints = inst->getJointsAt(0);

        TransformManager &transformManager = _engine->getTransformManager();

        for(int i = 0; i < inst->getJointCountAt(0); i++) {
            const auto joint = joints[i];
            const auto& jointTransformInstance = transformManager.getInstance(joint);
            const auto& jointTransform = transformManager.getTransform(jointTransformInstance);
            sceneAsset.initialJointTransforms.push_back(jointTransform);
        }

        EntityId eid = Entity::smuggle(asset->getRoot());

        _entityIdLookup.emplace(eid, _assets.size());
        _assets.push_back(sceneAsset);

        return eid;
    }

    bool AssetManager::hide(EntityId entityId, const char *meshName)
    {

        auto asset = getAssetByEntityId(entityId);
        if (!asset)
        {
            return false;
        }

        auto entity = findEntityByName(asset, meshName);

        if (entity.isNull())
        {
            Log("Mesh %s could not be found", meshName);
            return false;
        }
        _scene->remove(entity);
        return true;
    }

    bool AssetManager::reveal(EntityId entityId, const char *meshName)
    {
        auto asset = getAssetByEntityId(entityId);
        if (!asset)
        {
            Log("No asset found under entity ID");
            return false;
        }

        auto entity = findEntityByName(asset, meshName);


        if (entity.isNull())
        {
            Log("Mesh %s could not be found", meshName);
            return false;
        }
        _scene->addEntity(entity);
        return true;
    }

    void AssetManager::destroyAll()
    {
        for (auto &asset : _assets)
        {
            _scene->removeEntities(asset.asset->getEntities(),
                                   asset.asset->getEntityCount());
            _scene->removeEntities(asset.asset->getLightEntities(),
                                   asset.asset->getLightEntityCount());
            _assetLoader->destroyAsset(asset.asset);
        }
        _assets.clear();
    }

    FilamentAsset *AssetManager::getAssetByEntityId(EntityId entityId)
    {
        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            return nullptr;
        }
        return _assets[pos->second].asset;
    }

    void AssetManager::updateAnimations()
    {
        std::lock_guard lock(_mutex);
        RenderableManager &rm = _engine->getRenderableManager();

        auto now = high_resolution_clock::now();

        for (auto &asset : _assets)
        {
            
            for (int i = ((int)asset.gltfAnimations.size()) - 1; i >= 0; i--) {
                
                auto animationStatus = asset.gltfAnimations[i];

                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

                if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
                {
                    asset.asset->getInstance()->getAnimator()->applyAnimation(animationStatus.index, animationStatus.durationInSecs - 0.001);
                    asset.asset->getInstance()->getAnimator()->updateBoneMatrices();
                    asset.gltfAnimations.erase(asset.gltfAnimations.begin() + i);
                    asset.fadeGltfAnimationIndex = -1;
                    continue;
                }
                asset.asset->getInstance()->getAnimator()->applyAnimation(animationStatus.index, elapsedInSecs);

                if (asset.fadeGltfAnimationIndex != -1 && elapsedInSecs < asset.fadeDuration)
                {
                    // cross-fade
                    auto fadeFromTime = asset.fadeOutAnimationStart + elapsedInSecs;
                    auto alpha = elapsedInSecs / asset.fadeDuration;
                    asset.asset->getInstance()->getAnimator()->applyCrossFade(asset.fadeGltfAnimationIndex, fadeFromTime, alpha);
                }
            }

            asset.asset->getInstance()->getAnimator()->updateBoneMatrices();


            for (int i = (int)asset.morphAnimations.size() - 1; i >= 0; i--) {
                
                auto animationStatus = asset.morphAnimations[i];

                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

                if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
                {
                    asset.morphAnimations.erase(asset.morphAnimations.begin() + i);
                    continue;
                }

                
                int frameNumber = static_cast<int>(elapsedInSecs * 1000.0f / animationStatus.frameLengthInMs) % animationStatus.lengthInFrames;
                // offset from the end if reverse
                if (animationStatus.reverse)
                {
                    frameNumber = animationStatus.lengthInFrames - frameNumber;
                }
                auto baseOffset = frameNumber * animationStatus.morphIndices.size();
                for (int i = 0; i < animationStatus.morphIndices.size(); i++)
                {
                    auto morphIndex = animationStatus.morphIndices[i];
                    // set the weights appropriately
                    rm.setMorphWeights(
                        rm.getInstance(animationStatus.meshTarget),
                        animationStatus.frameData.data() + baseOffset + i,
                        1,
                        morphIndex);
                }
            }

            for (int i = (int)asset.boneAnimations.size() - 1; i >= 0; i--) {
                auto animationStatus = asset.boneAnimations[i];

                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

                if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
                {
                    asset.boneAnimations.erase(asset.boneAnimations.begin() + i);
                    continue;
                }
                
                float elapsedFrames = elapsedInSecs * 1000.0f / animationStatus.frameLengthInMs;
                
                int currFrame = static_cast<int>(elapsedFrames) % animationStatus.lengthInFrames;
                float delta = elapsedFrames - currFrame;
                int nextFrame = currFrame;
                auto restLocalTransform = asset.initialJointTransforms[animationStatus.boneIndex];

                // offset from the end if reverse
                if (animationStatus.reverse)
                {
                    currFrame = animationStatus.lengthInFrames - currFrame;
                    if(currFrame > 0) {
                        nextFrame = currFrame - 1;
                    } else { 
                        nextFrame = 0;
                    }
                } else { 
                    if(currFrame < animationStatus.lengthInFrames - 1) {
                        nextFrame = currFrame + 1;
                    } else { 
                        nextFrame = currFrame;
                    }
                }
                
                // simple linear interpolation
                math::mat4f curr = (1 - delta) * (restLocalTransform * animationStatus.frameData[currFrame]);
                math::mat4f next = delta * (restLocalTransform * animationStatus.frameData[nextFrame]);
                math::mat4f localTransform = curr + next;

                auto filamentInstance = asset.asset->getInstance();
                TransformManager &transformManager = _engine->getTransformManager();

                const Entity joint = filamentInstance->getJointsAt(animationStatus.skinIndex)[animationStatus.boneIndex];

                auto jointTransform = transformManager.getInstance(joint);
        
                transformManager.setTransform(jointTransform, localTransform);
        
                asset.asset->getInstance()->getAnimator()->updateBoneMatrices();

                if (animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
                {
                    animationStatus.start = now;
                }
            }
        }
    }

    // TODO - we really don't want to be looking up the bone index/entity by name every single frame
    // - could use findChildEntityByName 
    // - or is it better to add an option for "streaming" mode where we can just return a reference to a mat4 and then update the values directly?
    bool AssetManager::setBoneTransform(EntityId entityId, const char *entityName, int32_t skinIndex, const char* boneName, math::mat4f localTransform)
    {
        std::lock_guard lock(_mutex);

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("Couldn't find asset under specified entity id.");
            return false;
        }
        SceneAsset &sceneAsset = _assets[pos->second];

        const auto &entity = findEntityByName(sceneAsset, entityName);

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

        const auto &filamentInstance = sceneAsset.asset->getInstance();

        size_t skinCount = filamentInstance->getSkinCount();

        if (skinCount > 1)
        {
            Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
        }

        size_t numJoints = filamentInstance->getJointCountAt(skinIndex);
        auto joints = filamentInstance->getJointsAt(skinIndex);
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

        utils::Entity joint = filamentInstance->getJointsAt(skinIndex)[boneIndex];

        if (joint.isNull())
        {
            Log("ERROR : joint not found");
            return false;
        }

        const auto& inverseBindMatrix = filamentInstance->getInverseBindMatricesAt(skinIndex)[boneIndex];

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

    void AssetManager::remove(EntityId entityId)
    {
        std::lock_guard lock(_mutex);
        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("Couldn't find asset under specified entity id.");
            return;
        }
        auto assetIndex = pos->second;
        SceneAsset &sceneAsset = _assets[assetIndex];

        Log("Removing entity %d at asset index %d", entityId, assetIndex);

        for(auto entityPos : _entityIdLookup) {
            if(entityPos.second > pos->second) {
                _entityIdLookup[entityPos.first] = entityPos.second-1;
            }
        }
        
        _entityIdLookup.erase(entityId);


        _scene->removeEntities(sceneAsset.asset->getEntities(),
                               sceneAsset.asset->getEntityCount());
        auto lightCount =sceneAsset.asset->getLightEntityCount();
        if(lightCount > 0) {        _scene->removeEntities(sceneAsset.asset->getLightEntities(),
                                                           sceneAsset.asset->getLightEntityCount());
        }

        _assetLoader->destroyAsset(sceneAsset.asset);

        if (sceneAsset.texture)
        {
            _engine->destroy(sceneAsset.texture);
        }
        EntityManager &em = EntityManager::get();
        em.destroy(Entity::import(entityId));
        _assets.erase(std::remove_if(_assets.begin(), _assets.end(),
                                     [=](SceneAsset &asset)
                                     { return asset.asset == sceneAsset.asset; }),
                      _assets.end());
    }

    void AssetManager::setMorphTargetWeights(EntityId entityId, const char *const entityName, const float *const weights, const int count)
    {
        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];

        auto entity = findEntityByName(asset, entityName);
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

    utils::Entity AssetManager::findChildEntityByName(EntityId entityId, const char *entityName) {
        std::lock_guard lock(_mutex);

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("Couldn't find asset under specified entity id.");
            return utils::Entity();
        }
        SceneAsset &sceneAsset = _assets[pos->second];

        const auto entity = findEntityByName(sceneAsset, entityName);

        if(entity.isNull()) {
            Log("Failed to find entity %s.", entityName);
        }
        
        return entity;

    }


    utils::Entity AssetManager::findEntityByName(SceneAsset asset, const char *entityName)
    {
        utils::Entity entity;
        for (size_t i = 0, c = asset.asset->getEntityCount(); i != c; ++i)
        {
            auto entity = asset.asset->getEntities()[i];
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

    bool AssetManager::setMorphAnimationBuffer(
        EntityId entityId,
        const char *entityName,
        const float *const morphData,
        const int *const morphIndices,
        int numMorphTargets,
        int numFrames,
        float frameLengthInMs)
    {
        std::lock_guard lock(_mutex);

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return false;
        }
        auto &asset = _assets[pos->second];

        auto entity = findEntityByName(asset, entityName);
        if (!entity)
        {
            Log("Warning: failed to find entity %s", entityName);
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
        asset.morphAnimations.emplace_back(morphAnimation);
        return true;
    }

    bool AssetManager::setMaterialColor(EntityId entityId, const char *meshName, int materialIndex, const float r, const float g, const float b, const float a)
    {

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return false;
        }
        auto &asset = _assets[pos->second];
        auto entity = findEntityByName(asset, meshName);

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

    void AssetManager::resetBones(EntityId entityId) {
        std::lock_guard lock(_mutex);

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];
        
        auto filamentInstance = asset.asset->getInstance();
        filamentInstance->getAnimator()->resetBoneMatrices();
        
        auto skinCount = filamentInstance->getSkinCount();

        TransformManager &transformManager = _engine->getTransformManager();
        
        for(int skinIndex = 0; skinIndex < skinCount; skinIndex++) {
            for(int i =0; i < filamentInstance->getJointCountAt(skinIndex);i++) {
                const Entity joint = filamentInstance->getJointsAt(skinIndex)[i];
                auto restLocalTransform = asset.initialJointTransforms[i];
                auto jointTransform = transformManager.getInstance(joint);
                transformManager.setTransform(jointTransform, restLocalTransform);
            }
        }
        filamentInstance->getAnimator()->updateBoneMatrices();
        filamentInstance->getAnimator()->resetBoneMatrices();

    }

    bool AssetManager::addBoneAnimation(EntityId entityId,
                                        const float *const frameData,
                                        int numFrames,
                                        const char *const boneName,
                                        const char **const meshNames,
                                        int numMeshTargets,
                                        float frameLengthInMs,
                                        bool isModelSpace)
    {
        std::lock_guard lock(_mutex);

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return false;
        }
        auto &asset = _assets[pos->second];
        
        auto filamentInstance = asset.asset->getInstance();

        size_t skinCount = filamentInstance->getSkinCount();

        if (skinCount > 1)
        {
            Log("WARNING - skin count > 1 not currently implemented. This will probably not work");
        }

        int skinIndex = 0;
        const utils::Entity *joints = filamentInstance->getJointsAt(skinIndex);
        size_t numJoints = filamentInstance->getJointCountAt(skinIndex);

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

        const auto& inverseBindMatrix = filamentInstance->getInverseBindMatricesAt(skinIndex)[animation.boneIndex];
        const auto& bindMatrix = inverse(inverseBindMatrix);
        math::float3 trans;
        math::quatf rot;
        math::float3 scale;
        decomposeMatrix(inverseBindMatrix, &trans, &rot, &scale);
        math::float3 btrans;
        math::quatf brot;
        math::float3 bscale;
        decomposeMatrix(bindMatrix, &btrans, &brot, &bscale);
        // Log("Bind matrix for bone %s is \n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n", boneName, bindMatrix[0][0],bindMatrix[1][0],bindMatrix[2][0],bindMatrix[3][0],
        //     bindMatrix[0][1],bindMatrix[1][1],bindMatrix[2][1],bindMatrix[3][1],
        //     bindMatrix[0][2],bindMatrix[1][2],bindMatrix[2][2],bindMatrix[3][2],
        //     bindMatrix[0][3],bindMatrix[1][3],bindMatrix[2][3],bindMatrix[3][3]);
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
            // if(i == numFrames - 1) {            Log("Model transform for bone %s is \n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n", boneName,
            //                             frame[0][0],frame[1][0],frame[2][0],frame[3][0],
            //                             frame[0][1],frame[1][1],frame[2][1],frame[3][1],
            //                             frame[0][2],frame[1][2],frame[2][2],frame[3][2],
            //                             frame[0][3],frame[1][3],frame[2][3],frame[3][3]);
            // }
                
                if(isModelSpace) {
                    frame = (math::mat4f(rot) * frame) * math::mat4f(brot);
                }
                animation.frameData.push_back(frame);
       }

        animation.frameLengthInMs = frameLengthInMs;

        animation.meshTargets.clear();
        for (int i = 0; i < numMeshTargets; i++)
        {
            auto entity = findEntityByName(asset, meshNames[i]);
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
        asset.boneAnimations.push_back(animation);

        return true;
    }

    void AssetManager::playAnimation(EntityId e, int index, bool loop, bool reverse, bool replaceActive, float crossfade)
    {
        std::lock_guard lock(_mutex);

        if (index < 0)
        {
            Log("ERROR: glTF animation index must be greater than zero.");
            return;
        }
        const auto &pos = _entityIdLookup.find(e);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];

        if (replaceActive)
        {
            if (asset.gltfAnimations.size() > 0)
            {
                auto &last = asset.gltfAnimations.back();
                asset.fadeGltfAnimationIndex = last.index;
                asset.fadeDuration = crossfade;
                auto now = high_resolution_clock::now();
                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - last.start).count()) / 1000.0f;
                asset.fadeOutAnimationStart = elapsedInSecs;
                asset.gltfAnimations.clear();
            }
            else
            {
                asset.fadeGltfAnimationIndex = -1;
                asset.fadeDuration = 0.0f;
            }
        }
        else if (crossfade > 0)
        {
            Log("ERROR: crossfade only supported when replaceActive is true.");
            return;
        }
        else
        {
            asset.fadeGltfAnimationIndex = -1;
            asset.fadeDuration = 0.0f;
        }

        GltfAnimation animation;
        animation.index = index;
        animation.start = std::chrono::high_resolution_clock::now();
        animation.loop = loop;
        animation.reverse = reverse;
        animation.durationInSecs = asset.asset->getInstance()->getAnimator()->getAnimationDuration(index);

        asset.gltfAnimations.push_back(animation);

    }

    void AssetManager::stopAnimation(EntityId entityId, int index)
    {
        std::lock_guard lock(_mutex);

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];

        asset.gltfAnimations.erase(std::remove_if(asset.gltfAnimations.begin(),
                                               asset.gltfAnimations.end(),
                                               [=](GltfAnimation &anim)
                                               { return anim.index == index; }),
                                asset.gltfAnimations.end());
    }

    void AssetManager::loadTexture(EntityId entity, const char *resourcePath, int renderableIndex)
    {

        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];

        Log("Loading texture at %s for renderableIndex %d", resourcePath, renderableIndex);

        string rp(resourcePath);

        if (asset.texture)
        {
            _engine->destroy(asset.texture);
            asset.texture = nullptr;
        }

        ResourceBuffer imageResource = _resourceLoaderWrapper->load(rp.c_str());

        StreamBufferAdapter sb((char *)imageResource.data, (char *)imageResource.data + imageResource.size);

        istream *inputStream = new std::istream(&sb);

        LinearImage *image = new LinearImage(ImageDecoder::decode(
            *inputStream, rp.c_str(), ImageDecoder::ColorSpace::SRGB));

        if (!image->isValid())
        {
            Log("Invalid image : %s", rp.c_str());
            delete inputStream;
            _resourceLoaderWrapper->free(imageResource);
            return;
        }

        uint32_t channels = image->getChannels();
        uint32_t w = image->getWidth();
        uint32_t h = image->getHeight();
        asset.texture = Texture::Builder()
                             .width(w)
                             .height(h)
                             .levels(0xff)
                             .format(channels == 3 ? Texture::InternalFormat::RGB16F
                                                   : Texture::InternalFormat::RGBA16F)
                             .sampler(Texture::Sampler::SAMPLER_2D)
                             .build(*_engine);

        Texture::PixelBufferDescriptor::Callback freeCallback = [](void *buf, size_t,
                                                                   void *data)
        {
            delete reinterpret_cast<LinearImage *>(data);
        };

        Texture::PixelBufferDescriptor buffer(
            image->getPixelRef(), size_t(w * h * channels * sizeof(float)),
            channels == 3 ? Texture::Format::RGB : Texture::Format::RGBA,
            Texture::Type::FLOAT, freeCallback);

        asset.texture->setImage(*_engine, 0, std::move(buffer));
        MaterialInstance *const *inst = asset.asset->getInstance()->getMaterialInstances();
        size_t mic = asset.asset->getInstance()->getMaterialInstanceCount();
        Log("Material instance count : %d", mic);

        auto sampler = TextureSampler();
        inst[0]->setParameter("baseColorIndex", 0);
        inst[0]->setParameter("baseColorMap", asset.texture, sampler);
        delete inputStream;

        _resourceLoaderWrapper->free(imageResource);
    }

    void AssetManager::setAnimationFrame(EntityId entity, int animationIndex, int animationFrame)
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];
        auto offset = 60 * animationFrame * 1000; // TODO - don't hardcore 60fps framerate
        asset.asset->getInstance()->getAnimator()->applyAnimation(animationIndex, offset);
        asset.asset->getInstance()->getAnimator()->updateBoneMatrices();
    }

    float AssetManager::getAnimationDuration(EntityId entity, int animationIndex)
    {
        const auto &pos = _entityIdLookup.find(entity);

        unique_ptr<vector<string>> names = make_unique<vector<string>>();

        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity id.");
            return -1.0f;
        }

        auto &asset = _assets[pos->second];
        return asset.asset->getInstance()->getAnimator()->getAnimationDuration(animationIndex);
    }

    unique_ptr<vector<string>> AssetManager::getAnimationNames(EntityId entity)
    {

        const auto &pos = _entityIdLookup.find(entity);

        unique_ptr<vector<string>> names = make_unique<vector<string>>();

        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity id.");
            return names;
        }
        auto &asset = _assets[pos->second];

        size_t count = asset.asset->getInstance()->getAnimator()->getAnimationCount();

        for (size_t i = 0; i < count; i++)
        {
            names->push_back(asset.asset->getInstance()->getAnimator()->getAnimationName(i));
        }

        return names;
    }

    unique_ptr<vector<string>> AssetManager::getMorphTargetNames(EntityId entity, const char *meshName)
    {

        unique_ptr<vector<string>> names = make_unique<vector<string>>();

        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return names;
        }
        auto &asset = _assets[pos->second];

        const utils::Entity *entities = asset.asset->getEntities();

        for (int i = 0; i < asset.asset->getEntityCount(); i++)
        {
            utils::Entity e = entities[i];
            auto inst = _ncm->getInstance(e);
            const char *name = _ncm->getName(inst);

            if (name && strcmp(name, meshName) == 0)
            {
                size_t count = asset.asset->getMorphTargetCountAt(e);
                for (int j = 0; j < count; j++)
                {
                    const char *morphName = asset.asset->getMorphTargetNameAt(e, j);
                    names->push_back(morphName);
                }
                break;
            }
        }
        return names;
    }

    void AssetManager::transformToUnitCube(EntityId entity)
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];
        auto &tm = _engine->getTransformManager();
        FilamentInstance *inst = asset.asset->getInstance();
        auto aabb = inst->getBoundingBox();
        auto center = aabb.center();
        auto halfExtent = aabb.extent();
        auto maxExtent = max(halfExtent) * 2;
        auto scaleFactor = 2.0f / maxExtent;
        auto transform =
            math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
        tm.setTransform(tm.getInstance(inst->getRoot()), transform);
    }

    void AssetManager::setParent(EntityId childEntityId, EntityId parentEntityId) {
        auto& tm = _engine->getTransformManager();
        const auto child = Entity::import(childEntityId);
        const auto parent = Entity::import(parentEntityId);

        const auto& parentInstance = tm.getInstance(parent);
        const auto& childInstance = tm.getInstance(child);
        tm.setParent(childInstance, parentInstance);
        

    }

    void AssetManager::addCollisionComponent(EntityId entityId, void(*onCollisionCallback)(EntityId entityId), bool affectsCollidingTransform) {
        std::lock_guard lock(_mutex);
        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        } 
        auto &asset = _assets[pos->second];   
        asset.asset->getAssetInstances();
        auto collisionInstance = _collisionComponentManager->addComponent(asset.asset->getRoot());
        _collisionComponentManager->elementAt<0>(collisionInstance) = asset.asset->getInstance()->getBoundingBox();
        _collisionComponentManager->elementAt<1>(collisionInstance) = onCollisionCallback;
        _collisionComponentManager->elementAt<2>(collisionInstance) = affectsCollidingTransform;
        
    }

    void AssetManager::updateTransforms() { 
        std::lock_guard lock(_mutex);

        auto &tm = _engine->getTransformManager();
        for ( const auto &[entityId, transformUpdate]: _transformUpdates ) {
            const auto &pos = _entityIdLookup.find(entityId);
            if (pos == _entityIdLookup.end())
            {
                Log("ERROR: asset not found for entity.");
                continue;
            }
            auto &asset = _assets[pos->second];   
            auto transformInstance = tm.getInstance(asset.asset->getRoot());
            auto transform = tm.getTransform(transformInstance);

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
            auto bb = asset.asset->getBoundingBox();
            auto transformedBB = bb.transform(transform);
            
            auto collisionAxes = _collisionComponentManager->collides(transformedBB);

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
            tm.setTransform(transformInstance, transform);
        }
        _transformUpdates.clear();
    }

    void AssetManager::setScale(EntityId entity, float newScale)
    {
        std::lock_guard lock(_mutex);
        const auto &pos = _transformUpdates.find(entity);
        if (pos == _transformUpdates.end())
        {
            _transformUpdates[entity] = make_tuple(math::float3(), true, math::quatf(1.0f), true, newScale);
        } 
        auto curr = _transformUpdates[entity];
        auto& scale = get<4>(curr);
        scale = newScale;
        _transformUpdates[entity] = curr;
    }

    void AssetManager::setPosition(EntityId entityId, float x, float y, float z)
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

    void AssetManager::setRotation(EntityId entityId, float rads, float x, float y, float z, float w)
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

    void AssetManager::queuePositionUpdate(EntityId entity, float x, float y, float z, bool relative)
    {
        std::lock_guard lock(_mutex);

        if(!relative) {
            
        }
        const auto &pos = _transformUpdates.find(entity);
        if (pos == _transformUpdates.end())
        {
            _transformUpdates.emplace(entity, make_tuple(math::float3(), true, math::quatf(1.0f), true, 1.0f));
        } 
        auto curr = _transformUpdates[entity];
        auto& trans = get<0>(curr);
        trans.x = x;
        trans.y = y;
        trans.z = z;
         
        auto& isRelative = get<1>(curr);
        isRelative = relative;
        _transformUpdates[entity] = curr;        
    }

    void AssetManager::queueRotationUpdate(EntityId entity, float rads, float x, float y, float z, float w, bool relative)
    {
        std::lock_guard lock(_mutex);
        const auto &pos = _transformUpdates.find(entity);
        if (pos == _transformUpdates.end())
        {
            _transformUpdates.emplace(entity, make_tuple(math::float3(), true, math::quatf(1.0f), true, 1.0f));
        } 
        auto curr = _transformUpdates[entity];
        auto& rot = std::get<2>(curr);
        rot.w = w;
        rot.x = x;
        rot.y = y;
        rot.z = z;
        auto& isRelative = get<3>(curr);
        isRelative = relative;
        _transformUpdates[entity] = curr;
    }

    const utils::Entity *AssetManager::getCameraEntities(EntityId entity)
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return nullptr;
        }
        auto &asset = _assets[pos->second];
        return asset.asset->getCameraEntities();
    }

    size_t AssetManager::getCameraEntityCount(EntityId entity)
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return 0;
        }
        auto &asset = _assets[pos->second];
        return asset.asset->getCameraEntityCount();
    }

    const utils::Entity *AssetManager::getLightEntities(EntityId entity) const noexcept
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return nullptr;
        }
        auto &asset = _assets[pos->second];
        return asset.asset->getLightEntities();
    }

    size_t AssetManager::getLightEntityCount(EntityId entity) const noexcept
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return 0;
        }
        auto &asset = _assets[pos->second];
        return asset.asset->getLightEntityCount();
    }

    const char *AssetManager::getNameForEntity(EntityId entityId)
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

    int AssetManager::getEntityCount(EntityId entityId, bool renderableOnly) {
        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return 0;
        }
        auto &asset = _assets[pos->second];
        if(renderableOnly) {
            int count = 0;
            const auto& rm = _engine->getRenderableManager();
            const Entity *entities = asset.asset->getEntities();
            for(int i=0; i < asset.asset->getEntityCount(); i++) {
                if(rm.hasComponent(entities[i])) { 
                    count++;
                }
            }
            return count;
        } 
        return asset.asset->getEntityCount();
    }

    const char* AssetManager::getEntityNameAt(EntityId entityId, int index, bool renderableOnly) {
        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return nullptr;
        }
        auto &asset = _assets[pos->second];
        int found = -1;

        if(renderableOnly) {
            int count = 0;
            const auto& rm = _engine->getRenderableManager();
            const Entity *entities = asset.asset->getEntities();
            for(int i=0; i < asset.asset->getEntityCount(); i++) {
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

        if(found >= asset.asset->getEntityCount()) { 
            Log("ERROR: index %d greater than number of child entities.", found);
            return nullptr;
        }
        
        const utils::Entity entity = asset.asset->getEntities()[found];    
        auto inst = _ncm->getInstance(entity);
        return _ncm->getName(inst);
    }

} // namespace polyvox
