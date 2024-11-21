#pragma once

#include "APIBoundaryTypes.h"
#include "APIExport.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE const char *NameComponentManager_getName(TNameComponentManager *tNameComponentManager, EntityId entity);
	

#ifdef __cplusplus
}
#endif
