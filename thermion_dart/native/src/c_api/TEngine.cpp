#include "c_api/TEngine.h"


#include <filament/Engine.h>
#include <filament/Material.h>
#include <filament/Scene.h>
#include <filament/TransformManager.h>
#include <filament/View.h>

#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
#endif

        EMSCRIPTEN_KEEPALIVE TTransformManager *Engine_getTransformManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &transformManager = engine->getTransformManager();
            return reinterpret_cast<TTransformManager *>(&transformManager);
        }

        EMSCRIPTEN_KEEPALIVE TRenderableManager *Engine_getRenderableManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &renderableManager = engine->getRenderableManager();
            return reinterpret_cast<TRenderableManager *>(&renderableManager);
        }

        EMSCRIPTEN_KEEPALIVE TLightManager *Engine_getLightManager(TEngine *tEngine)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &lightManager = engine->getLightManager();
            return reinterpret_cast<TLightManager *>(&lightManager);
        }

        EMSCRIPTEN_KEEPALIVE TCamera *Engine_getCameraComponent(TEngine *tEngine, EntityId entityId)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto entity = utils::Entity::import(entityId);
            if (entity.isNull())
            {
                return std::nullptr_t();
            }
            auto *camera = engine->getCameraComponent(entity);
            return reinterpret_cast<TCamera *>(camera);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_setTransform(TEngine *tEngine, EntityId entity, double4x4 transform)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto &transformManager = engine->getTransformManager();

            auto transformInstance = transformManager.getInstance(utils::Entity::import(entity));
            if (!transformInstance.isValid())
            {
                Log("Transform instance not valid");
            }
            transformManager.setTransform(transformInstance, convert_double4x4_to_mat4(transform));
        }

        EMSCRIPTEN_KEEPALIVE TMaterial *Engine_buildMaterial(TEngine *tEngine, const uint8_t *materialData, size_t length)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *material = Material::Builder()
                                 .package(materialData, length)
                                 .build(*engine);
            return reinterpret_cast<TMaterial *>(material);
        }

        EMSCRIPTEN_KEEPALIVE void Engine_destroyMaterial(TEngine *tEngine, TMaterial *tMaterial)
        {
            auto *engine = reinterpret_cast<Engine *>(tEngine);
            auto *material = reinterpret_cast<Material *>(tMaterial);
            engine->destroy(material);
        }

#ifdef __cplusplus
    }
}
#endif
