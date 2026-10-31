 

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

#include <mutex>
#include <unordered_map>

#include "Log.hpp"

namespace
{
    // gltfio::ResourceLoader does not own its texture providers. They hold the
    // decoder state of every texture they decoded (for KTX2, a copy of the
    // compressed image), so they are deleted with the loader, after it: its
    // destructor still calls cancelDecoding() on them.
    struct TextureProviders
    {
        filament::gltfio::TextureProvider *stb = nullptr;
        filament::gltfio::TextureProvider *ktx2 = nullptr;
    };
    std::mutex gTextureProvidersMutex;
    std::unordered_map<filament::gltfio::ResourceLoader *, TextureProviders> gTextureProviders;
}

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
        
#endif

EMSCRIPTEN_KEEPALIVE TGltfResourceLoader *GltfResourceLoader_create(TEngine *tEngine) {
    auto *engine = reinterpret_cast<Engine *>(tEngine);
    auto *gltfResourceLoader = new gltfio::ResourceLoader({
        .engine = engine,
    });
    auto stbDecoder = gltfio::createStbProvider(engine);
    auto ktxDecoder = gltfio::createKtx2Provider(engine);
    gltfResourceLoader->addTextureProvider("image/ktx2", ktxDecoder);
    gltfResourceLoader->addTextureProvider("image/png", stbDecoder);
    gltfResourceLoader->addTextureProvider("image/jpeg", stbDecoder);
    {
        std::lock_guard<std::mutex> lock(gTextureProvidersMutex);
        gTextureProviders[gltfResourceLoader] = {stbDecoder, ktxDecoder};
    }

    return reinterpret_cast<TGltfResourceLoader *>(gltfResourceLoader);
}

EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_destroy(TEngine *tEngine, TGltfResourceLoader *tGltfResourceLoader) {
    auto *gltfResourceLoader = reinterpret_cast<gltfio::ResourceLoader *>(tGltfResourceLoader);
    TextureProviders providers;
    {
        std::lock_guard<std::mutex> lock(gTextureProvidersMutex);
        auto found = gTextureProviders.find(gltfResourceLoader);
        if (found != gTextureProviders.end()) {
            providers = found->second;
            gTextureProviders.erase(found);
        }
    }
    delete gltfResourceLoader;
    delete providers.stb;
    delete providers.ktx2;
}

EMSCRIPTEN_KEEPALIVE void GltfResourceLoader_addResourceData(
    TGltfResourceLoader *loader, const char *uri, uint8_t *data, size_t length,
    void (*onRelease)(void *, size_t, void *), void *userData) {
    TRACE("Adding data (length %d) for glTF resource URI %s", length, uri);
    auto *gltfResourceLoader = reinterpret_cast<filament::gltfio::ResourceLoader *>(loader);
    gltfResourceLoader->addResourceData(uri, {data, length, onRelease, userData});
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
