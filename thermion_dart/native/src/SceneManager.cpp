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
#include <filament/Viewport.h>
#include <filament/Frustum.h>

#include <utils/EntityManager.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>
#include <gltfio/math.h>
#include <gltfio/materials/uberarchive.h>
#include <imageio/ImageDecoder.h>

#include "material/FileMaterialProvider.hpp"
#include "material/UnlitMaterialProvider.hpp"
#include "material/unlit.h"

#include "StreamBufferAdapter.hpp"
#include "Log.hpp"
#include "SceneManager.hpp"
#include "CustomGeometry.hpp"
#include "UnprojectTexture.hpp"

#include "Gizmo.hpp"

extern "C"
{
#include "material/image.h"
#include "material/unlit_fixed_size.h"
}

namespace thermion
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
                               const char *uberArchivePath,
                               Camera *mainCamera)
        : _resourceLoaderWrapper(resourceLoaderWrapper),
          _engine(engine),
          _scene(scene),
          _mainCamera(mainCamera)
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

        _unlitMaterialProvider = new UnlitMaterialProvider(_engine, UNLIT_PACKAGE, UNLIT_UNLIT_SIZE);

        utils::EntityManager &em = utils::EntityManager::get();

        _ncm = new NameComponentManager(em);

        _assetLoader = AssetLoader::create({_engine, _ubershaderProvider, _ncm, &em});

        _gltfResourceLoader->addTextureProvider("image/ktx2", _ktxDecoder);
        _gltfResourceLoader->addTextureProvider("image/png", _stbDecoder);
        _gltfResourceLoader->addTextureProvider("image/jpeg", _stbDecoder);

        auto &tm = _engine->getTransformManager();

        _collisionComponentManager = new CollisionComponentManager(tm);
        _animationComponentManager = new AnimationComponentManager(tm, _engine->getRenderableManager());

        _gridOverlay = new GridOverlay(*_engine);

        _scene->addEntity(_gridOverlay->sphere());
        _scene->addEntity(_gridOverlay->grid());

        _gizmoMaterial =
            Material::Builder()
                .package(UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_DATA, UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_SIZE)
                .build(*_engine);
    }

    SceneManager::~SceneManager()
    {
        for (auto camera : _cameras)
        {
            auto entity = camera->getEntity();
            _engine->destroyCameraComponent(entity);
            _engine->getEntityManager().destroy(entity);
        }
        _cameras.clear();

        _gridOverlay->destroy();
        destroyAll();

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

    Gizmo *SceneManager::createGizmo(View *view, Scene *scene)
    {
        return new Gizmo(_engine, view, scene, _gizmoMaterial);
    }

    bool SceneManager::isGizmoEntity(Entity entity)
    {
        return false; // TODO
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
                                    const char *relativeResourcePath,
                                    bool keepData)
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

        if (!keepData)
        {
            asset->releaseSourceData();
        }

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

    void SceneManager::setVisibilityLayer(EntityId entityId, int layer)
    {
        auto &rm = _engine->getRenderableManager();
        auto renderable = rm.getInstance(utils::Entity::import(entityId));
        if (!renderable.isValid())
        {
            Log("Warning: no renderable found");
        }

        rm.setLayerMask(renderable, 0xFF, 1u << layer);
    }

    EntityId SceneManager::loadGlbFromBuffer(const uint8_t *data, size_t length, int numInstances, bool keepData, int priority, int layer, bool loadResourcesAsync)
    {

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

        auto &rm = _engine->getRenderableManager();

        for (int i = 0; i < entityCount; i++)
        {
            auto instance = rm.getInstance(asset->getEntities()[i]);
            if (!instance.isValid())
            {
                Log("No valid renderable for entity");
                continue;
            }
            rm.setPriority(instance, priority);
            rm.setLayerMask(instance, 0xFF, 1u << (uint8_t)layer);
        }

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
        if (loadResourcesAsync)
        {
            if (!_gltfResourceLoader->asyncBeginLoad(asset))
            {
                Log("Unknown error loading glb asset");
                return 0;
            }
        }
        else
        {
            if (!_gltfResourceLoader->loadResources(asset))
            {
                Log("Unknown error loading glb asset");
                return 0;
            }
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

        if (!keepData)
        {
            asset->releaseSourceData();
        }

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

        if(isGeometryEntity(entityId)) {
            auto geometry = getGeometry(entityId);
            auto materialInstance = createUnlitMaterialInstance();
            auto instanceEntity = geometry->createInstance(materialInstance);
            _scene->addEntity(instanceEntity);

            return Entity::smuggle(instanceEntity);
        }

        const auto &pos = _assets.find(entityId);
        if (pos == _assets.end())
        {
            Log("Couldn't find asset under specified entity id.");
            return 0;
        }

        const auto asset = pos->second;
        auto instance = _assetLoader->createInstance(asset);

        if (!instance)
        {
            Log("Failed to create instance");
            return 0;
        }
        auto root = instance->getRoot();
        _scene->addEntities(instance->getEntities(), instance->getEntityCount());

        return Entity::smuggle(root);
    }

    EntityId SceneManager::loadGlb(const char *uri, int numInstances, bool keepData)
    {
        ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);
        auto entity = loadGlbFromBuffer((const uint8_t *)rbuf.data, rbuf.size, numInstances, keepData);
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
            for (int i = 0; i < numInstances; i++)
            {
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
        for (auto *texture : _textures)
        {
            _engine->destroy(texture);
        }

        for (auto *materialInstance : _materialInstances)
        {
            _engine->destroy(materialInstance);
        }

        // TODO - free geometry?
        _textures.clear();
        _assets.clear();
        _materialInstances.clear();
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

    math::mat4f SceneManager::getLocalTransform(EntityId entityId)
    {
        auto entity = Entity::import(entityId);
        auto &tm = _engine->getTransformManager();
        auto transformInstance = tm.getInstance(entity);
        return tm.getTransform(transformInstance);
    }

    math::mat4f SceneManager::getWorldTransform(EntityId entityId)
    {
        auto entity = Entity::import(entityId);
        auto &tm = _engine->getTransformManager();
        auto transformInstance = tm.getInstance(entity);
        return tm.getWorldTransform(transformInstance);
    }

    EntityId SceneManager::getBone(EntityId entityId, int skinIndex, int boneIndex)
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
                Log("Failed to find glTF instance under entityID %d, revealing as regular entity", entityId);
                return false;
            }
        }
        auto joints = instance->getJointsAt(skinIndex);
        auto joint = joints[boneIndex];
        return Entity::smuggle(joint);
    }

    math::mat4f SceneManager::getInverseBindMatrix(EntityId entityId, int skinIndex, int boneIndex)
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

        if (isGeometryEntity(entityId))
        {
            return;            
        } else if(isGeometryInstance(entityId)) {
            // destroy renderable
            auto & rm = _engine->getRenderableManager();
            auto & em = _engine->getEntityManager();
            auto instanceEntity = utils::Entity::import(entityId);
            auto it = std::find(_geometryInstances.begin(), _geometryInstances.end(), entityId);
            _geometryInstances.erase(it);
            rm.destroy(instanceEntity);
            em.destroy(instanceEntity);
            _engine->destroy(instanceEntity);
            return;
        } 
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
        const uint32_t *const morphIndices,
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
            std::unordered_set<Entity, Entity::Hasher> joints;
            std::unordered_set<Entity, Entity::Hasher> completed;
            std::stack<Entity> stack;

            auto transforms = getBoneRestTranforms(entityId, skinIndex);

            for (int i = 0; i < instance->getJointCountAt(skinIndex); i++)
            {
                auto restTransform = transforms->at(i);
                const auto &joint = instance->getJointsAt(skinIndex)[i];
                auto transformInstance = transformManager.getInstance(joint);
                transformManager.setTransform(transformInstance, restTransform);
            }
        }
        instance->getAnimator()->updateBoneMatrices();
    }

    std::unique_ptr<std::vector<math::mat4f>> SceneManager::getBoneRestTranforms(EntityId entityId, int skinIndex)
    {

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
        std::unordered_set<Entity, Entity::Hasher> completed;
        std::stack<Entity> stack;

        for (int i = 0; i < instance->getJointCountAt(skinIndex); i++)
        {
            const auto &joint = instance->getJointsAt(skinIndex)[i];
            joints.push_back(joint);
            stack.push(joint);
        }

        while (!stack.empty())
        {
            const auto &joint = stack.top();

            // if we've already handled this node previously (e.g. when we encountered it as a parent), then skip
            if (completed.find(joint) != completed.end())
            {
                stack.pop();
                continue;
            }

            const auto transformInstance = transformManager.getInstance(joint);
            auto parent = transformManager.getParent(transformInstance);

            // we need to handle parent joints before handling their children
            // therefore, if this joint has a parent that hasn't been handled yet,
            // push the parent to the top of the stack and start the loop again
            const auto &jointIter = std::find(joints.begin(), joints.end(), joint);
            auto parentIter = std::find(joints.begin(), joints.end(), parent);

            if (parentIter != joints.end() && completed.find(parent) == completed.end())
            {
                stack.push(parent);
                continue;
            }

            // otherwise let's get the inverse bind matrix for the joint
            math::mat4f inverseBindMatrix;
            bool found = false;
            for (int i = 0; i < instance->getJointCountAt(skinIndex); i++)
            {
                if (instance->getJointsAt(skinIndex)[i] == joint)
                {
                    inverseBindMatrix = instance->getInverseBindMatricesAt(skinIndex)[i];
                    found = true;
                    break;
                }
            }
            ASSERT_PRECONDITION(found, "Failed to find inverse bind matrix for joint %d", joint);

            // now we need to ascend back up the hierarchy to calculate the modelSpaceTransform
            math::mat4f modelSpaceTransform;
            while (parentIter != joints.end())
            {
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

    bool SceneManager::updateBoneMatrices(EntityId entityId)
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
        instance->getAnimator()->updateBoneMatrices();
        return true;
    }

    bool SceneManager::setTransform(EntityId entityId, math::mat4f transform)
    {
        auto &tm = _engine->getTransformManager();
        const auto &entity = Entity::import(entityId);
        auto transformInstance = tm.getInstance(entity);
        if (!transformInstance)
        {
            return false;
        }
        tm.setTransform(transformInstance, transform);
        return true;
    }

    bool SceneManager::setTransform(EntityId entityId, math::mat4 transform)
    {
        auto &tm = _engine->getTransformManager();
        const auto &entity = Entity::import(entityId);
        auto transformInstance = tm.getInstance(entity);
        if (!transformInstance)
        {
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
        if (!_animationComponentManager->hasComponent(instance->getRoot()))
        {
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
        for (int i = 0; i < animationComponent.gltfAnimations.size(); i++)
        {
            if (animationComponent.gltfAnimations[i].index == index)
            {
                found = true;
                break;
            }
        }
        if (!found)
        {
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

    Texture *SceneManager::createTexture(const uint8_t *data, size_t length, const char *name)
    {
        using namespace filament;

        // Create an input stream from the data
        std::istringstream stream(std::string(reinterpret_cast<const char *>(data), length));

        // Decode the image
        image::LinearImage linearImage = image::ImageDecoder::decode(stream, name, image::ImageDecoder::ColorSpace::SRGB);

        if (!linearImage.isValid())
        {
            Log("Failed to decode image.");
            return nullptr;
        }

        uint32_t w = linearImage.getWidth();
        uint32_t h = linearImage.getHeight();
        uint32_t channels = linearImage.getChannels();

        Texture::InternalFormat textureFormat = channels == 3 ? Texture::InternalFormat::RGB16F
                                                              : Texture::InternalFormat::RGBA16F;
        Texture::Format bufferFormat = channels == 3 ? Texture::Format::RGB
                                                     : Texture::Format::RGBA;

        Texture *texture = Texture::Builder()
                               .width(w)
                               .height(h)
                               .levels(1)
                               .format(textureFormat)
                               .sampler(Texture::Sampler::SAMPLER_2D)
                               .build(*_engine);

        if (!texture)
        {
            Log("Failed to create texture: ");
            return nullptr;
        }

        Texture::PixelBufferDescriptor buffer(
            linearImage.getPixelRef(),
            size_t(w * h * channels * sizeof(float)),
            bufferFormat,
            Texture::Type::FLOAT);

        texture->setImage(*_engine, 0, std::move(buffer));

        Log("Created texture: %s (%d x %d, %d channels)", name, w, h, channels);

        _textures.insert(texture);

        return texture;
    }

    bool SceneManager::applyTexture(EntityId entityId, Texture *texture, const char *parameterName, int materialIndex)
    {
        auto entity = Entity::import(entityId);

        if (entity.isNull())
        {
            Log("Entity %d is null?", entityId);
            return false;
        }

        RenderableManager &rm = _engine->getRenderableManager();

        auto renderable = rm.getInstance(entity);

        if (!renderable.isValid())
        {
            Log("Renderable not valid, was the entity id correct (%d)?", entityId);
            return false;
        }

        MaterialInstance *mi = rm.getMaterialInstanceAt(renderable, materialIndex);

        if (!mi)
        {
            Log("ERROR: material index must be less than number of material instances");
            return false;
        }

        auto sampler = TextureSampler();
        mi->setParameter(parameterName, texture, sampler);
        Log("Applied texture to entity %d", entityId);
        return true;
    }

    void SceneManager::destroyTexture(Texture *texture)
    {
        if (_textures.find(texture) == _textures.end())
        {
            Log("Warning: couldn't find texture");
        }
        _textures.erase(texture);
        _engine->destroy(texture);
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
            if (!instance)
            {
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

    unique_ptr<vector<string>> SceneManager::getBoneNames(EntityId assetEntityId, int skinIndex)
    {

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

    EntityId SceneManager::getParent(EntityId childEntityId)
    {
        auto &tm = _engine->getTransformManager();
        const auto child = Entity::import(childEntityId);
        const auto &childInstance = tm.getInstance(child);
        auto parent = tm.getParent(childInstance);
        return Entity::smuggle(parent);
    }

    EntityId SceneManager::getAncestor(EntityId childEntityId)
    {
        auto &tm = _engine->getTransformManager();
        const auto child = Entity::import(childEntityId);
        auto transformInstance = tm.getInstance(child);
        Entity parent;

        while (true)
        {
            auto newParent = tm.getParent(transformInstance);
            if (newParent.isNull())
            {
                break;
            }
            parent = newParent;
            transformInstance = tm.getInstance(parent);
        }

        return Entity::smuggle(parent);
    }

    void SceneManager::setParent(EntityId childEntityId, EntityId parentEntityId, bool preserveScaling)
    {
        auto &tm = _engine->getTransformManager();
        const auto child = Entity::import(childEntityId);
        const auto parent = Entity::import(parentEntityId);

        const auto &parentInstance = tm.getInstance(parent);
        const auto &childInstance = tm.getInstance(child);

        if (!parentInstance.isValid())
        {
            Log("Parent instance is not valid");
            return;
        }

        if (!childInstance.isValid())
        {
            Log("Child instance is not valid");
            return;
        }

        if (preserveScaling)
        {
            auto parentTransform = tm.getWorldTransform(parentInstance);
            math::float3 parentTranslation;
            math::quatf parentRotation;
            math::float3 parentScale;

            decomposeMatrix(parentTransform, &parentTranslation, &parentRotation, &parentScale);

            auto childTransform = tm.getTransform(childInstance);
            math::float3 childTranslation;
            math::quatf childRotation;
            math::float3 childScale;

            decomposeMatrix(childTransform, &childTranslation, &childRotation, &childScale);

            childScale = childScale * (1 / parentScale);

            childTransform = composeMatrix(childTranslation, childRotation, childScale);

            tm.setTransform(childInstance, childTransform);
        }

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
        tm.openLocalTransformTransaction();

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

            if (isCollidable)
            {
                auto transformedBB = boundingBox.transform(transform);

                auto collisionAxes = _collisionComponentManager->collides(entity, transformedBB);

                if (collisionAxes.size() == 1)
                {
                    // auto globalAxis = collisionAxes[0];
                    // globalAxis *= norm(relativeTranslation);
                    // auto newRelativeTranslation = relativeTranslation + globalAxis;
                    // translation -= relativeTranslation;
                    // translation += newRelativeTranslation;
                    // transform = composeMatrix(translation, rotation, scale);
                }
                else if (collisionAxes.size() > 1)
                {
                    // translation -= relativeTranslation;
                    // transform = composeMatrix(translation, rotation, scale);
                }
            }
            tm.setTransform(transformInstance, transformUpdate);
        }
        tm.commitLocalTransformTransaction();
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

    void SceneManager::queueRelativePositionUpdateFromViewportVector(View *view, EntityId entityId, float viewportCoordX, float viewportCoordY)
    {
        // Get the camera and viewport
        const auto &camera = view->getCamera();
        const auto &vp = view->getViewport();

        // Convert viewport coordinates to NDC space
        float ndcX = (2.0f * viewportCoordX) / vp.width - 1.0f;
        float ndcY = 1.0f - (2.0f * viewportCoordY) / vp.height;

        // Get the current position of the entity
        auto &tm = _engine->getTransformManager();
        auto entity = Entity::import(entityId);
        auto transformInstance = tm.getInstance(entity);
        auto currentTransform = tm.getTransform(transformInstance);

        // get entity model origin in camera space
        auto entityPositionInCameraSpace = camera.getViewMatrix() * currentTransform * filament::math::float4{0.0f, 0.0f, 0.0f, 1.0f};
        // get entity model origin in clip space
        auto entityPositionInClipSpace = camera.getProjectionMatrix() * entityPositionInCameraSpace;
        auto entityPositionInNdcSpace = entityPositionInClipSpace / entityPositionInClipSpace.w;

        // Viewport coords in NDC space (use entity position in camera space Z to project onto near plane)
        math::float4 ndcNearPlanePos = {ndcX, ndcY, -1.0f, 1.0f};
        math::float4 ndcFarPlanePos = {ndcX, ndcY, 0.99f, 1.0f};
        math::float4 ndcEntityPlanePos = {ndcX, ndcY, entityPositionInNdcSpace.z, 1.0f};

        // Get viewport coords in clip space
        math::float4 nearPlaneInClipSpace = Camera::inverseProjection(camera.getProjectionMatrix()) * ndcNearPlanePos;
        auto nearPlaneInCameraSpace = nearPlaneInClipSpace / nearPlaneInClipSpace.w;
        math::float4 farPlaneInClipSpace = Camera::inverseProjection(camera.getProjectionMatrix()) * ndcFarPlanePos;
        auto farPlaneInCameraSpace = farPlaneInClipSpace / farPlaneInClipSpace.w;
        math::float4 entityPlaneInClipSpace = Camera::inverseProjection(camera.getProjectionMatrix()) * ndcEntityPlanePos;
        auto entityPlaneInCameraSpace = entityPlaneInClipSpace / entityPlaneInClipSpace.w;
        auto entityPlaneInWorldSpace = camera.getModelMatrix() * entityPlaneInCameraSpace;

        // Queue the position update (as a relative movement)
    }

    void SceneManager::queueTransformUpdates(EntityId *entities, math::mat4 *transforms, int numEntities)
    {
        std::lock_guard lock(_mutex);

        for (int i = 0; i < numEntities; i++)
        {
            auto entity = entities[i];
            const auto &pos = _transformUpdates.find(entity);
            if (pos == _transformUpdates.end())
            {
                _transformUpdates.emplace(entity, transforms[i]);
            }
            auto curr = _transformUpdates[entity];
            _transformUpdates[entity] = curr;
        }
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
    }

    Aabb3 SceneManager::getRenderableBoundingBox(EntityId entityId) {
        auto& rm = _engine->getRenderableManager();
        auto instance = rm.getInstance(Entity::import(entityId));
        if(!instance.isValid()) {
            return Aabb3 {};
        }
        auto box = rm.getAxisAlignedBoundingBox(instance);
        return Aabb3 { box.center.x, box.center.y, box.center.z, box.halfExtent.x, box.halfExtent.y, box.halfExtent.z };
    }

    Aabb2 SceneManager::getScreenSpaceBoundingBox(View *view, EntityId entityId)
    {
        const auto &camera = view->getCamera();
        const auto &viewport = view->getViewport();

        auto &tcm = _engine->getTransformManager();
        auto &rcm = _engine->getRenderableManager();

        // Get the projection and view matrices
        math::mat4 projMatrix = camera.getProjectionMatrix();
        math::mat4 viewMatrix = camera.getViewMatrix();
        math::mat4 vpMatrix = projMatrix * viewMatrix;

        auto entity = Entity::import(entityId);

        auto renderable = rcm.getInstance(entity);
        auto worldTransform = tcm.getWorldTransform(tcm.getInstance(entity));

        // Get the axis-aligned bounding box in model space
        Box aabb = rcm.getAxisAlignedBoundingBox(renderable);

        auto min = aabb.getMin();
        auto max = aabb.getMax();

        // Transform the 8 corners of the AABB to clip space
        std::array<math::float4, 8> corners = {
            worldTransform * math::float4(min.x, min.y, min.z, 1.0f),
            worldTransform * math::float4(max.x, min.y, min.z, 1.0f),
            worldTransform * math::float4(min.x, max.y, min.z, 1.0f),
            worldTransform * math::float4(max.x, max.y, min.z, 1.0f),
            worldTransform * math::float4(min.x, min.y, max.z, 1.0f),
            worldTransform * math::float4(max.x, min.y, max.z, 1.0f),
            worldTransform * math::float4(min.x, max.y, max.z, 1.0f),
            worldTransform * math::float4(max.x, max.y, max.z, 1.0f)};

        // Project corners to clip space and convert to viewport space
        float minX = std::numeric_limits<float>::max();
        float minY = std::numeric_limits<float>::max();
        float maxX = std::numeric_limits<float>::lowest();
        float maxY = std::numeric_limits<float>::lowest();

        for (const auto &corner : corners)
        {

            math::float4 clipSpace = vpMatrix * corner;

            // Check if the point is behind the camera
            if (clipSpace.w <= 0)
            {
                continue; // Skip this point
            }

            // Perform perspective division
            math::float3 ndcSpace = clipSpace.xyz / clipSpace.w;

            // Clamp NDC coordinates to [-1, 1] range
            ndcSpace.x = std::max(-1.0f, std::min(1.0f, ndcSpace.x));
            ndcSpace.y = std::max(-1.0f, std::min(1.0f, ndcSpace.y));

            // Convert NDC to viewport space
            float viewportX = (ndcSpace.x * 0.5f + 0.5f) * viewport.width;
            float viewportY = (1.0f - (ndcSpace.y * 0.5f + 0.5f)) * viewport.height; // Flip Y-axis

            minX = std::min(minX, viewportX);
            minY = std::min(minY, viewportY);
            maxX = std::max(maxX, viewportX);
            maxY = std::max(maxY, viewportY);
        }

        return Aabb2{minX, minY, maxX, maxY};
    }

    void SceneManager::removeStencilHighlight(EntityId entityId)
    {
        std::lock_guard lock(_stencilMutex);
        auto found = _highlighted.find(entityId);
        if (found == _highlighted.end())
        {
            Log("Entity %d has no stencil highlight, skipping removal", entityId);
            return;
        }
        Log("Erasing entity id %d from highlighted", entityId);

        _highlighted.erase(entityId);
    }

    void SceneManager::setStencilHighlight(EntityId entityId, float r, float g, float b)
    {

        std::lock_guard lock(_stencilMutex);

        auto highlightEntity = std::make_unique<HighlightOverlay>(entityId, this, _engine, r, g, b);

        if (highlightEntity->isValid())
        {
            _highlighted.emplace(entityId, std::move(highlightEntity));
        }
    }

    EntityId SceneManager::createGeometry(
        float *vertices,
        uint32_t numVertices,
        float *normals,
        uint32_t numNormals,
        float *uvs,
        uint32_t numUvs,
        uint16_t *indices,
        uint32_t numIndices,
        filament::RenderableManager::PrimitiveType primitiveType,
        filament::MaterialInstance *materialInstance,
        bool keepData)
    {
        auto geometry = std::make_unique<CustomGeometry>(vertices, numVertices, normals, numNormals, uvs, numUvs, indices, numIndices, primitiveType, _engine);
    
        filament::Material *mat = nullptr;

        if (!materialInstance)
        {
            Log("Using default ubershader material");
            filament::gltfio::MaterialKey config;

            memset(&config, 0, sizeof(config)); // Initialize all bits to zero

            config.unlit = false;
            config.doubleSided = false;
            config.useSpecularGlossiness = false;
            config.alphaMode = filament::gltfio::AlphaMode::OPAQUE;
            config.hasBaseColorTexture = numUvs > 0;
            config.hasClearCoat = false;
            config.hasClearCoatNormalTexture = false;
            config.hasClearCoatRoughnessTexture = false;
            config.hasEmissiveTexture = false;
            config.hasIOR = false;
            config.hasMetallicRoughnessTexture = false;
            config.hasNormalTexture = false;
            config.hasOcclusionTexture = false;
            config.hasSheen = false;
            config.hasSheenColorTexture = false;
            config.hasSheenRoughnessTexture = false;
            config.hasSpecularGlossinessTexture = false;
            config.hasTextureTransforms = false;
            config.hasTransmission = false;
            config.hasTransmissionTexture = false;
            config.hasVolume = false;
            config.hasVolumeThicknessTexture = false;
            config.baseColorUV = 0;
            config.hasVertexColors = false;
            config.hasVolume = false;

            materialInstance = createUbershaderMaterialInstance(config);

            if (!materialInstance)
            {
                Log("Failed to create material instance");
                return Entity::smuggle(Entity());
            }
        }

        // Set up texture and sampler if UVs are available
        if (uvs != nullptr && numUvs > 0)
        {
            if(materialInstance->getMaterial()->hasParameter("baseColorMap")) {
                // Create a default white texture
                static constexpr uint32_t textureSize = 1;
                static constexpr uint32_t white = 0x00ffffff;
                Texture *texture = Texture::Builder()
                                    .width(textureSize)
                                    .height(textureSize)
                                    .levels(1)
                                    .format(Texture::InternalFormat::RGBA8)
                                    .build(*_engine);

                _textures.insert(texture);

                filament::backend::PixelBufferDescriptor pbd(&white, 4, Texture::Format::RGBA, Texture::Type::UBYTE);
                texture->setImage(*_engine, 0, std::move(pbd));

                // Create a sampler
                TextureSampler sampler(TextureSampler::MinFilter::NEAREST, TextureSampler::MagFilter::NEAREST);
                sampler.setWrapModeS(TextureSampler::WrapMode::REPEAT);
                sampler.setWrapModeT(TextureSampler::WrapMode::REPEAT);

                // Set the texture and sampler to the material instance
                materialInstance->setParameter("baseColorMap", texture, sampler);
            }
        }

        auto instanceEntity = geometry->createInstance(materialInstance); 
        auto instanceEntityId = Entity::smuggle(instanceEntity);
        _scene->addEntity(instanceEntity);
        _geometryInstances.push_back(instanceEntityId);

        _geometry.emplace(instanceEntityId, std::move(geometry));

        return instanceEntityId;
    }

    MaterialInstance *SceneManager::getMaterialInstanceAt(EntityId entityId, int materialIndex)
    {
        auto entity = Entity::import(entityId);
        const auto &rm = _engine->getRenderableManager();
        auto renderableInstance = rm.getInstance(entity);
        if (!renderableInstance.isValid())
        {
            Log("Error retrieving material instance: no renderable found for entity %d");
            return std::nullptr_t();
        }
        return rm.getMaterialInstanceAt(renderableInstance, materialIndex);
    }

    void SceneManager::setMaterialProperty(EntityId entityId, int materialIndex, const char *property, float value)
    {
        auto entity = Entity::import(entityId);
        const auto &rm = _engine->getRenderableManager();
        auto renderableInstance = rm.getInstance(entity);
        if (!renderableInstance.isValid())
        {
            Log("Error setting material property for entity %d: no renderable");
            return;
        }
        auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, materialIndex);

        if (!materialInstance->getMaterial()->hasParameter(property))
        {
            Log("Parameter %s not found", property);
            return;
        }
        materialInstance->setParameter(property, value);
    }

    void SceneManager::setMaterialProperty(EntityId entityId, int materialIndex, const char *property, int32_t value)
    {
        auto entity = Entity::import(entityId);
        const auto &rm = _engine->getRenderableManager();
        auto renderableInstance = rm.getInstance(entity);
        if (!renderableInstance.isValid())
        {
            Log("Error setting material property for entity %d: no renderable");
            return;
        }
        auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, materialIndex);

        if (!materialInstance->getMaterial()->hasParameter(property))
        {
            Log("Parameter %s not found", property);
            return;
        }
        materialInstance->setParameter(property, value);
    }

    void SceneManager::setMaterialProperty(EntityId entityId, int materialIndex, const char *property, filament::math::float4 &value)
    {
        auto entity = Entity::import(entityId);
        const auto &rm = _engine->getRenderableManager();
        auto renderableInstance = rm.getInstance(entity);
        if (!renderableInstance.isValid())
        {
            Log("Error setting material property for entity %d: no renderable");
            return;
        }
        auto materialInstance = rm.getMaterialInstanceAt(renderableInstance, materialIndex);

        if (!materialInstance->getMaterial()->hasParameter(property))
        {
            Log("Parameter %s not found", property);
            return;
        }
        materialInstance->setParameter(property, filament::math::float4{value.x, value.y, value.z, value.w});
    }

    void SceneManager::destroy(MaterialInstance *instance)
    {
        _engine->destroy(instance);
    }

    MaterialInstance *SceneManager::createUbershaderMaterialInstance(filament::gltfio::MaterialKey config)
    {
        filament::gltfio::UvMap uvmap{};
        auto *materialInstance = _ubershaderProvider->createMaterialInstance(&config, &uvmap);
        if (!materialInstance)
        {
            Log("Invalid material configuration");
            return nullptr;
        }
        materialInstance->setParameter("baseColorFactor", RgbaType::sRGB, filament::math::float4{1.0f, 0.0f, 1.0f, 1.0f});
        materialInstance->setParameter("baseColorIndex", 0);
        _materialInstances.push_back(materialInstance);
        return materialInstance;
    }

    MaterialInstance *SceneManager::createUnlitFixedSizeMaterialInstance()
    {
        auto instance = _gizmoMaterial->createInstance();
        instance->setParameter("scale", 1.0f);
        return instance;
    }

    MaterialInstance *SceneManager::createUnlitMaterialInstance()
    {
        UvMap uvmap;
        auto instance = _unlitMaterialProvider->createMaterialInstance(nullptr, &uvmap);
        instance->setParameter("uvScale", filament::math::float2{1.0f, 1.0f});
        _materialInstances.push_back(instance);
        return instance;
    }

    Camera *SceneManager::createCamera()
    {
        auto entity = EntityManager::get().create();
        auto camera = _engine->createCamera(entity);
        _cameras.push_back(camera);
        return camera;
    }

    void SceneManager::destroyCamera(Camera *camera)
    {
        auto entity = camera->getEntity();
        _engine->destroyCameraComponent(entity);
        _engine->getEntityManager().destroy(entity);
        auto it = std::find(_cameras.begin(), _cameras.end(), camera);
        if (it != _cameras.end())
        {
            _cameras.erase(it);
        }
    }

    size_t SceneManager::getCameraCount()
    {
        return _cameras.size() + 1;
    }

    Camera *SceneManager::getCameraAt(size_t index)
    {
        if (index == 0)
        {
            return _mainCamera;
        }
        if (index - 1 > _cameras.size() - 1)
        {
            return nullptr;
        }
        return _cameras[index - 1];
    }

} // namespace thermion
