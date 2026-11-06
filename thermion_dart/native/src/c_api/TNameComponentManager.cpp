#include "rendering/EngineApiLock.hpp"
 

#include <utils/NameComponentManager.h>

#include "Log.hpp"
#include "c_api/APIExport.h"
#include "c_api/APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TNameComponentManager *NameComponentManager_create()
	{
		THERMION_ENGINE_API_GUARD;
		auto *ncm = new utils::NameComponentManager(utils::EntityManager::get());
		return reinterpret_cast<TNameComponentManager *>(ncm);
	}

	EMSCRIPTEN_KEEPALIVE void NameComponentManager_destroy(TNameComponentManager *tNameComponentManager)
	{
		THERMION_ENGINE_API_GUARD;
		delete reinterpret_cast<utils::NameComponentManager *>(tNameComponentManager);
	}

	EMSCRIPTEN_KEEPALIVE const char *NameComponentManager_getName(TNameComponentManager *tNameComponentManager, EntityId entityId)
	{
		THERMION_ENGINE_API_GUARD;
		auto ncm = reinterpret_cast<utils::NameComponentManager *>(tNameComponentManager);
		auto entity = utils::Entity::import(entityId);
		if(!ncm->hasComponent(entity)) {
			return nullptr;
		}
		auto instance = ncm->getInstance(entity);
		return ncm->getName(instance);
	}

#ifdef __cplusplus
}
#endif
