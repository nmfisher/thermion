#ifndef UNLIT_FIXED_SIZE_H_
#define UNLIT_FIXED_SIZE_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "unlit_fixed_size_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "unlit_fixed_size_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "unlit_fixed_size_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "unlit_fixed_size_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
