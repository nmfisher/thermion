#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>

#include <utils/Entity.h>
#include <utils/EntityManager.h>

#include <gltfio/math.h>

#include "scene/Gizmo.hpp"
#include "scene/SceneManager.hpp"

#include "material/gizmo.h"

#include "Log.hpp"

namespace thermion
{

    using namespace filament::gltfio;

    Gizmo::Gizmo(
        SceneAsset *sceneAsset,
        Engine *engine,
        View *view,
        Scene *scene,
        Material *material) noexcept : _source(sceneAsset),
                                       _engine(engine),
                                       _view(view),
                                       _scene(scene),
                                       _material(material)
    {
        auto &entityManager = _engine->getEntityManager();

        _parent = entityManager.create();
        RenderableManager::Builder(1)               // 1 primitive
            .boundingBox({{-1, -1, -1}, {1, 1, 1}}) // Set a basic bounding box
            .culling(false)                         // Disable culling since this is a UI element
            .castShadows(false)                     // UI elements typically don't cast shadows
            .receiveShadows(false)

            .build(*_engine, _parent); // Bu
        auto &tm = _engine->getTransformManager();
        auto parentTransformInstance = tm.getInstance(_parent);
        tm.setTransform(parentTransformInstance, math::mat4f());

        TRACE("Created Gizmo parent entity %d", _parent);
        _entities.push_back(_parent);

        createAxisInstance(Axis::X);
        createAxisInstance(Axis::Y);
        createAxisInstance(Axis::Z);
    }

    // move constructor so we don't re-create all entities/materials when moving
    Gizmo::Gizmo(Gizmo &&other) noexcept : _source(other._source),
                                           _engine(other._engine),
                                           _view(other._view),
                                           _scene(other._scene),
                                           _material(other._material),
                                           _parent(other._parent),
                                           _scale(other._scale),
                                           _entities(std::move(other._entities)),
                                           _materialInstances(std::move(other._materialInstances)),
                                           _hitTest(std::move(other._hitTest)),
                                           _axes(std::move(other._axes))
    {
        other._source = nullptr;
        other._engine = nullptr;
        other._view = nullptr;
        other._scene = nullptr;
        other._material = nullptr;
        other._parent = {};
    }

    void Gizmo::createAxisInstance(Gizmo::Axis axis)
    {
        auto &rm = _engine->getRenderableManager();

        auto *materialInstance = _material->createInstance();
        _materialInstances.push_back(materialInstance);
        auto instance = _source->createInstance(&materialInstance, 1);

        TRACE("Created Gizmo axis glTF instance with head entity %d", instance->getEntity());
        materialInstance->setParameter("baseColorFactor", inactiveColors[axis]);
        materialInstance->setParameter("scale", _scale);

        auto hitTestEntity = instance->findEntityByName("HitTest");
        TRACE("Created hit test entity %d for axis %d", hitTestEntity, axis);
        _hitTest.push_back(hitTestEntity);

        if (hitTestEntity.isNull())
        {
            TRACE("Hit test entity not found");
        }
        else
        {
            auto renderableInstance = rm.getInstance(hitTestEntity);
            if (!renderableInstance.isValid())
            {
                TRACE("Failed to find renderable for hit test entity");
            }
            else
            {
                auto *hitTestMaterialInstance = _material->createInstance();
                _materialInstances.push_back(hitTestMaterialInstance);
                hitTestMaterialInstance->setParameter("baseColorFactor", math::float4{0.0f, 0.0f, 0.0f, 0.0f});
                hitTestMaterialInstance->setParameter("scale", _scale);
                rm.setMaterialInstanceAt(renderableInstance, 0, hitTestMaterialInstance);
            }
        }

        auto transform = getRotationForAxis(axis);

        TRACE("Created Gizmo axis instance for axis %d", axis);

        auto &tm = _engine->getTransformManager();
        auto transformInstance = tm.getInstance(instance->getEntity());
        tm.setTransform(transformInstance, transform);

        // parent this entity's transform to the Gizmo _parent entity
        auto parentTransformInstance = tm.getInstance(_parent);
        if (parentTransformInstance.isValid())
        {
            tm.setParent(transformInstance, parentTransformInstance);
        }
        else
        {
            TRACE("WARNING: parent transform instance not valid.");
        }

        _entities.push_back(instance->getEntity());

        TRACE("Added entity %d for axis %d", instance->getEntity(), axis);

        for (int i = 0; i < instance->getChildEntityCount(); i++)
        {
            auto entity = instance->getChildEntities()[i];
            _entities.push_back(entity);
            TRACE("Added entity %d for axis %d", entity, axis);
            auto renderable = rm.getInstance(entity);
            if (renderable.isValid())
            {
                rm.setPriority(renderable, 7);
            }
        }

        _axes.push_back(instance);
    }

    Gizmo::~Gizmo()
    {
        _scene->removeEntities(_entities.data(), _entities.size());

        for (auto entity : _entities)
        {
            _engine->destroy(entity);
        }

        for (auto *materialInstance : _materialInstances)
        {
            _engine->destroy(materialInstance);
        }
    }

    void Gizmo::highlight(Gizmo::Axis axis)
    {
        auto &rm = _engine->getRenderableManager();
        auto instance = _axes[axis];

        for (int i = 0; i < instance->getChildEntityCount(); i++)
        {
            auto childEntity = instance->getChildEntities()[i];
            if (childEntity == _hitTest[axis])
            {
                continue;
            }
            auto renderableInstance = rm.getInstance(childEntity);
            if (renderableInstance.isValid())
            {
                auto *materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);
                math::float4 baseColor = activeColors[axis];
                materialInstance->setParameter("baseColorFactor", baseColor);
            }
        }
    }

    void Gizmo::unhighlight(Gizmo::Axis axis)
    {
        auto &rm = _engine->getRenderableManager();

        auto instance = _axes[axis];

        for (int i = 0; i < instance->getChildEntityCount(); i++)
        {
            auto childEntity = instance->getChildEntities()[i];
            if (childEntity == _hitTest[axis])
            {
                continue;
            }
            auto renderableInstance = rm.getInstance(childEntity);
            if (renderableInstance.isValid())
            {
                auto *materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);
                math::float4 baseColor = inactiveColors[axis];
                materialInstance->setParameter("baseColorFactor", baseColor);
            }
        }
    }

    void Gizmo::pick(uint32_t x, uint32_t y, GizmoPickCallback callback)
    {

        auto handler = new Gizmo::PickCallbackHandler(this, callback);
        _view->pick(x, y, [=](filament::View::PickingQueryResult const &result)
                    { 
                        handler->handle(result); 
                        delete handler; });
    }

    bool Gizmo::isGizmoEntity(Entity e)
    {
        return std::find(_entities.begin(), _entities.end(), e) != _entities.end();
    }

    math::mat4f Gizmo::getRotationForAxis(Gizmo::Axis axis)
    {

        math::mat4f transform;

        switch (axis)
        {
        case Axis::X:
            transform = math::mat4f::rotation(math::F_PI_2, math::float3{0, 1, 0});
            break;
        case Axis::Y:
            transform = math::mat4f::rotation(-math::F_PI_2, math::float3{1, 0, 0});
            break;
        case Axis::Z:
            break;
        }
        return transform;
    }

}
