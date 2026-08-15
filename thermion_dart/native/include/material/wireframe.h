#ifndef WIREFRAME_H_
#define WIREFRAME_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "wireframe_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "wireframe_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "wireframe_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "wireframe_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
