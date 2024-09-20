#pragma once

#include <mutex>
#include <vector>
#include <memory>
#include <map>
#include <set>

#include <filament/Scene.h>
#include <filament/Camera.h>
#include <filament/View.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/ResourceLoader.h>

#include <filament/IndexBuffer.h>
#include <filament/InstanceBuffer.h>
#include <utils/NameComponentManager.h>

#include "material/gizmo.h"

#include "CustomGeometry.hpp"
#include "Gizmo.hpp"
#include "APIBoundaryTypes.h"
#include "GridOverlay.hpp"
#include "ResourceBuffer.hpp"
#include "components/CollisionComponentManager.hpp"
#include "components/AnimationComponentManager.hpp"

#include "tsl/robin_map.h"


namespace thermion_filament
{
    typedef int32_t EntityId;

    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using std::string;
    using std::unique_ptr;
    using std::vector;

    class SceneManager
    {
    public:
        SceneManager(View* view,
                    const ResourceLoaderWrapperImpl *const loader,
                     Engine *engine,
                     Scene *scene,
                     const char *uberArchivePath);
        ~SceneManager();

        enum LAYERS {
            DEFAULT_ASSETS = 0,
            BACKGROUND = 6,
            OVERLAY = 7,
        };

        class HighlightOverlay {
            public:
                HighlightOverlay(EntityId id, SceneManager* const sceneManager, Engine* const engine, float r, float g, float b);
                ~HighlightOverlay();

                bool isValid() {
                    return !_entity.isNull();
                }

            private:
                MaterialInstance* _highlightMaterialInstance = nullptr;
                bool _isGeometryEntity = false;
                bool _isGltfAsset = false;
                FilamentInstance* _newInstance = nullptr;
                Entity _entity;
                Engine* const _engine;
                SceneManager* const _sceneManager;                
        };
        
        ////
        /// @brief Load the glTF file from the specified path and adds all entities to the scene.
        /// @param uri the path to the asset. Should be either asset:// (representing a Flutter asset), or file:// (representing a filesystem file).
        /// @param relativeResourcePath the (relative) path to the asset's resources. 
        /// @return the glTF entity.
        ///
        EntityId loadGltf(const char *uri, const char *relativeResourcePath, bool keepData = false);

        ////
        /// @brief Load the GLB from the specified path, optionally creating multiple instances.
        /// @param uri the path to the asset. Should be either asset:// (representing a Flutter asset), or file:// (representing a filesystem file).
        /// @param numInstances the number of instances to create.
        /// @return an Entity representing the FilamentAsset associated with the loaded FilamentAsset.
        ///
        EntityId loadGlb(const char *uri, int numInstances, bool keepData);
        EntityId loadGlbFromBuffer(const uint8_t *data, size_t length, int numInstances = 1, bool keepData = false, int priority = 4, int layer = 0);
        EntityId createInstance(EntityId entityId);

        void remove(EntityId entity);
        void destroyAll();
        unique_ptr<vector<string>> getAnimationNames(EntityId entity);
        float getAnimationDuration(EntityId entity, int animationIndex);

        unique_ptr<vector<string>> getMorphTargetNames(EntityId assetEntityId, EntityId childEntity);
        unique_ptr<vector<string>> getBoneNames(EntityId assetEntityId, EntityId childEntity);
        void transformToUnitCube(EntityId e);
        inline void updateTransform(EntityId e);
        void setScale(EntityId e, float scale);
        void setPosition(EntityId e, float x, float y, float z);
        void setRotation(EntityId e, float rads, float x, float y, float z, float w);
        void queuePositionUpdate(EntityId e, float x, float y, float z, bool relative);
        void queueRotationUpdate(EntityId e, float rads, float x, float y, float z, float w, bool relative);
        void queueRelativePositionUpdateWorldAxis(EntityId entity, float viewportCoordX, float viewportCoordY, float x, float y, float z);
        void queueRelativePositionUpdateFromViewportVector(EntityId entityId, float viewportCoordX, float viewportCoordY);
        const utils::Entity *getCameraEntities(EntityId e);
        size_t getCameraEntityCount(EntityId e);
        const utils::Entity *getLightEntities(EntityId e) noexcept;
        size_t getLightEntityCount(EntityId e) noexcept;

        void updateAnimations();
        void updateTransforms();
        void testCollisions(EntityId entity);
        bool setMaterialColor(EntityId e, const char *meshName, int materialInstance, const float r, const float g, const float b, const float a);

        bool setMorphAnimationBuffer(
            EntityId entityId,
            const float *const morphData,
            const int *const morphIndices,
            int numMorphTargets,
            int numFrames,
            float frameLengthInMs);

        void clearMorphAnimationBuffer(
            EntityId entityId);

        bool setMorphTargetWeights(EntityId entityId, const float *const weights, int count);

        math::mat4f getLocalTransform(EntityId entityId);
        math::mat4f getWorldTransform(EntityId entityId);
        EntityId getBone(EntityId entityId, int skinIndex, int boneIndex);
        math::mat4f getInverseBindMatrix(EntityId entityId, int skinIndex, int boneIndex);

        /// @brief Set the local transform for the bone at boneIndex/skinIndex in the given entity.
        /// @param entityId the parent entity
        /// @param entityName the name of the mesh under entityId for which the bone will be set.
        /// @param skinIndex the index of the joint skin. Currently only 0 is supported.
        /// @param boneName the name of the bone
        /// @param transform the 4x4 matrix representing the local transform for the bone
        /// @return true if the transform was successfully set, false otherwise
        bool setBoneTransform(EntityId entityId, int skinIndex, int boneIndex, math::mat4f transform);

        /// @brief Immediately start animating the bone at [boneIndex] under the parent instance [entity] at skin [skinIndex].
        /// @param entity the mesh entity to animate
        /// @param frameData frame data as quaternions
        /// @param numFrames the number of frames
        /// @param boneName the name of the bone to animate
        /// @param frameLengthInMs the length of each frame in ms
        /// @return true if the bone animation was successfully enqueued
        bool addBoneAnimation(
            EntityId parent,
            int skinIndex,
            int boneIndex,
            const float *const frameData,
            int numFrames,
            float frameLengthInMs,
            float fadeOutInSecs,
            float fadeInInSecs,
            float maxDelta
        );

        std::unique_ptr<std::vector<math::mat4f>> getBoneRestTranforms(EntityId entityId, int skinIndex);
        void resetBones(EntityId entityId);
        bool setTransform(EntityId entityId, math::mat4f transform);
        bool updateBoneMatrices(EntityId entityId);
        void playAnimation(EntityId e, int index, bool loop, bool reverse, bool replaceActive, float crossfade = 0.3f, float startOffset = 0.0f);
        void stopAnimation(EntityId e, int index);
        void setMorphTargetWeights(const char *const entityName, float *weights, int count);
        
        Texture* createTexture(const uint8_t* data, size_t length, const char* name);
        bool applyTexture(EntityId entityId, Texture *texture, const char* slotName, int materialIndex);
        void destroyTexture(Texture* texture);
        
        void setAnimationFrame(EntityId entity, int animationIndex, int animationFrame);
        bool hide(EntityId entity, const char *meshName);
        bool reveal(EntityId entity, const char *meshName);
        const char *getNameForEntity(EntityId entityId);
        utils::Entity findChildEntityByName(
            EntityId entityId,
            const char *entityName);
        int getEntityCount(EntityId entity, bool renderableOnly);
        void getEntities(EntityId entity, bool renderableOnly, EntityId *out);
        const char *getEntityNameAt(EntityId entity, int index, bool renderableOnly);
        void addCollisionComponent(EntityId entity, void (*onCollisionCallback)(const EntityId entityId1, const EntityId entityId2), bool affectsCollidingTransform);
        void removeCollisionComponent(EntityId entityId);
        EntityId getParent(EntityId child);
        EntityId getAncestor(EntityId child);
        void setParent(EntityId child, EntityId parent, bool preserveScaling);
        bool addAnimationComponent(EntityId entity);
        void removeAnimationComponent(EntityId entity);

        /// @brief renders an outline around the specified entity.
        ///
        ///
        void setStencilHighlight(EntityId entity, float r, float g, float b);

        /// @brief removes the outline around the specified entity.
        ///
        ///        
        void removeStencilHighlight(EntityId entity);

        /// @brief returns the number of instances of the FilamentAsset represented by the given entity.
        /// @param entityId
        /// @return the number of instances
        int getInstanceCount(EntityId entityId);

        /// @brief returns an array containing all instances of the FilamentAsset represented by the given entity.
        /// @param entityId
        void getInstances(EntityId entityId, EntityId *out);

        ///
        /// Sets the draw priority for the given entity. See RenderableManager.h for more details.
        ///
        void setPriority(EntityId entity, int priority);

        /// @brief returns the 2D min/max viewport coordinates of the bounding box for the specified enitty;
        /// @param out a pointer large enough to store four floats (the min/max coordinates of the bounding box)
        /// @return
        ///
        Aabb2 getBoundingBox(EntityId entity);

        ///
        /// Toggles the visibility of the given layer.
        ///
        void setLayerVisibility(SceneManager::LAYERS layer, bool enabled);

        ///
        /// Creates an entity with the specified geometry/material/normals and adds to the scene.
        /// If [keepData] is true, stores 
        ///
        EntityId createGeometry(
            float *vertices, 
            uint32_t numVertices, 
            float *normals,
            uint32_t numNormals,
            float *uvs,
            uint32_t numUvs,
            uint16_t *indices, 
            uint32_t numIndices, 
            filament::RenderableManager::PrimitiveType primitiveType = RenderableManager::PrimitiveType::TRIANGLES, 
            MaterialInstance* materialInstance = nullptr,
            bool keepData = false
        );

        friend class FilamentViewer;

        Gizmo* gizmo = nullptr;

        gltfio::MaterialProvider * const unlitMaterialProvider() {
            return _unlitMaterialProvider;
        }

        bool isGeometryEntity(EntityId entity) {
            return _geometry.find(entity) != _geometry.end();
        }

        const CustomGeometry* const getGeometry(EntityId entityId) {
            return _geometry[entityId].get();
        }

        Scene* const getScene() { 
            return _scene;
        }

        bool isGltfAsset(EntityId entity) {
            return getAssetByEntityId(entity) != nullptr;
        }

        gltfio::FilamentInstance *getInstanceByEntityId(EntityId entityId);
        gltfio::FilamentAsset *getAssetByEntityId(EntityId entityId);

        gltfio::FilamentInstance *createGltfAssetInstance(FilamentAsset* asset) {
            return _assetLoader->createInstance(asset);
        }

        MaterialInstance* getMaterialInstanceAt(EntityId entityId, int materialIndex);

        void setMaterialProperty(EntityId entity, int materialIndex, const char* property, float value);
        void setMaterialProperty(EntityId entity, int materialIndex, const char* property, int32_t value);
        void setMaterialProperty(EntityId entityId, int materialIndex, const char* property, filament::math::float4& value);
        void setMaterialDepthWrite(EntityId entityId, int materialIndex, bool enabled);

        MaterialInstance* createUbershaderMaterialInstance(MaterialKey key);
        void destroy(MaterialInstance* materialInstance);

        gltfio::MaterialProvider* getUbershaderProvider() {
            return _ubershaderProvider;
        }

        MaterialInstance* createUnlitMaterialInstance();

        void setVisibilityLayer(EntityId entityId, int layer);

    private:
        gltfio::AssetLoader *_assetLoader = nullptr;
        const ResourceLoaderWrapperImpl *const _resourceLoaderWrapper;
        Engine *_engine = nullptr;
        Scene *_scene = nullptr;       
        View* _view = nullptr;

        gltfio::MaterialProvider *_ubershaderProvider = nullptr;
        gltfio::MaterialProvider *_unlitMaterialProvider = nullptr;
        gltfio::ResourceLoader *_gltfResourceLoader = nullptr;
        gltfio::TextureProvider *_stbDecoder = nullptr;
        gltfio::TextureProvider *_ktxDecoder = nullptr;
        std::mutex _mutex;
        std::mutex _stencilMutex;

        utils::NameComponentManager *_ncm;

        tsl::robin_map<
            EntityId,
            gltfio::FilamentInstance *>
            _instances;
        tsl::robin_map<EntityId, gltfio::FilamentAsset *> _assets;
        tsl::robin_map<EntityId, unique_ptr<CustomGeometry>> _geometry;
        tsl::robin_map<EntityId, unique_ptr<HighlightOverlay>> _highlighted;        
        tsl::robin_map<EntityId, std::tuple<math::float3, bool, math::quatf, bool, float>> _transformUpdates;
        std::set<Texture*> _textures;

        AnimationComponentManager *_animationComponentManager = nullptr;
        CollisionComponentManager *_collisionComponentManager = nullptr;

        utils::Entity findEntityByName(
            const gltfio::FilamentInstance *instance,
            const char *entityName);

        GridOverlay* _gridOverlay = nullptr;     
        

    };
}
