#include "SceneAssetLoader.hpp"
#include "Log.hpp"

#include <gltfio/Animator.h>

namespace polyvox {

using namespace filament;
using namespace filament::gltfio;

SceneAssetLoader::SceneAssetLoader(LoadResource loadResource,
                                   FreeResource freeResource,
                                   MaterialProvider* materialProvider,
                                   EntityManager* entityManager, 
                                   ResourceLoader *resourceLoader,
                                   NameComponentManager *ncm, 
                                   Engine *engine,
                                   Scene *scene)
    : _loadResource(loadResource), _freeResource(freeResource), _materialProvider(materialProvider), _entityManager(entityManager), 
      _resourceLoader(resourceLoader), _ncm(ncm),
      _engine(engine), _scene(scene) {
        _assetLoader =   AssetLoader::create({_engine, materialProvider, _ncm, entityManager});
      }

SceneAssetLoader::~SceneAssetLoader() { 
  destroyAll();
  AssetLoader::destroy(&_assetLoader);
}

SceneAsset *SceneAssetLoader::fromGltf(const char *uri,
                                       const char *relativeResourcePath) {
  ResourceBuffer rbuf = _loadResource(uri);

  // Parse the glTF file and create Filament entities.
  Log("Creating asset from JSON");
  FilamentAsset *asset =
      _assetLoader->createAsset((uint8_t *)rbuf.data, rbuf.size);
  Log("Created asset from JSON");

  if (!asset) {
    Log("Unable to parse asset");
    return nullptr;
  }
  Log("Loading relative resources");

  const char *const *const resourceUris = asset->getResourceUris();
  const size_t resourceUriCount = asset->getResourceUriCount();

  Log("Loading %d resources for asset", resourceUriCount);

  for (size_t i = 0; i < resourceUriCount; i++) {
    string uri =
        string(relativeResourcePath) + string("/") + string(resourceUris[i]);
    Log("Creating resource buffer for resource at %s", uri.c_str());
    ResourceBuffer buf = _loadResource(uri.c_str());

    // using FunctionCallback = std::function<void(void*, unsigned int, void
    // *)>; auto cb = [&] (void * ptr, unsigned int len, void * misc)  {
    // };
    // FunctionCallback fcb = cb;

    ResourceLoader::BufferDescriptor b(buf.data, buf.size);
    _resourceLoader->addResourceData(resourceUris[i], std::move(b));
    _freeResource(buf.id);
  }

  _resourceLoader->loadResources(asset);
  const Entity *entities = asset->getEntities();
  RenderableManager &rm = _engine->getRenderableManager();
  for (int i = 0; i < asset->getEntityCount(); i++) {
    Entity e = entities[i];
    auto inst = rm.getInstance(e);
    rm.setCulling(inst, false);
  }

  FilamentInstance* inst = asset->getInstance();
  inst->getAnimator()->updateBoneMatrices();

  inst->recomputeBoundingBoxes();

  _scene->addEntities(asset->getEntities(), asset->getEntityCount());

  Log("Loaded relative resources");
  asset->releaseSourceData();

  Log("Load complete for GLTF at URI %s", uri);
  return new SceneAsset(asset, _engine, _ncm, _loadResource,_freeResource);
}

SceneAsset *SceneAssetLoader::fromGlb(const char *uri) {
  Log("Loading GLB at URI %s", uri);

  ResourceBuffer rbuf = _loadResource(uri);

  FilamentAsset *asset = _assetLoader->createAsset(
      (const uint8_t *)rbuf.data, rbuf.size);


  if (!asset) {
    Log("Unknown error loading GLB asset.");
    return nullptr;
  }

  int entityCount = asset->getEntityCount();

  _scene->addEntities(asset->getEntities(), entityCount);

  Log("Added %d entities to scene", entityCount);
  
  _resourceLoader->loadResources(asset);

  Log("Resources loaded.");

  const Entity *entities = asset->getEntities();

  RenderableManager &rm = _engine->getRenderableManager();

  MaterialKey config;
  auto mi_new = _materialProvider->createMaterialInstance(&config, nullptr);
  
  // why did I need to explicitly enable culling?
  for (int i = 0; i < asset->getEntityCount(); i++) {
    auto entityInstance = rm.getInstance(entities[i]);   
    auto mi = rm.getMaterialInstanceAt(entityInstance, 0);
    // auto m = mi->getMaterial();
    // auto shading = m->getShading();
    // Log("Shading %d", shading);
  }

  auto lights = asset->getLightEntities();
  _scene->addEntities(lights, asset->getLightEntityCount());
  
  Log("Added %d lights to scene from asset", asset->getLightEntityCount());

  FilamentInstance* inst = asset->getInstance();


  inst->getAnimator()->updateBoneMatrices();

  inst->recomputeBoundingBoxes();

  asset->releaseSourceData();
  Log("Source data released.");

  _freeResource(rbuf.id);

  Log("Successfully loaded GLB.");
  SceneAsset* sceneAsset = new SceneAsset(asset, _engine, _ncm, _loadResource, _freeResource);
  _assets.push_back(sceneAsset);


  

  return sceneAsset;
}

void SceneAssetLoader::destroyAll() {
  for (auto asset : _assets) {
     _scene->removeEntities(asset->_asset->getEntities(),
                         asset->_asset->getEntityCount());

    _scene->removeEntities(asset->getLightEntities(),
                          asset->getLightEntityCount());

    _resourceLoader->evictResourceData();
    _assetLoader->destroyAsset(asset->_asset);
    delete asset;
  }
  _assets.clear();
}

void SceneAssetLoader::remove(SceneAsset *asset) {
  bool erased = false;
  for (auto it = _assets.begin(); it != _assets.end();++it) {
    if (*it == asset) {
      _assets.erase(it);
      erased = true;
      break;
    }
  }
  if (!erased) {
    Log("Error removing asset from scene : not found");
    return;
  }

  Log("Removing asset and all associated entities/lights.");

  _scene->removeEntities(asset->_asset->getEntities(),
                         asset->_asset->getEntityCount());

  _scene->removeEntities(asset->getLightEntities(),
                         asset->getLightEntityCount());

  _resourceLoader->evictResourceData();
  _assetLoader->destroyAsset(asset->_asset);
  delete asset;
}
} // namespace polyvox
