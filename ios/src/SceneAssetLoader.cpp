#include "SceneAssetLoader.hpp"
#include "Log.hpp"

#include <gltfio/Animator.h>

namespace polyvox {

using namespace filament;
using namespace filament::gltfio;

SceneAssetLoader::SceneAssetLoader(LoadResource loadResource,
                                   FreeResource freeResource,
                                   AssetLoader *assetLoader,
                                   ResourceLoader *resourceLoader,
                                   NameComponentManager *ncm, Engine *engine,
                                   Scene *scene)
    : _loadResource(loadResource), _freeResource(freeResource),
      _assetLoader(assetLoader), _resourceLoader(resourceLoader), _ncm(ncm),
      _engine(engine), _scene(scene) {}

SceneAsset *SceneAssetLoader::fromGltf(const char *uri,
                                       const char *relativeResourcePath) {
  ResourceBuffer rbuf = _loadResource(uri);

  // Parse the glTF file and create Filament entities.
  Log("Creating asset from JSON");
  FilamentAsset *asset =
      _assetLoader->createAssetFromJson((uint8_t *)rbuf.data, rbuf.size);
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

  asset->getAnimator()->updateBoneMatrices();

  _scene->addEntities(asset->getEntities(), asset->getEntityCount());

  Log("Loaded relative resources");
  asset->releaseSourceData();

  Log("Load complete for GLTF at URI %s", uri);
  return new SceneAsset(asset, _engine, _ncm, _loadResource,_freeResource);
}

SceneAsset *SceneAssetLoader::fromGlb(const char *uri) {
  Log("Loading GLB at URI %s", uri);

  ResourceBuffer rbuf = _loadResource(uri);

  FilamentAsset *asset = _assetLoader->createAssetFromBinary(
      (const uint8_t *)rbuf.data, rbuf.size);

  if (!asset) {
    Log("Unknown error loading GLB asset.");
    return nullptr;
  }

  int entityCount = asset->getEntityCount();

  _scene->addEntities(asset->getEntities(), entityCount);

  Log("Added %d entities to scene", entityCount);

  size_t lightEntityCount = asset->getLightEntityCount();
  Log("Found %d light entities in scene.", lightEntityCount );
  
  _resourceLoader->loadResources(asset);

  Log("Resources loaded.");

  const Entity *entities = asset->getEntities();
  RenderableManager &rm = _engine->getRenderableManager();
  for (int i = 0; i < asset->getEntityCount(); i++) {
    Entity e = entities[i];
    auto inst = rm.getInstance(e);
    // check this
    rm.setCulling(inst, true);
  }

  asset->getAnimator()->updateBoneMatrices();

  asset->releaseSourceData();
  Log("Source data released.");

  _freeResource(rbuf.id);

  Log("Successfully loaded GLB.");
  return new SceneAsset(asset, _engine, _ncm, _loadResource, _freeResource);
}

void SceneAssetLoader::remove(SceneAsset *asset) {
  _scene->removeEntities(asset->_asset->getEntities(),
                         asset->_asset->getEntityCount());
  _resourceLoader->evictResourceData();
  _assetLoader->destroyAsset(asset->_asset);
  delete asset;
}
} // namespace polyvox
