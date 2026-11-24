#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

// Compile-time feature bitmask of the loaded library. Always compiled,
// never guarded, so every build variant exports it:
//   bit 0  THERMION_ENABLE_GLTF
//   bit 1  THERMION_ENABLE_KTX
//   bit 2  THERMION_ENABLE_IMAGE_DECODING
//   bit 3  THERMION_ENABLE_RUNTIME_MATERIALS (mirrors MaterialCompiler_isSupported)
/// Compile-time feature bitmask of the loaded engine: bit 0 gltf, bit 1 ktx,
/// bit 2 image_decoding, bit 3 runtime_materials (c_api/ThermionFeatures.h).
EMSCRIPTEN_KEEPALIVE uint32_t Thermion_getEnabledFeatures();

#ifdef __cplusplus
}
#endif
