#include <utils/Entity.h>
#include <filament/TransformManager.h>
#include <filament/math/mat4.h>
#include <gltfio/math.h>

#include "c_api/APIExport.h"

#include "Log.hpp"
#include "MathUtils.hpp"

using namespace thermion;

extern "C"
{
    using namespace filament;
    using namespace utils;
    using namespace filament::gltfio;
    
#include "c_api/TTransformManager.h"

    EMSCRIPTEN_KEEPALIVE double4x4 TransformManager_getLocalTransform(TTransformManager *tTransformManager, EntityId entityId)
    {
        auto *transformManager = reinterpret_cast<filament::TransformManager *>(tTransformManager);
        const auto &entity = utils::Entity::import(entityId);
        auto transformInstance = transformManager->getInstance(entity);
        if (!transformInstance)
        {
            Log("Failed to find transform instance");
            return double4x4();
        }
        auto transform = transformManager->getTransformAccurate(transformInstance);
        return convert_mat4_to_double4x4(transform);
    }

    EMSCRIPTEN_KEEPALIVE double4x4 TransformManager_getWorldTransform(TTransformManager *tTransformManager, EntityId entityId)
    {
        auto *transformManager = reinterpret_cast<filament::TransformManager *>(tTransformManager);
        const auto &entity = utils::Entity::import(entityId);
        auto transformInstance = transformManager->getInstance(entity);
        if (!transformInstance)
        {
            Log("Failed to find transform instance");
            return double4x4();
        }
        auto transform = transformManager->getWorldTransformAccurate(transformInstance);
        return convert_mat4_to_double4x4(transform);
    }

    EMSCRIPTEN_KEEPALIVE void TransformManager_setTransform(TTransformManager *tTransformManager, EntityId entityId, double4x4 transform)
    {
        auto *transformManager = reinterpret_cast<filament::TransformManager *>(tTransformManager);
        const auto &entity = utils::Entity::import(entityId);
        auto transformInstance = transformManager->getInstance(entity);
        if (!transformInstance)
        {
            return;
        }
        transformManager->setTransform(transformInstance, convert_double4x4_to_mat4(transform));
    }

    EMSCRIPTEN_KEEPALIVE void TransformManager_transformToUnitCube(TTransformManager *tTransformManager, EntityId entityId, Aabb3 boundingBox) {
        
        auto *transformManager = reinterpret_cast<filament::TransformManager*>(tTransformManager);
        const auto &entity = utils::Entity::import(entityId);
        auto transformInstance = transformManager->getInstance(entity);
        if (!transformInstance || !transformInstance.isValid())
        {
            return;
        }

        auto center = filament::math::float3 { boundingBox.centerX, boundingBox.centerY, boundingBox.centerZ };
        auto halfExtent = filament::math::float3 { boundingBox.halfExtentX, boundingBox.halfExtentY, boundingBox.halfExtentZ };
        auto maxExtent = max(halfExtent) * 2;
        auto scaleFactor = 2.0f / maxExtent;
        auto transform = math::mat4f::scaling(scaleFactor) * math::mat4f::translation(-center);
        transformManager->setTransform(transformInstance, transform);
    }

    EMSCRIPTEN_KEEPALIVE void TransformManager_setParent(TTransformManager *tTransformManager, EntityId childId, EntityId parentId, bool preserveScaling)
    {
        auto tm = reinterpret_cast<TransformManager *>(tTransformManager);
        const auto child = Entity::import(childId);
        const auto parent = Entity::import(parentId);

        const auto &childInstance = tm->getInstance(child);

        if (!childInstance.isValid())
        {
            TRACE("Can't set transform parent, child instance is not valid");
            return;
        }

        if(parent.isNull()) {
            Log("Unparenting child instance");
            tm->setParent(childInstance, TransformManager::Instance());
            return;
        }

        const auto &parentInstance = tm->getInstance(parent);

        if (!parentInstance.isValid())
        {
            Log("Parent instance is not valid");
            return;
        }



        if (preserveScaling)
        {
            auto parentTransform = tm->getWorldTransform(parentInstance);
            math::float3 parentTranslation;
            math::quatf parentRotation;
            math::float3 parentScale;

            decomposeMatrix(parentTransform, &parentTranslation, &parentRotation, &parentScale);

            auto childTransform = tm->getTransform(childInstance);
            math::float3 childTranslation;
            math::quatf childRotation;
            math::float3 childScale;

            decomposeMatrix(childTransform, &childTranslation, &childRotation, &childScale);

            childScale = childScale * (1 / parentScale);

            childTransform = composeMatrix(childTranslation, childRotation, childScale);

            tm->setTransform(childInstance, childTransform);
        }

        tm->setParent(childInstance, parentInstance);
    }

    EMSCRIPTEN_KEEPALIVE EntityId TransformManager_getParent(TTransformManager *tTransformManager, EntityId childId)
    {
        auto tm = reinterpret_cast<TransformManager *>(tTransformManager);
        const auto child = Entity::import(childId);
        const auto &childInstance = tm->getInstance(child);

        return Entity::smuggle(tm->getParent(childInstance));
    }

    EMSCRIPTEN_KEEPALIVE EntityId TransformManager_getAncestor(TTransformManager *tTransformManager, EntityId childEntityId)
    {
        auto tm = reinterpret_cast<TransformManager *>(tTransformManager);

        const auto child = Entity::import(childEntityId);
        auto transformInstance = tm->getInstance(child);
        Entity parent;

        while (true)
        {
            auto newParent = tm->getParent(transformInstance);
            if (newParent.isNull())
            {
                break;
            }
            parent = newParent;
            transformInstance = tm->getInstance(parent);
        }

        return Entity::smuggle(parent);
    }
}