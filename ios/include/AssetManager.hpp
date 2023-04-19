#pragma once

#include <filament/Scene.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>

#include "ResourceManagement.hpp"
#include "SceneAsset.hpp"
#include "ResourceBuffer.hpp"

typedef int32_t EntityId;

namespace polyvox {
    using namespace filament;
    using namespace filament::gltfio;

    class AssetManager {
        public:
            AssetManager(LoadResource loadResource,
                        FreeResource freeResource,
                        NameComponentManager *ncm, 
                        Engine *engine,
                        Scene *scene);
            ~AssetManager();
            EntityId loadGltf(const char* uri, const char* relativeResourcePath);
            EntityId loadGlb(const char* uri, bool unlit);
            FilamentAsset* getAssetByEntityId(EntityId entityId);
            void remove(EntityId entity);
            void destroyAll();
            unique_ptr<vector<string>> getAnimationNames(EntityId entity);
            unique_ptr<vector<string>> getMorphTargetNames(EntityId entity, const char *meshName);
            void transformToUnitCube(EntityId e);
            inline void updateTransform(EntityId e);
            void setScale(EntityId e, float scale);
            void setPosition(EntityId e, float x, float y, float z);
            void setRotation(EntityId e, float rads, float x, float y, float z);
            const utils::Entity *getCameraEntities(EntityId e);
            size_t getCameraEntityCount(EntityId e);
            const utils::Entity* getLightEntities(EntityId e) const noexcept;
            size_t getLightEntityCount(EntityId e) const noexcept;
            void updateAnimations();

            bool setBoneAnimationBuffer(
                EntityId entity,
                int length,
                const char** const boneNames,
                const char** const meshNames,
                const float* const frameData,
                int numFrames, 
                float frameLengthInMs);
            bool setMorphAnimationBuffer(
                EntityId entity, 
                const char* entityName, 
                const float* const morphData,     
                int numMorphWeights, 
                int numFrames, 
                float frameLengthInMs);
            void playAnimation(EntityId e, int index, bool loop, bool reverse);
            void stopAnimation(EntityId e, int index);
            void setMorphTargetWeights(const char* const entityName, float *weights, int count);
            void loadTexture(EntityId entity, const char* resourcePath, int renderableIndex);
            void setAnimationFrame(EntityId entity, int animationIndex, int animationFrame);
            
        private:
            LoadResource _loadResource;
            FreeResource _freeResource;
            AssetLoader* _assetLoader = nullptr;
            ResourceLoader* _resourceLoader = nullptr;
            NameComponentManager* _ncm = nullptr;
            Engine* _engine;
            Scene* _scene;
            MaterialProvider* _unlitProvider = nullptr;
            MaterialProvider* _ubershaderProvider = nullptr;
            gltfio::ResourceLoader* _gltfResourceLoader = nullptr;
            gltfio::TextureProvider* _stbDecoder = nullptr;
            vector<SceneAsset> _assets;
            tsl::robin_map<EntityId, int> _entityIdLookup;
 
            void setBoneTransform(
              FilamentInstance* instance,
                vector<BoneAnimationData> animations,
                int frameNumber
            );

            utils::Entity findEntityByName(
                SceneAsset asset, 
                const char* entityName
            );
            
            inline void updateTransform(SceneAsset asset);


    };
}
