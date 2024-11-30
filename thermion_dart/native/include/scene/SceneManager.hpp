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

#include "tsl/robin_map.h"

#include "AnimationManager.hpp"
#include "CustomGeometry.hpp"
#include "Gizmo.hpp"
#include "GridOverlay.hpp"
#include "ResourceBuffer.hpp"
#include "SceneAsset.hpp"

#include "components/CollisionComponentManager.hpp"

namespace thermion
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
        SceneManager(
            const ResourceLoaderWrapperImpl *const loader,
            Engine *engine,
            Scene *scene,
            const char *uberArchivePath,
            Camera *mainCamera);
        ~SceneManager();

        enum LAYERS
        {
            DEFAULT_ASSETS = 0,
            BACKGROUND = 6,
            OVERLAY = 7,
        };

        ////
        /// @brief Load the glTF file from the specified path and adds all entities to the scene.
        /// @param uri the path to the asset. Should be either asset:// (representing a Flutter asset), or file:// (representing a filesystem file).
        /// @param relativeResourcePath the (relative) path to the asset's resources.
        /// @return the glTF entity.
        ///
        SceneAsset* loadGltf(const char *uri, const char *relativeResourcePath, int numInstances = 1, bool keepData = false);

        ////
        /// @brief Load the GLB from the specified path, optionally creating multiple instances.
        /// @param uri the path to the asset. Should be either asset:// (representing a Flutter asset), or file:// (representing a filesystem file).
        /// @param numInstances the number of instances to create. Must be at least 1.
        /// @return an Entity representing the FilamentAsset associated with the loaded FilamentAsset.
        ///
        SceneAsset* loadGlb(const char *uri, int numInstances, bool keepData);
        
        /// @brief 
        /// @param data 
        /// @param length 
        /// @param numInstances 
        /// @param keepData 
        /// @param priority 
        /// @param layer 
        /// @param loadResourcesAsync 
        /// @return 
        SceneAsset* loadGlbFromBuffer(const uint8_t *data, size_t length, int numInstances = 1, bool keepData = false, int priority = 4, int layer = 0, bool loadResourcesAsync = false);

        ///
        /// Creates an instance of the given entity.
        /// This may return an instance from a pool of inactive instances; see [remove] for more information.
        /// If [materialInstances] is provided, these wil
        ///
        SceneAsset* createInstance(SceneAsset* asset, MaterialInstance **materialInstances = nullptr, size_t materialInstanceCount = 0);

        /// @brief Removes the asset (and all its child entities) from the scene and "destroys" all resources.
        /// If the asset is not an instance, the asset will be deleted.
        /// If the asset is an instance, [remove] is not guaranted to delete the asset. It may be returned to a pool of inactive instances.
        /// From the user's perspective, this can be considered as destroyed.
        /// @param entity
        void destroy(SceneAsset* entity);

        /// @brief Destroys all assets, scenes, materials, etc.
        ///
        void destroyAll();
        
        /// @brief 
        /// @param entityId 
        void transformToUnitCube(EntityId entityId);

        /// @brief 
        /// @param entities 
        /// @param transforms 
        /// @param numEntities 
        void queueTransformUpdates(EntityId *entities, math::mat4 *transforms, int numEntities);

        /// @brief 
        /// @param entity 
        /// @param viewportCoordX 
        /// @param viewportCoordY 
        /// @param x 
        /// @param y 
        /// @param z 
        void queueRelativePositionUpdateWorldAxis(EntityId entity, float viewportCoordX, float viewportCoordY, float x, float y, float z);
        
        /// @brief 
        /// @param view 
        /// @param entityId 
        /// @param viewportCoordX 
        /// @param viewportCoordY 
        void queueRelativePositionUpdateFromViewportVector(View *view, EntityId entityId, float viewportCoordX, float viewportCoordY);

        const utils::Entity *getCameraEntities(EntityId e);
        size_t getCameraEntityCount(EntityId e);
        const utils::Entity *getLightEntities(EntityId e) noexcept;
        size_t getLightEntityCount(EntityId e) noexcept;

        /// @brief 
        void update();


        /// @brief 
        /// @param data 
        /// @param length 
        /// @param name 
        /// @return 
        Texture *createTexture(const uint8_t *data, size_t length, const char *name);

        /// @brief 
        /// @param entityId 
        /// @param texture 
        /// @param slotName 
        /// @param materialIndex 
        /// @return 
        bool applyTexture(EntityId entityId, Texture *texture, const char *slotName, int materialIndex);

        /// @brief 
        /// @param texture 
        void destroyTexture(Texture *texture);

        /// @brief 
        /// @param entity 
        /// @return 
        bool removeFromScene(EntityId entity);
        
        /// @brief 
        /// @param entity 
        /// @return 
        bool addToScene(EntityId entity);
        
        /// @brief 
        /// @param entity 
        /// @param onCollisionCallback 
        /// @param affectsCollidingTransform 
        void addCollisionComponent(EntityId entity, void (*onCollisionCallback)(const EntityId entityId1, const EntityId entityId2), bool affectsCollidingTransform);
        
        /// @brief 
        /// @param entityId 
        ///
        ///
        void removeCollisionComponent(EntityId entityId);

        /// @brief 
        /// @param entity 
        void testCollisions(EntityId entity);

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
        Aabb2 getScreenSpaceBoundingBox(View *view, EntityId entity);

        /// @brief returns the 3D bounding box of the renderable instance for the given entity.
        /// @return the bounding box
        ///
        Aabb3 getRenderableBoundingBox(EntityId entity);

        ///
        /// Creates an entity with the specified geometry/material/normals and adds to the scene.
        /// If [keepData] is true, stores
        ///
        SceneAsset *createGeometry(
            float *vertices,
            uint32_t numVertices,
            float *normals,
            uint32_t numNormals,
            float *uvs,
            uint32_t numUvs,
            uint16_t *indices,
            uint32_t numIndices,
            filament::RenderableManager::PrimitiveType primitiveType = RenderableManager::PrimitiveType::TRIANGLES,
            MaterialInstance **materialInstances = nullptr,
            size_t materialInstanceCount = 0,
            bool keepData = false);


        gltfio::MaterialProvider *const getUnlitMaterialProvider()
        {
            return _unlitMaterialProvider;
        }

        gltfio::MaterialProvider *const getUbershaderMaterialProvider()
        {
            return _ubershaderProvider;
        }

        /// @brief 
        /// @param materialInstance 
        void destroy(MaterialInstance *materialInstance);

        /// @brief 
        /// @return 
        MaterialInstance *createUnlitFixedSizeMaterialInstance();

        /// @brief 
        /// @return 
        MaterialInstance *createUnlitMaterialInstance();

        /// @brief 
        /// @param entityId 
        /// @param layer 
        void setVisibilityLayer(EntityId entityId, int layer);

        /// @brief 
        /// @return 
        Camera *createCamera();

        /// @brief 
        /// @param camera 
        void destroyCamera(Camera *camera);

        /// @brief 
        /// @return 
        size_t getCameraCount();

        /// @brief 
        /// @param index 
        /// @return 
        Camera *getCameraAt(size_t index);

        /// @brief 
        /// @param view 
        /// @param scene 
        /// @return 
        Gizmo *createGizmo(View *view, Scene *scene);


        /// @brief 
        /// @return 
        Scene *getScene()
        {
            return _scene;
        }

        /// @brief 
        /// @return 
        AnimationManager *getAnimationManager() { 
            return _animationManager.get();
        }

        /// @brief 
        /// @return 
        NameComponentManager *getNameComponentManager() { 
            return _ncm;
        }

        SceneAsset *createGrid();

        bool isGridEntity(utils::Entity entity);

    private:
        gltfio::AssetLoader *_assetLoader = nullptr;
        const ResourceLoaderWrapperImpl *const _resourceLoaderWrapper;
        Engine *_engine = nullptr;
        Scene *_scene = nullptr;
        Camera *_mainCamera;

        gltfio::MaterialKey _defaultUnlitConfig;

        gltfio::MaterialProvider *_ubershaderProvider = nullptr;
        gltfio::MaterialProvider *_unlitMaterialProvider = nullptr;
        gltfio::ResourceLoader *_gltfResourceLoader = nullptr;
        gltfio::TextureProvider *_stbDecoder = nullptr;
        gltfio::TextureProvider *_ktxDecoder = nullptr;
        std::mutex _mutex;
        std::vector<MaterialInstance *> _materialInstances;

        Material *_unlitFixedSizeMaterial = nullptr;

        utils::NameComponentManager *_ncm;

        tsl::robin_map<EntityId, math::mat4> _transformUpdates;
        std::set<Texture *> _textures;
        std::vector<Camera *> _cameras;
        std::vector<std::unique_ptr<SceneAsset>> _sceneAssets;
        std::vector<std::unique_ptr<Gizmo>> _gizmos;

        std::unique_ptr<AnimationManager> _animationManager = std::nullptr_t();
        std::unique_ptr<CollisionComponentManager> _collisionComponentManager = std::nullptr_t();

        std::unique_ptr<GridOverlay> _grid = std::nullptr_t();

        void _updateTransforms();
    };
}
