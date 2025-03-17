#pragma once

#include "APIBoundaryTypes.h"
#include "APIExport.h"

#ifdef __cplusplus
extern "C"
{
#endif
	
	// EMSCRIPTEN_KEEPALIVE TMaterialProvider *MaterialProvider_create(TEngine *tEngine, uint8_t* data, size_t length);
	EMSCRIPTEN_KEEPALIVE TMaterialInstance *MaterialProvider_createMaterialInstance(TMaterialProvider *provider, TMaterialKey *key);
	
#ifdef __cplusplus
}
#endif
