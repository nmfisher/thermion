#pragma once

#include <memory>
#include <string>
#include <vector>

#include <filament/IndexBuffer.h>
#include <filament/Scene.h>
#include <filament/VertexBuffer.h>
#include <math.h>
#include <math/mat4.h>
#include <utils/Entity.h>

#include "CustomGeometry.hpp"
#include "Log.hpp"
#include "c_api/APIBoundaryTypes.h"

namespace thermion {

using namespace filament;
using namespace utils;

enum SceneLayer {
    DefaultAsset = 0,
    Background = 6,
    Overlay = 7,
};

class SceneAsset {

    public:
        enum SceneAssetType { Gltf, Geometry, Light, Skybox, Ibl, Image, Gizmo };
        
        virtual ~SceneAsset() {
            
        }

        virtual SceneAssetType getType() = 0;
        
        virtual utils::Entity getEntity() {
            return utils::Entity::import(0);
        }
        
        virtual bool isInstance() = 0;
        virtual SceneAsset* getInstanceOwner() = 0;
        virtual void destroyInstance(SceneAsset *instance) = 0;

        virtual SceneAsset* createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount) = 0;

        virtual MaterialInstance **getMaterialInstances() = 0;
        virtual size_t getMaterialInstanceCount() = 0;
        virtual void addAllEntities(Scene *scene) = 0;
        virtual void removeAllEntities(Scene *scene) = 0;

        virtual size_t getInstanceCount() = 0;
        virtual SceneAsset *getInstanceByEntity(utils::Entity entity) = 0;
        virtual SceneAsset *getInstanceAt(size_t index) = 0;
        virtual size_t getChildEntityCount() = 0;
        virtual const Entity* getChildEntities() = 0;
        virtual Entity findEntityByName(const char* name) = 0;

        virtual const filament::Aabb getBoundingBox() const = 0;

        virtual uint32_t getGeometryCapabilities() const {
            return SCENE_ASSET_GEOMETRY_CAPABILITY_NONE;
        }

        virtual bool supportsFlatShading() const {
            return false;
        }

        virtual TVertexBufferStorageMode getVertexBufferStorageMode(size_t primitiveIndex) const {
            return VERTEX_BUFFER_STORAGE_MODE_UNKNOWN;
        }

        virtual size_t getBoneCount(size_t skinIndex) const {
            return 0;
        }

        virtual const Entity *getBones(size_t skinIndex) const {
            return nullptr;
        }

        virtual const char *getBoneName(size_t skinIndex, size_t boneIndex) const {
            return nullptr;
        }

        /// Morph target names (glTF extras metadata) for the given child
        /// entity. Asset types without morph target metadata return empty.
        virtual std::vector<std::string> getMorphTargetNames(utils::Entity childEntity) const {
            return {};
        }

        /// The asset whose entity carries the runtime bone animation
        /// component. Defaults to the asset itself. Owner assets whose
        /// getEntity() differs from their instances' entities (e.g. glTF
        /// owners) override this to return the instance that skin/bone
        /// operations target, so add/remove of the bone animation component
        /// always resolve to the same entity. Returns nullptr when no
        /// instance exists yet.
        virtual SceneAsset *getSkinTarget() {
            return this;
        }

        /// Skinning interface. Joint entities/counts/names are exposed by
        /// getBones/getBoneCount/getBoneName above; the accessors below
        /// complete the gltfio-free skin interface used by runtime bone
        /// animation. Asset types without skins return 0 / nullptr / no-op.
        virtual size_t getSkinCount() const {
            return 0;
        }

        /// Inverse bind matrices for all joints of the given skin (i.e.
        /// getBoneCount(skinIndex) matrices), or nullptr when unavailable.
        virtual const math::mat4f *getInverseBindMatrices(size_t skinIndex) const {
            return nullptr;
        }

        /// Recompute and upload GPU bone matrices from the current joint
        /// transforms. No-op for asset types without skinned renderables.
        virtual void updateBoneMatrices() {
        }

        /// Geometry buffer accessors. Asset types without accessible geometry
        /// buffers return nullptr; instances resolve to their owning asset.
        virtual VertexBuffer *getVertexBuffer(size_t primitiveIndex) const {
            return nullptr;
        }

        virtual IndexBuffer *getIndexBuffer(size_t primitiveIndex) const {
            return nullptr;
        }

        /// Light/camera entity accessors. Only glTF owner assets carry light
        /// and camera entities; everything else returns nullptr / -1.
        virtual const Entity *getLightEntities() const {
            return nullptr;
        }

        virtual size_t getLightEntityCount() const {
            return -1;
        }

        virtual const Entity *getCameraEntities() const {
            return nullptr;
        }

        virtual size_t getCameraEntityCount() const {
            return -1;
        }

        /// Starting primitive offset for the given entity, or -1 when the
        /// asset has no preserved geometry for it.
        virtual int getPrimitiveOffsetForEntity(utils::Entity entity) const {
            return -1;
        }

        /// Release underlying source data early. No-op for asset types
        /// without releasable source data; instances log and do nothing.
        virtual void releaseSourceData() {
            Log("releaseSourceData only supported on glTF assets");
        }

        /// Toggle flat (per-face) shading. No-op for asset types without
        /// flat-shading support; instances apply it to their owning asset.
        virtual void setFlatShading(bool flatShading) {
            Log("setFlatShading only supported on glTF assets");
        }

};
}
