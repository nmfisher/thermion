#pragma once

#include <utils/Entity.h>
#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/Scene.h>
#include <filament/Camera.h>
#include <filament/View.h>
#include <filament/Viewport.h>
#include <filament/RenderableManager.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/ResourceLoader.h>

#include <filament/IndexBuffer.h>
#include <filament/InstanceBuffer.h>

#include "c_api/ThermionDartApi.h"
#include "scene/SceneAsset.hpp"

namespace thermion
{

    using namespace filament;
    using namespace utils;

    class Gizmo : public SceneAsset
    {

    public:
        Gizmo(
            SceneAsset *sceneAsset,
            Engine *engine, 
            View *view, 
            Scene *scene, 
            Material *material);
        ~Gizmo() override;

        enum Axis
        {
            X,
            Y,
            Z
        };

        enum GizmoPickResultType { 
            AxisX,
            AxisY,
            AxisZ,
            Parent,
            None
        };


        const Aabb getBoundingBox() const override
        {
            return Aabb { };
        }
        
        typedef void (*GizmoPickCallback)(Gizmo::GizmoPickResultType result, float x, float y, float z);

        void pick(uint32_t x, uint32_t y, GizmoPickCallback callback);
        bool isGizmoEntity(Entity entity);

        SceneAssetType getType() override { return SceneAssetType::Gizmo; }
        utils::Entity getEntity() override { return _parent; }
        bool isInstance() override { return false; }
        SceneAsset *createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount) override { return nullptr; }
        MaterialInstance **getMaterialInstances() override { return _materialInstances.data(); }
        size_t getMaterialInstanceCount() override { return _materialInstances.size(); }

        void addAllEntities(Scene *scene) override
        {
            for (const auto &entity : _entities)
            {
                if (entity.isNull())
                {
                    continue;
                }
                scene->addEntity(entity);
            }
        }

        void removeAllEntities(Scene *scene) override
        {
            for (const auto &entity : _entities)
            {
                scene->remove(entity);
            }
        }

        size_t getInstanceCount() override { return 0; }
        SceneAsset *getInstanceByEntity(utils::Entity entity) override { return nullptr; }
        SceneAsset *getInstanceAt(size_t index) override { return nullptr; }

        size_t getChildEntityCount() override { return _entities.size() - 1; }
        const Entity *getChildEntities() override { return _entities.data() + 1; }

        Entity findEntityByName(const char *name) override
        {
            return utils::Entity::import(0);
        }

        void setPriority(RenderableManager &rm, int mask) override
        {
        }

        void setLayer(RenderableManager &rm, int layer) override
        {
        }

        void highlight(Gizmo::Axis axis);
        void unhighlight(Gizmo::Axis axis);

    private:
        class PickCallbackHandler
        {
        public:
            PickCallbackHandler(Gizmo *gizmo, GizmoPickCallback callback)
                : _gizmo(gizmo), _callback(callback) {}

            void handle(filament::View::PickingQueryResult const &result)
            {

                _gizmo->unhighlight(Gizmo::Axis::X);
                _gizmo->unhighlight(Gizmo::Axis::Y);    
                _gizmo->unhighlight(Gizmo::Axis::Z);

                Gizmo::GizmoPickResultType resultType;

                if (result.renderable == _gizmo->_parent)
                {
                    resultType = Gizmo::GizmoPickResultType::Parent;
                }
                else if (result.renderable == _gizmo->_x->getEntity())
                {
                    resultType = Gizmo::GizmoPickResultType::AxisX;
                    _gizmo->highlight(Gizmo::Axis::X);
                }
                else if (result.renderable == _gizmo->_y->getEntity())
                {
                    _gizmo->highlight(Gizmo::Axis::Y);
                    resultType = Gizmo::GizmoPickResultType::AxisY;
                }
                else if (result.renderable == _gizmo->_z->getEntity())
                {
                    _gizmo->highlight(Gizmo::Axis::Z);
                    resultType = Gizmo::GizmoPickResultType::AxisZ;
                } else { 
                    resultType = Gizmo::GizmoPickResultType::None;
                }

                _callback(resultType, result.fragCoords.x, result.fragCoords.y, result.fragCoords.z);
            }

        private:
            Gizmo *_gizmo;
            GizmoPickCallback _callback;
        };

        Entity createParentEntity();
        SceneAsset *createAxisInstance(Gizmo::Axis axis);

        math::mat4f getRotationForAxis(Gizmo::Axis axis);
        Entity getEntityForAxis(Gizmo::Axis axis)
        {
            switch (axis)
            {
            case Gizmo::Axis::X:
                return _x->getEntity();
            case Gizmo::Axis::Y:
                return _y->getEntity();
            case Gizmo::Axis::Z:
                return _z->getEntity();
            }
        }

        SceneAsset *_source;
        Engine *_engine;
        Scene *_scene;
        View *_view;
        Material *_material;

        utils::Entity _parent;
        SceneAsset *_x;
        SceneAsset *_y;
        SceneAsset *_z;

        std::vector<utils::Entity> _entities;
        std::vector<MaterialInstance *> _materialInstances;

        math::float4 activeColors[3]{
            math::float4{1.0f, 1.0f, 0.0f, 0.5f},
            math::float4{1.0f, 1.0f, 0.0f, 0.5f},
            math::float4{1.0f, 1.0f, 0.0f, 0.5f},
        };
        math::float4 inactiveColors[3]{
            math::float4{1.0f, 0.0f, 0.0f, 1.0f},
            math::float4{0.0f, 1.0f, 0.0f, 1.0f},
            math::float4{0.0f, 0.0f, 1.0f, 1.0f},
        };
    };

}