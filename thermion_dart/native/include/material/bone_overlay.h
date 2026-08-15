#ifndef BONE_OVERLAY_H_
#define BONE_OVERLAY_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "bone_overlay_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "bone_overlay_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "bone_overlay_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "bone_overlay_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
