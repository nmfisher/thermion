#ifndef LINEAR_DEPTH_H_
#define LINEAR_DEPTH_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "linear_depth_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "linear_depth_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "linear_depth_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "linear_depth_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
