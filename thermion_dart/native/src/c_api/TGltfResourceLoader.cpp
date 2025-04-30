#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include "c_api/TGltfResourceLoader.h"

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

EMSCRIPTEN_KEEPALIVE TGltfResourceLoader *GltfResourceLoader_create(TEngine *tEngine, const char *relativeResourcePath) {
    auto *engine = reinterpret_cast<Engine *>(tEngine);
    auto *gltfResourceLoader = new gltfio::ResourceLoader({
        .engine = engine,
        .gltfPath = relativeResourcePath
    });
    auto stbDecoder = gltfio::createStbProvider(engine);
    auto ktxDecoder = gltfio::createKtx2Provider(engine);
    gltfResourceLoader->addTextureProvider("image/ktx2", ktxDecoder);
    gltfResourceLoader->addTextureProvider("image/png", stbDecoder);
    gltfResourceLoader->addTextureProvider("image/jpeg", stbDecoder);
    
    return reinterpret_cast<TGltfResourceLoader *>(gltfResourceLoader);
}

EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroy(TEngine *tEngine, TGltfResourceLoader *tGltfResourceLoader) {
    auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
    delete gltfResourceLoader;
}

EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceData(TGltfResourceLoader *tGltfResourceLoader, const char *uri, uint8_t *data, size_t length) {
    TRACE("Adding data (length %d) for glTF resource URI %s", length, uri);
    auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
    for(int i = 0; i < 8; i++) {
        std::cout << static_cast<uint32_t>(data[i]) << " "; 
    }
    std::cout << std::endl;
    gltfResourceLoader->addResourceData(uri, { data, length});
}

EMSCRIPTEN_KEEPALIVE bool GltfResourceLoader_loadResources(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset) {    
    auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset *>(tFilamentAsset);
    return gltfResourceLoader->loadResources(filamentAsset);
}

EMSCRIPTEN_KEEPALIVE bool GltfResourceLoader_asyncBeginLoad(TGltfResourceLoader *tGltfResourceLoader, TFilamentAsset *tFilamentAsset) {
    auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
    auto *filamentAsset = reinterpret_cast<gltfio::FilamentAsset *>(tFilamentAsset);
    return gltfResourceLoader->asyncBeginLoad(filamentAsset);
}

EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_asyncUpdateLoad(TGltfResourceLoader *tGltfResourceLoader) {
    auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
    gltfResourceLoader->asyncUpdateLoad();
}

EMSCRIPTEN_KEEPALIVE float GltfResourceLoader_asyncGetLoadProgress(TGltfResourceLoader *tGltfResourceLoader) {
    auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
    return gltfResourceLoader->asyncGetLoadProgress();
}


#ifdef __cplusplus
    }
}
#endif
