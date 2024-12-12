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
            Material *material) noexcept;

        Gizmo(Gizmo &&other) noexcept;

        ~Gizmo() override;

        enum Axis
        {
            X,
            Y,
            Z
        };

        enum GizmoPickResultType
        {
            AxisX,
            AxisY,
            AxisZ,
            Parent,
            None
        };

        const Aabb getBoundingBox() const override
        {
            return Aabb{};
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
            TRACE("addAllEntities called with %d entities", _entities.size());
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

                Gizmo::GizmoPickResultType resultType = _gizmo->getPickResult(result.renderable);

                _callback(resultType, result.fragCoords.x, result.fragCoords.y, result.fragCoords.z);
            }

        private:
            Gizmo *_gizmo;
            GizmoPickCallback _callback;
        };

        Entity createParentEntity();
        void createAxisInstance(Gizmo::Axis axis);

        math::mat4f getRotationForAxis(Gizmo::Axis axis);

    private:
        SceneAsset *_source;
        Engine *_engine;
        Scene *_scene;
        View *_view;
        Material *_material;

        float _scale = 8.0f;

        utils::Entity _parent;
        std::vector<SceneAsset *> _axes;
        std::vector<utils::Entity> _hitTest;

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

        GizmoPickResultType getPickResult(utils::Entity entity)
        {
            if (entity.isNull())
            {
                return Gizmo::GizmoPickResultType::None;
            }

            TRACE("Checking picked entity %d against gizmo axes with (%d axis hit test entities : %d %d %d)", entity, _hitTest.size(), _hitTest[0], _hitTest[1], _hitTest[2]);

            if (entity == _parent)
            {
                return GizmoPickResultType::Parent;
            }

            for (int axisIndex = 0; axisIndex < _axes.size(); axisIndex++)
            {
                auto axis = _axes[axisIndex];
                TRACE("Checking for axisindex %d with %d child entities", axisIndex, axis->getChildEntityCount());
                GizmoPickResultType result = GizmoPickResultType::None;
                if (entity == _hitTest[axisIndex])
                {
                    TRACE("MATCHED AXIS HIT TEST ENTITY for axisIndex %d", axisIndex);
                    result = GizmoPickResultType(axisIndex);
                }
                else
                {
                    if(entity == axis->getEntity()) {
                        TRACE("MATCHED AXIS HEAD ENTITY");
                        result = GizmoPickResultType(axisIndex);
                    } else {
                        for (int entityIndex = 0; entityIndex < axis->getChildEntityCount(); entityIndex++)
                        {
                            auto childEntity = axis->getChildEntities()[entityIndex];
                            
                            if (entity == childEntity)
                            {
                                TRACE("MATCHED AXIS CHILD ENTITY %d (index %d)", childEntity, entityIndex);
                                result = GizmoPickResultType(axisIndex);
                                break;
                            }
                            TRACE("Failed to match entity %d against axis child entity %d", entity, childEntity);
                        }
                    }
                }
                if (result != GizmoPickResultType::None)
                {
                    highlight(Gizmo::Axis(axisIndex));
                    return result;
                }
            }

            return Gizmo::GizmoPickResultType::None;
        }
    };

}