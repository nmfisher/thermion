#ifndef TRANSLATION_AXIS_H_
#define TRANSLATION_AXIS_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "translation_axis_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "translation_axis_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "translation_axis_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "translation_axis_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
