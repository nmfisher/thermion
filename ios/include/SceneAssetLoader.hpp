#pragma once

#include <filament/Scene.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>

#include "ResourceManagement.hpp"
#include "SceneAsset.hpp"
#include "ResourceBuffer.hpp"

namespace polyvox {
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;

    class SceneAssetLoader {
        public:
            SceneAssetLoader(
                LoadResource loadResource, 
                FreeResource freeResource, 
                AssetLoader* assetLoader,
                ResourceLoader* resourceLoader,
                NameComponentManager* ncm,
                Engine* engine,
                Scene* scene);
            SceneAsset* fromGltf(const char* uri, const char* relativeResourcePath);
            SceneAsset* fromGlb(const char* uri);
            void remove(SceneAsset* asset);

        private:
            LoadResource _loadResource;
            FreeResource _freeResource;
            AssetLoader* _assetLoader;
            ResourceLoader* _resourceLoader;
            NameComponentManager* _ncm;
            Engine* _engine;
            Scene* _scene;

    };
}
