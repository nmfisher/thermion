#ifndef CAPTURE_UV_H_
#define CAPTURE_UV_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "capture_uv_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "capture_uv_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "capture_uv_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "capture_uv_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
