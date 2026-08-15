#ifndef GRID_H_
#define GRID_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "grid_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "grid_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "grid_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "grid_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
