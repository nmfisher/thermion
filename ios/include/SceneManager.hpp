#pragma once

#include <mutex>
#include <vector>
#include <memory>
#include <map>

#include <filament/Scene.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/ResourceLoader.h>

#include <filament/IndexBuffer.h>
#include <filament/InstanceBuffer.h>

#include "material/gizmo.h"
#include "utils/NameComponentManager.h"
#include "ResourceBuffer.hpp"
#include "components/CollisionComponentManager.hpp"
#include "components/AnimationComponentManager.hpp"

#include "tsl/robin_map.h"

namespace flutter_filament
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
        SceneManager(const ResourceLoaderWrapper *const loader,
                     Engine *engine,
                     Scene *scene,
                     const char *uberArchivePath);
        ~SceneManager();

        EntityId loadGltf(const char *uri, const char *relativeResourcePath);

        ////
        /// @brief Load the GLB from the specified path, optionally creating multiple instances.
        /// @param uri the path to the asset. Should be either asset:// (representing a Flutter asset), or file:// (representing a filesystem file).
        /// @param numInstances the number of instances to create.
        /// @return an Entity representing the FilamentAsset associated with the loaded FilamentAsset.
        ///
        EntityId loadGlb(const char *uri, int numInstances);
        EntityId loadGlbFromBuffer(const uint8_t *data, size_t length, int numInstances = 1);
        EntityId createInstance(EntityId entityId);

        void remove(EntityId entity);
        void destroyAll();
        unique_ptr<vector<string>> getAnimationNames(EntityId entity);
        float getAnimationDuration(EntityId entity, int animationIndex);

        unique_ptr<vector<string>> getMorphTargetNames(EntityId entity, const char *name);
        void transformToUnitCube(EntityId e);
        inline void updateTransform(EntityId e);
        void setScale(EntityId e, float scale);
        void setPosition(EntityId e, float x, float y, float z);
        void setRotation(EntityId e, float rads, float x, float y, float z, float w);
        void queuePositionUpdate(EntityId e, float x, float y, float z, bool relative);
        void queueRotationUpdate(EntityId e, float rads, float x, float y, float z, float w, bool relative);
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

        bool setMorphTargetWeights(EntityId entityId, const float *const weights, int count);

        /// @brief Set the local transform for the bone at boneIndex/skinIndex in the given entity.
        /// @param entityId the parent entity
        /// @param entityName the name of the mesh under entityId for which the bone will be set.
        /// @param skinIndex the index of the joint skin. Currently only 0 is supported.
        /// @param boneName the name of the bone
        /// @param transform the 4x4 matrix representing the local transform for the bone
        /// @return true if the transform was successfully set, false otherwise
        bool setBoneTransform(EntityId entityId, const char *entityName, int skinIndex, const char *boneName, math::mat4f transform);

        /// @brief Set frame data to animate the given bones/entities.
        /// @param entity the parent entity
        /// @param frameData frame data as quaternions
        /// @param numFrames the number of frames
        /// @param boneName the name of the bone to animate
        /// @param meshName an array of mesh names under [entity] that should be animated
        /// @param numMeshTargets the number of meshes under [meshName]
        /// @param frameLengthInMs the length of each frame in ms
        /// @return true if the bone animation was successfully enqueued
        bool addBoneAnimation(
            EntityId entity,
            const float *const frameData,
            int numFrames,
            const char *const boneName,
            const char **const meshName,
            int numMeshTargets,
            float frameLengthInMs,
            bool isModelSpace);
        void resetBones(EntityId entityId);
        void playAnimation(EntityId e, int index, bool loop, bool reverse, bool replaceActive, float crossfade = 0.3f);
        void stopAnimation(EntityId e, int index);
        void setMorphTargetWeights(const char *const entityName, float *weights, int count);
        void loadTexture(EntityId entity, const char *resourcePath, int renderableIndex);
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
        void setParent(EntityId child, EntityId parent);
        bool addAnimationComponent(EntityId entity);

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

        /// @brief returns the gizmo entity, used to manipulate the global transform for entities
        /// @param out a pointer to an array of three EntityId {x, y, z}
        /// @return
        ///
        void getGizmo(EntityId *out);

        friend class FilamentViewer;

    private:
        gltfio::AssetLoader *_assetLoader = nullptr;
        const ResourceLoaderWrapper *const _resourceLoaderWrapper;
        Engine *_engine;
        Scene *_scene;
        gltfio::MaterialProvider *_ubershaderProvider = nullptr;
        gltfio::ResourceLoader *_gltfResourceLoader = nullptr;
        gltfio::TextureProvider *_stbDecoder = nullptr;
        gltfio::TextureProvider *_ktxDecoder = nullptr;
        std::mutex _mutex;
        Material *_gizmoMaterial;

        utils::NameComponentManager *_ncm;

        tsl::robin_map<
            EntityId,
            gltfio::FilamentInstance *>
            _instances;
        tsl::robin_map<EntityId, gltfio::FilamentAsset *> _assets;
        tsl::robin_map<EntityId, std::tuple<math::float3, bool, math::quatf, bool, float>> _transformUpdates;

        AnimationComponentManager *_animationComponentManager = nullptr;
        CollisionComponentManager *_collisionComponentManager = nullptr;

        gltfio::FilamentInstance *getInstanceByEntityId(EntityId entityId);
        gltfio::FilamentAsset *getAssetByEntityId(EntityId entityId);

        utils::Entity findEntityByName(
            const gltfio::FilamentInstance *instance,
            const char *entityName);

        EntityId addGizmo();
        utils::Entity _gizmoX;
        utils::Entity _gizmoY;
        utils::Entity _gizmoZ;
    };
}
