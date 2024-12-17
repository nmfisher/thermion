#include <memory>
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
#include "material/gizmo.h"

#include "StreamBufferAdapter.hpp"

#include "Log.hpp"

#include "scene/SceneManager.hpp"
#include "scene/CustomGeometry.hpp"
#include "scene/GeometrySceneAsset.hpp"
#include "scene/GltfSceneAsset.hpp"
#include "scene/Gizmo.hpp"
#include "scene/SceneAsset.hpp"
#include "scene/GeometrySceneAssetBuilder.hpp"
#include "UnprojectTexture.hpp"

#include "resources/translation_gizmo_glb.h"
#include "resources/rotation_gizmo_glb.h"

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

        _collisionComponentManager = std::make_unique<CollisionComponentManager>(tm);

        _animationManager = std::make_unique<AnimationManager>(_engine, _scene);

        _unlitFixedSizeMaterial =
            Material::Builder()
                .package(UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_DATA, UNLIT_FIXED_SIZE_UNLIT_FIXED_SIZE_SIZE)
                .build(*_engine);

        _gizmoMaterial =
            Material::Builder()
                .package(GIZMO_GIZMO_DATA, GIZMO_GIZMO_SIZE)
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

        destroyAll();

        _engine->destroy(_unlitFixedSizeMaterial);
        _engine->destroy(_gizmoMaterial);
        _cameras.clear();

        _grid = nullptr;

        _gltfResourceLoader->asyncCancelLoad();
        _ubershaderProvider->destroyMaterials();

        _animationManager = std::nullptr_t();
        _collisionComponentManager = std::nullptr_t();
        delete _ncm;

        delete _gltfResourceLoader;
        delete _stbDecoder;
        delete _ktxDecoder;
        delete _ubershaderProvider;
        AssetLoader::destroy(&_assetLoader);
    }

    SceneAsset *SceneManager::createGrid(Material *material)
    {
        if (!_grid)
        {
            if(!material) {
                material = Material::Builder()
                    .package(GRID_PACKAGE, GRID_GRID_SIZE)
                    .build(*_engine);
            }
            
            _grid = std::make_unique<GridOverlay>(*_engine, material);
        }
        return _grid.get();
    }

    bool SceneManager::isGridEntity(utils::Entity entity)
    {
        if (!_grid)
        {
            TRACE("No grid");
            return false;
        }
        if (entity == _grid->getEntity())
        {
            TRACE("%d is a grid entity.", entity);
            return true;
        }
        for (int i = 0; i < _grid->getChildEntityCount(); i++)
        {
            if (entity == _grid->getChildEntities()[i])
            {
                TRACE("%d is a child entity of grid.", entity);
                return true;
            }
        }
        return false;
    }

    Gizmo *SceneManager::createGizmo(View *view, Scene *scene, GizmoType type)
    {
        TRACE("Creating gizmo type %d", type);
        Gizmo *raw;
        switch (type)
        {
        case GizmoType::TRANSLATION:
            if (!_translationGizmoGlb)
            {
                TRACE("Translation gizmo source not found, loading");
                _translationGizmoGlb = loadGlbFromBuffer(TRANSLATION_GIZMO_GLB_TRANSLATION_GIZMO_DATA, TRANSLATION_GIZMO_GLB_TRANSLATION_GIZMO_SIZE, 100, true, 4, 0, false, false);
            }
            raw = new Gizmo(_translationGizmoGlb, _engine, view, scene, _unlitFixedSizeMaterial);
            TRACE("Built translation gizmo");
            break;
        case GizmoType::ROTATION:
            if (!_rotationGizmoGlb)
            {
                TRACE("Rotation gizmo source not found, loading");
                _rotationGizmoGlb = loadGlbFromBuffer(ROTATION_GIZMO_GLB_ROTATION_GIZMO_DATA, ROTATION_GIZMO_GLB_ROTATION_GIZMO_SIZE, 100, true, 4, 0, false, false);
            }
            raw = new Gizmo(_rotationGizmoGlb, _engine, view, scene, _unlitFixedSizeMaterial);
            TRACE("Built rotation gizmo");
            break;
        }

        _sceneAssets.push_back(std::unique_ptr<Gizmo>(raw));
        return raw;
    }

    int SceneManager::getInstanceCount(EntityId entityId)
    {
        auto entity = utils::Entity::import(entityId);
        for (auto &asset : _sceneAssets)
        {
            if (asset->getEntity() == entity)
            {
                return asset->getInstanceCount();
            }
        }
        return -1;
    }

    void SceneManager::getInstances(EntityId entityId, EntityId *out)
    {
        auto entity = utils::Entity::import(entityId);
        for (auto &asset : _sceneAssets)
        {
            if (asset->getEntity() == entity)
            {
                for (int i = 0; i < asset->getInstanceCount(); i++)
                {
                    out[i] = Entity::smuggle(asset->getInstanceAt(i)->getEntity());
                }
                return;
            }
        }
    }

    SceneAsset *SceneManager::loadGltf(const char *uri,
                                       const char *relativeResourcePath,
                                       int numInstances,
                                       bool keepData)
    {
        if (numInstances < 1)
        {
            return std::nullptr_t();
        }

        ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);

        std::vector<FilamentInstance *> instances(numInstances);

        FilamentAsset *asset = _assetLoader->createInstancedAsset((uint8_t *)rbuf.data, rbuf.size, instances.data(), numInstances);

        if (!asset)
        {
            Log("Unable to load glTF asset at %d", uri);
            return std::nullptr_t();
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
            return std::nullptr_t();
        }
#endif

        auto sceneAsset = std::make_unique<GltfSceneAsset>(
            asset,
            _assetLoader,
            _engine,
            _ncm);
        auto filamentInstance = asset->getInstance();
        size_t entityCount = filamentInstance->getEntityCount();

        _scene->addEntities(filamentInstance->getEntities(), entityCount);

        for (auto &rb : resourceBuffers)
        {
            _resourceLoaderWrapper->free(rb);
        }
        _resourceLoaderWrapper->free(rbuf);

        auto lights = asset->getLightEntities();
        _scene->addEntities(lights, asset->getLightEntityCount());

        sceneAsset->createInstance();

        auto entityId = Entity::smuggle(sceneAsset->getEntity());

        auto *raw = sceneAsset.get();

        _sceneAssets.push_back(std::move(sceneAsset));

        Log("Finished loading glTF from %s", uri);

        return raw;
    }

    void SceneManager::setVisibilityLayer(EntityId entityId, int layer)
    {
        utils::Entity entity = utils::Entity::import(entityId);
        for (auto &asset : _sceneAssets)
        {
            if (asset->getEntity() == entity)
            {
                asset->setLayer(_engine->getRenderableManager(), layer);
            }
        }
    }

    SceneAsset *SceneManager::loadGlbFromBuffer(const uint8_t *data, size_t length, int numInstances, bool keepData, int priority, int layer, bool loadResourcesAsync, bool addToScene)
    {
        auto &rm = _engine->getRenderableManager();

        std::vector<FilamentInstance *> instances(numInstances);

        FilamentAsset *asset = _assetLoader->createInstancedAsset((const uint8_t *)data, length, instances.data(), numInstances);

        Log("Created instanced asset.");

        if (!asset)
        {
            Log("Unknown error loading GLB asset.");
            return std::nullptr_t();
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

        auto sceneAsset = std::make_unique<GltfSceneAsset>(
            asset,
            _assetLoader,
            _engine,
            _ncm);

        auto sceneAssetInstance = sceneAsset->createInstance();
        if (addToScene)
        {
            sceneAssetInstance->addAllEntities(_scene);
        }
        sceneAssetInstance->setPriority(_engine->getRenderableManager(), priority);
        sceneAssetInstance->setLayer(_engine->getRenderableManager(), layer);

        auto *raw = sceneAsset.get();

        _sceneAssets.push_back(std::move(sceneAsset));

        return raw;
    }

    SceneAsset *SceneManager::createInstance(SceneAsset *asset, MaterialInstance **materialInstances, size_t materialInstanceCount)
    {
        std::lock_guard lock(_mutex);

        auto instance = asset->createInstance(materialInstances, materialInstanceCount);
        if (instance)
        {
            instance->addAllEntities(_scene);
        }
        else
        {
            Log("Failed to create instance");
        }
        return instance;
    }

    SceneAsset *SceneManager::loadGlb(const char *uri, int numInstances, bool keepData)
    {
        ResourceBuffer rbuf = _resourceLoaderWrapper->load(uri);
        auto entity = loadGlbFromBuffer((const uint8_t *)rbuf.data, rbuf.size, numInstances, keepData);
        _resourceLoaderWrapper->free(rbuf);
        return entity;
    }

    bool SceneManager::removeFromScene(EntityId entityId)
    {
        _scene->remove(Entity::import(entityId));
        return true;
    }

    bool SceneManager::addToScene(EntityId entityId)
    {
        _scene->addEntity(Entity::import(entityId));
        return true;
    }

    void SceneManager::destroyAll()
    {
        std::lock_guard lock(_mutex);

        for (auto &asset : _sceneAssets)
        {
            asset->removeAllEntities(_scene);
        }

        _sceneAssets.clear();

        for (auto *texture : _textures)
        {
            _engine->destroy(texture);
        }

        for (auto *materialInstance : _materialInstances)
        {
            _engine->destroy(materialInstance);
        }

        _textures.clear();
        _materialInstances.clear();
    }

    void SceneManager::destroy(SceneAsset *asset)
    {

        std::lock_guard lock(_mutex);

        auto it = std::remove_if(_sceneAssets.begin(), _sceneAssets.end(), [=](auto &sceneAsset)
                                 { return sceneAsset.get() == asset; });
        if (it != _sceneAssets.end())
        {
            auto entity = (*it)->getEntity();
            _collisionComponentManager->removeComponent(entity);
            _animationManager->removeAnimationComponent(utils::Entity::smuggle(entity));
            for (int i = 0; i < (*it)->getChildEntityCount(); i++)
            {
                auto childEntity = (*it)->getChildEntities()[i];
                _collisionComponentManager->removeComponent(childEntity);
                _animationManager->removeAnimationComponent(utils::Entity::smuggle(childEntity));
            }
            (*it)->removeAllEntities(_scene);
            _sceneAssets.erase(it, _sceneAssets.end());
            return;
        }
    }

    Texture *SceneManager::createTexture(const uint8_t *data, size_t length, const char *name)
    {

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

    void SceneManager::addCollisionComponent(EntityId entityId, void (*onCollisionCallback)(const EntityId entityId1, const EntityId entityId2), bool affectsTransform)
    {
        std::lock_guard lock(_mutex);
        utils::Entity entity = utils::Entity::import(entityId);
        for (auto &asset : _sceneAssets)
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset->getInstanceByEntity(entity));
            if (instance)
            {
                auto collisionInstance = _collisionComponentManager->addComponent(instance->getInstance()->getRoot());
                _collisionComponentManager->elementAt<0>(collisionInstance) = instance->getInstance()->getBoundingBox();
                _collisionComponentManager->elementAt<1>(collisionInstance) = onCollisionCallback;
                _collisionComponentManager->elementAt<2>(collisionInstance) = affectsTransform;
                return;
            }
        }
    }

    void SceneManager::removeCollisionComponent(EntityId entityId)
    {
        std::lock_guard lock(_mutex);
        utils::Entity entity = utils::Entity::import(entityId);
        _collisionComponentManager->removeComponent(entity);
    }

    void SceneManager::testCollisions(EntityId entityId)
    {
        utils::Entity entity = utils::Entity::import(entityId);
        for (auto &asset : _sceneAssets)
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset->getInstanceByEntity(entity));
            if (instance)
            {
                const auto &tm = _engine->getTransformManager();
                auto transformInstance = tm.getInstance(entity);
                auto worldTransform = tm.getWorldTransform(transformInstance);
                auto aabb = instance->getInstance()->getBoundingBox();
                aabb = aabb.transform(worldTransform);
                _collisionComponentManager->collides(entity, aabb);
            }
        }
    }

    void SceneManager::update()
    {
        _animationManager->update();
        _updateTransforms();
    }

    void SceneManager::_updateTransforms()
    {
        std::lock_guard lock(_mutex);

        // auto &tm = _engine->getTransformManager();
        // tm.openLocalTransformTransaction();

        // for (const auto &[entityId, transformUpdate] : _transformUpdates)
        // {
        //     const auto &pos = _instances.find(entityId);

        //     bool isCollidable = true;
        //     Entity entity;
        //     filament::TransformManager::Instance transformInstance;
        //     filament::math::mat4f transform;
        //     Aabb boundingBox;
        //     if (pos == _instances.end())
        //     {
        //         isCollidable = false;
        //         entity = Entity::import(entityId);
        //     }
        //     else
        //     {
        //         const auto *instance = pos->second;
        //         entity = instance->getRoot();
        //         boundingBox = instance->getBoundingBox();
        //     }

        //     transformInstance = tm.getInstance(entity);
        //     transform = tm.getTransform(transformInstance);

        //     if (isCollidable)
        //     {
        //         auto transformedBB = boundingBox.transform(transform);

        //         auto collisionAxes = _collisionComponentManager->collides(entity, transformedBB);

        //         if (collisionAxes.size() == 1)
        //         {
        //             // auto globalAxis = collisionAxes[0];
        //             // globalAxis *= norm(relativeTranslation);
        //             // auto newRelativeTranslation = relativeTranslation + globalAxis;
        //             // translation -= relativeTranslation;
        //             // translation += newRelativeTranslation;
        //             // transform = composeMatrix(translation, rotation, scale);
        //         }
        //         else if (collisionAxes.size() > 1)
        //         {
        //             // translation -= relativeTranslation;
        //             // transform = composeMatrix(translation, rotation, scale);
        //         }
        //     }
        //     tm.setTransform(transformInstance, transformUpdate);
        // }
        // tm.commitLocalTransformTransaction();
        // _transformUpdates.clear();
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

    Aabb3 SceneManager::getRenderableBoundingBox(EntityId entityId)
    {
        auto &rm = _engine->getRenderableManager();
        auto instance = rm.getInstance(Entity::import(entityId));
        if (!instance.isValid())
        {
            return Aabb3{};
        }
        auto box = rm.getAxisAlignedBoundingBox(instance);
        return Aabb3{box.center.x, box.center.y, box.center.z, box.halfExtent.x, box.halfExtent.y, box.halfExtent.z};
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

    static filament::gltfio::MaterialKey getDefaultUnlitMaterialConfig(int numUvs)
    {
        filament::gltfio::MaterialKey config;
        memset(&config, 0, sizeof(config));

        config.unlit = false;
        config.doubleSided = false;
        config.useSpecularGlossiness = false;
        config.alphaMode = filament::gltfio::AlphaMode::OPAQUE;
        config.hasBaseColorTexture = numUvs > 0;
        config.baseColorUV = 0;
        config.hasVertexColors = false;

        return config;
    }

    SceneAsset *SceneManager::createGeometry(
        float *vertices,
        uint32_t numVertices,
        float *normals,
        uint32_t numNormals,
        float *uvs,
        uint32_t numUvs,
        uint16_t *indices,
        uint32_t numIndices,
        filament::RenderableManager::PrimitiveType primitiveType,
        filament::MaterialInstance **materialInstances,
        size_t materialInstanceCount,
        bool keepData)
    {
        utils::Entity entity;

        auto builder = GeometrySceneAssetBuilder(_engine)
                           .vertices(vertices, numVertices)
                           .indices(indices, numIndices)
                           .primitiveType(primitiveType);

        if (normals)
        {
            builder.normals(normals, numNormals);
        }

        if (uvs)
        {
            builder.uvs(uvs, numUvs);
        }

        builder.materials(materialInstances, materialInstanceCount);

        auto sceneAsset = builder.build();

        if (!sceneAsset)
        {
            Log("Failed to create geometry");
            return std::nullptr_t();
        }

        sceneAsset->addAllEntities(_scene);
        auto *raw = sceneAsset.get();
        _sceneAssets.push_back(std::move(sceneAsset));
        return raw;
    }

    void SceneManager::destroy(filament::MaterialInstance *instance)
    {
        auto it = std::find(_materialInstances.begin(), _materialInstances.end(), instance);
        if (it != _materialInstances.end())
        {
            _materialInstances.erase(it);
        }
        _engine->destroy(instance);
    }

    MaterialInstance *SceneManager::createUnlitFixedSizeMaterialInstance()
    {
        auto instance = _unlitFixedSizeMaterial->createInstance();
        instance->setParameter("scale", 1.0f);
        return instance;
    }

    MaterialInstance *SceneManager::createUnlitMaterialInstance()
    {
        UvMap uvmap;
        auto instance = _unlitMaterialProvider->createMaterialInstance(nullptr, &uvmap);
        instance->setParameter("baseColorFactor", filament::math::float4{1.0f, 1.0f, 1.0f, 1.0f});
        instance->setParameter("baseColorIndex", -1);
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

    void SceneManager::transformToUnitCube(EntityId entityId)
    {
        auto entity = utils::Entity::import(entityId);
        for (auto &asset : _sceneAssets)
        {
            auto *instance = reinterpret_cast<GltfSceneAssetInstance *>(asset->getInstanceByEntity(entity));
            if (instance)
            {
                auto &transformManager = _engine->getTransformManager();
                const auto &entity = utils::Entity::import(entityId);
                auto transformInstance = transformManager.getInstance(entity);
                if (!transformInstance)
                {
                    return;
                }

                auto aabb = instance->getInstance()->getBoundingBox();
                auto center = aabb.center();
                auto halfExtent = aabb.extent();
                auto maxExtent = max(halfExtent) * 2;
                auto scaleFactor = 2.0f / maxExtent;
                auto transform = math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
                transformManager.setTransform(transformManager.getInstance(entity), transform);
                return;
            }
        }
    }

} // namespace thermion
