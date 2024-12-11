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
        Material *material
    ) : _source(sceneAsset), 
        _engine(engine),
        _view(view),
        _scene(scene),
        _material(material)
    {
        auto &entityManager = _engine->getEntityManager();

        _parent = entityManager.create();

        _z = createAxisInstance(Axis::Z);
        _y = createAxisInstance(Axis::Y);
        _x = createAxisInstance(Axis::X);

        _entities = std::vector { _parent };
        
        for(auto axis : { _z, _y, _x}) {
            
            for(int i =0; i < axis->getChildEntityCount(); i++) {
                auto entity = axis->getChildEntities()[i];
                _entities.push_back(entity);
            }
        }

    }


    SceneAsset *Gizmo::createAxisInstance(Gizmo::Axis axis)
    {
        auto *materialInstance = _material->createInstance();
        _materialInstances.push_back(materialInstance);
        auto instance = _source->createInstance(&materialInstance, 1);

        auto box = _source->getBoundingBox();
        Log("BB %f %f %f %f %f %f", box.center(), box.extent().x, box.extent().y, box.extent().z);

        // Set material properties
        materialInstance->setParameter("baseColorFactor", inactiveColors[axis]);
        materialInstance->setParameter("scale", 4.0f);
        // materialInstance->setParameter("screenSpaceSize", 90.0f);

        auto transform = getRotationForAxis(axis);

        Log("Created axis instance for %d", axis);

        auto& tm = _engine->getTransformManager();
        auto transformInstance = tm.getInstance(instance->getEntity());
        tm.setTransform(transformInstance, transform);

        return instance;
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
        auto entity = getEntityForAxis(axis);
        if (entity.isNull())
        {
            return;
        }
        auto renderableInstance = rm.getInstance(entity);

        if (!renderableInstance.isValid())
        {
            Log("Invalid renderable for axis");
            return;
        }
        auto *materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);
        math::float4 baseColor = activeColors[axis];
        materialInstance->setParameter("baseColorFactor", baseColor);
    }

    void Gizmo::unhighlight(Gizmo::Axis axis)
    {
        auto &rm = _engine->getRenderableManager();
        auto entity = getEntityForAxis(axis);
        if (entity.isNull())
        {
            return;
        }
        auto renderableInstance = rm.getInstance(entity);
        if (!renderableInstance.isValid())
        {
            Log("Invalid renderable for axis");
            return;
        }
        auto *materialInstance = rm.getMaterialInstanceAt(renderableInstance, 0);
        math::float4 baseColor = inactiveColors[axis];
        materialInstance->setParameter("baseColorFactor", baseColor);
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
