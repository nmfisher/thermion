#include <utils/NameComponentManager.h>

#include "c_api/APIExport.h"
#include "c_api/APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TNameComponentManager *NameComponentManager_create()
	{
		auto *ncm = new utils::NameComponentManager(utils::EntityManager::get());
		return reinterpret_cast<TNameComponentManager *>(ncm);
	}

	EMSCRIPTEN_KEEPALIVE const char *NameComponentManager_getName(TNameComponentManager *tNameComponentManager, EntityId entity)
	{
		auto ncm = reinterpret_cast<utils::NameComponentManager *>(tNameComponentManager);
		auto instance = ncm->getInstance(utils::Entity::import(entity));
		return ncm->getName(instance);
	}

#ifdef __cplusplus
}
#endif
