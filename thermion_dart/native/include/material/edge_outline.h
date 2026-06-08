#ifndef EDGE_OUTLINE_H_
#define EDGE_OUTLINE_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "edge_outline_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "edge_outline_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "edge_outline_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "edge_outline_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
