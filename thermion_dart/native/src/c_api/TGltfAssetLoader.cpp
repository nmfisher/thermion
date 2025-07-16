#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include "c_api/TGltfAssetLoader.h"

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/Material.h>
#include <filament/RenderableManager.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/TextureProvider.h>
#include <gltfio/math.h>
#include <gltfio/materials/uberarchive.h>

#include <utils/EntityManager.h>
#include <utils/NameComponentManager.h>

#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
        
#endif


EMSCRIPTEN_KEEPALIVE TGltfAssetLoader *GltfAssetLoader_create(TEngine *tEngine, TMaterialProvider *tMaterialProvider, TNameComponentManager *tNameComponentManager) {
    auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
    auto *nameComponentManager = reinterpret_cast<utils::NameComponentManager *>(tNameComponentManager);
    auto *materialProvider = reinterpret_cast<gltfio::MaterialProvider *>(tMaterialProvider);

    if(!materialProvider) {
        Log("No material provider specified, using default ubershader provider");
        materialProvider = gltfio::createUbershaderProvider(
            engine,
            UBERARCHIVE_DEFAULT_DATA,
            UBERARCHIVE_DEFAULT_SIZE
        );
    }

    utils::EntityManager &em = utils::EntityManager::get();
    auto *assetLoader = gltfio::AssetLoader::create({engine, materialProvider, nameComponentManager, &em});
    return reinterpret_cast<TGltfAssetLoader *>(assetLoader);
}

EMSCRIPTEN_KEEPALIVE TFilamentAsset *GltfAssetLoader_load(
    TEngine *tEngine,
    TGltfAssetLoader *tAssetLoader,
    const uint8_t *data,
    size_t length,
    uint8_t numInstances)
{
    auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
    auto *assetLoader = reinterpret_cast<gltfio::AssetLoader *>(tAssetLoader);
    
    gltfio::FilamentAsset *asset;

    if(numInstances > 1) {
        std::vector<gltfio::FilamentInstance *> instances(numInstances);
        asset = assetLoader->createInstancedAsset((const uint8_t *)data, length, instances.data(), numInstances);
    } else { 
        asset = assetLoader->createAsset((const uint8_t *)data, length);
    }

    if (!asset)
    {
        Log("Unknown error loading GLB asset.");
        return std::nullptr_t();
    }

    const char *const *const resourceUris = asset->getResourceUris();
    const size_t resourceUriCount = asset->getResourceUriCount();

    TRACE("Loading glTF asset with %d resource URIs (allocating %d reserved instances", resourceUriCount, numInstances);

    for(int i = 0; i < resourceUriCount; i++) {
        TRACE("%s", resourceUris[i]);
    }

    return reinterpret_cast<TFilamentAsset *>(asset);
}

EMSCRIPTEN_KEEPALIVE TMaterialInstance *GltfAssetLoader_getMaterialInstance(TRenderableManager *tRenderableManager, TFilamentAsset *tAsset) {
    auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
    auto *asset = reinterpret_cast<gltfio::FilamentAsset *>(tAsset);
    auto renderable = asset->getRenderableEntities();
    for(int i =0; i < asset->getRenderableEntityCount(); i++) {
        auto renderableInstance = renderableManager->getInstance(renderable[i]);
        if(!renderableInstance.isValid()) {
            Log("INVALID RENDERABLE");
            continue;
        }
        auto mi = renderableManager->getMaterialInstanceAt(renderableInstance, 0);
        mi->setParameter("baseColorFactor", filament::math::float4 { 1.0f, 0.0f, 0.0f, 1.0f});
    }
    auto renderableInstance = renderableManager->getInstance(renderable[0]);
    auto mi = renderableManager->getMaterialInstanceAt(renderableInstance, 0);
    return reinterpret_cast<TMaterialInstance*>(mi);
}

EMSCRIPTEN_KEEPALIVE TMaterialProvider *GltfAssetLoader_getMaterialProvider(TGltfAssetLoader *tAssetLoader) {
    auto *assetLoader = reinterpret_cast<gltfio::AssetLoader *>(tAssetLoader);
    auto &materialProvider = assetLoader->getMaterialProvider();
    return reinterpret_cast<TMaterialProvider *>(&materialProvider);
}

EMSCRIPTEN_KEEPALIVE int32_t FilamentAsset_getResourceUriCount(
    TFilamentAsset *tFilamentAsset
) {
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset *>(tFilamentAsset);
    return filamentAsset->getResourceUriCount();
}

EMSCRIPTEN_KEEPALIVE const char* const* FilamentAsset_getResourceUris(
    TFilamentAsset *tFilamentAsset
) {
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset *>(tFilamentAsset);
    return filamentAsset->getResourceUris();    
}

#ifdef __cplusplus
    }
}
#endif
