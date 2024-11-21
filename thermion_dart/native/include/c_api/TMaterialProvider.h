#pragma once

#include "APIBoundaryTypes.h"
#include "APIExport.h"

#ifdef __cplusplus
extern "C"
{
#endif
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *MaterialProvider_createMaterialInstance(TMaterialProvider *provider, TMaterialKey *key);
	
#ifdef __cplusplus
}
#endif
