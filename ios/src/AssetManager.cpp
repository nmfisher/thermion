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
        _gltfResourceLoader->addTextureProvider("image/ktx2", _ktxDecoder);
        _gltfResourceLoader->addTextureProvider("image/png", _stbDecoder);
        _gltfResourceLoader->addTextureProvider("image/jpeg", _stbDecoder);
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

        _scene->addEntities(asset->getEntities(), asset->getEntityCount());

        FilamentInstance *inst = asset->getInstance();
        inst->getAnimator()->updateBoneMatrices();
        inst->recomputeBoundingBoxes();

        asset->releaseSourceData();

        SceneAsset sceneAsset(asset);

        utils::Entity e = EntityManager::get().create();

        EntityId eid = Entity::smuggle(e);

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

        Log("Loaded GLB of size %d at URI %s", rbuf.size, uri);

        FilamentAsset *asset = _assetLoader->createAsset(
            (const uint8_t *)rbuf.data, rbuf.size);

        if (!asset)
        {
            Log("Unknown error loading GLB asset.");
            return 0;
        }

        size_t entityCount = asset->getEntityCount();

        _scene->addEntities(asset->getEntities(), entityCount);

        if (!_gltfResourceLoader->loadResources(asset))
        {
            Log("Unknown error loading glb asset");
            _resourceLoaderWrapper->free(rbuf);
            return 0;
        }

        auto lights = asset->getLightEntities();
        _scene->addEntities(lights, asset->getLightEntityCount());

        FilamentInstance *inst = asset->getInstance();

        inst->getAnimator()->updateBoneMatrices();

        inst->recomputeBoundingBoxes();

        asset->releaseSourceData();

        _resourceLoaderWrapper->free(rbuf);

        SceneAsset sceneAsset(asset);

        utils::Entity e = EntityManager::get().create();
        EntityId eid = Entity::smuggle(e);

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

        std::lock_guard lock(_animationMutex);
        RenderableManager &rm = _engine->getRenderableManager();

        auto now = high_resolution_clock::now();

        for (auto &asset : _assets)
        {
            
            for (int i = asset.gltfAnimations.size() - 1; i >= 0; i--) {
                
                auto animationStatus = asset.gltfAnimations[i];

                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

                if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
                {
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
                asset.asset->getInstance()->getAnimator()->updateBoneMatrices();
            }

            for (int i = asset.morphAnimations.size() - 1; i >= 0; i--) {
                
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

            for (int i = asset.boneAnimations.size() - 1; i >= 0; i--) {
                auto animationStatus = asset.boneAnimations[i];

                auto elapsedInSecs = float(std::chrono::duration_cast<std::chrono::milliseconds>(now - animationStatus.start).count()) / 1000.0f;

                if (!animationStatus.loop && elapsedInSecs >= animationStatus.durationInSecs)
                {
                    asset.boneAnimations.erase(asset.boneAnimations.begin() + i);
                    continue;
                }

                float frameLengthInMs = animationStatus.frameLengthInMs;
                
                int frameNumber = static_cast<int>(elapsedInSecs * 1000.0f / frameLengthInMs) % animationStatus.lengthInFrames;

                // offset from the end if reverse
                if (animationStatus.reverse)
                {
                    frameNumber = animationStatus.lengthInFrames - frameNumber;
                }
                updateBoneTransformFromAnimationBuffer(
                    animationStatus,
                    frameNumber,
                    asset.asset);
            
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

        std::lock_guard lock(_animationMutex);

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

        int numJoints = filamentInstance->getJointCountAt(skinIndex);
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

        auto jointTransformInstance = transformManager.getInstance(joint);
        auto globalJointTransform = transformManager.getWorldTransform(jointTransformInstance);

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

    void AssetManager::updateBoneTransformFromAnimationBuffer(
        const BoneAnimation& animation, 
        int frameNumber,
        FilamentAsset *asset)
    {
        auto filamentInstance = asset->getInstance();
        TransformManager &transformManager = _engine->getTransformManager();

        RenderableManager &rm = _engine->getRenderableManager();

        auto boneIndex = animation.boneIndex;

        math::mat4f localTransform(animation.frameData[frameNumber]);

        const auto& inverseBindMatrix = filamentInstance->getInverseBindMatricesAt(animation.skinIndex)[boneIndex];

        for(const auto& meshTarget : animation.meshTargets) {

            const Entity joint = filamentInstance->getJointsAt(animation.skinIndex)[animation.boneIndex];

            auto jointInstance = transformManager.getInstance(joint);
            auto globalJointTransform = transformManager.getWorldTransform(jointInstance);
            
        
            auto inverseGlobalTransform = inverse(
                transformManager.getWorldTransform(
                transformManager.getInstance(meshTarget)
                )
            );
            const auto boneTransform = inverseGlobalTransform * globalJointTransform * localTransform * inverseBindMatrix;
            const auto &renderableInstance = rm.getInstance(meshTarget);
            rm.setBones(
                renderableInstance,
                &boneTransform,
                1,
                boneIndex
            );
        }
        
    }

    void AssetManager::remove(EntityId entityId)
    {
        std::lock_guard lock(_animationMutex);
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
        std::lock_guard lock(_animationMutex);

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
        std::lock_guard lock(_animationMutex);

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

    bool AssetManager::addBoneAnimation(EntityId entityId,
                                        const float *const frameData,
                                        int numFrames,
                                        const char *const boneName,
                                        const char **const meshNames,
                                        int numMeshTargets,
                                        float frameLengthInMs)
    {
        std::lock_guard lock(_animationMutex);

        const auto &pos = _entityIdLookup.find(entityId);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return false;
        }
        auto &asset = _assets[pos->second];
        
        asset.asset->getInstance()->getAnimator()->resetBoneMatrices();

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
        for(int i = 0; i < numFrames; i++) {
            animation.frameData.push_back(math::quatf( 
                frameData[i*4],
                frameData[(i*4)+1],
                frameData[(i*4)+2],
                frameData[(i*4)+3]
            ));

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
            Log("Added mesh target %s", meshNames[i]);
            animation.meshTargets.push_back(entity);
        }

        animation.start = std::chrono::high_resolution_clock::now();
        animation.reverse = false;
        animation.durationInSecs = (frameLengthInMs * numFrames) / 1000.0f;
        animation.lengthInFrames = numFrames;
        animation.frameLengthInMs = frameLengthInMs;
        asset.boneAnimations.push_back(animation);

        return true;
    }

    void AssetManager::playAnimation(EntityId e, int index, bool loop, bool reverse, bool replaceActive, float crossfade)
    {
        std::lock_guard lock(_animationMutex);

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
        std::lock_guard lock(_animationMutex);

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

        Log("Transforming asset to unit cube.");
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

    void AssetManager::updateTransform(SceneAsset &asset)
    {
        auto &tm = _engine->getTransformManager();
        auto transform =
            asset.position * asset.rotation * math::mat4f::scaling(asset.mScale);
        tm.setTransform(tm.getInstance(asset.asset->getRoot()), transform);
    }

    void AssetManager::setScale(EntityId entity, float scale)
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];
        asset.mScale = scale;
        updateTransform(asset);
    }

    void AssetManager::setPosition(EntityId entity, float x, float y, float z)
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];
        asset.position = math::mat4f::translation(math::float3(x, y, z));
        updateTransform(asset);
    }

    void AssetManager::setRotation(EntityId entity, float rads, float x, float y, float z)
    {
        const auto &pos = _entityIdLookup.find(entity);
        if (pos == _entityIdLookup.end())
        {
            Log("ERROR: asset not found for entity.");
            return;
        }
        auto &asset = _assets[pos->second];
        asset.rotation = math::mat4f::rotation(rads, math::float3(x, y, z));
        updateTransform(asset);
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

} // namespace polyvox
