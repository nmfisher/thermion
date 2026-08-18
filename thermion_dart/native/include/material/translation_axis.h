#ifndef TRANSLATION_AXIS_H_
#define TRANSLATION_AXIS_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "translation_axis_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "translation_axis_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "translation_axis_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "translation_axis_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "translation_axis_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "translation_axis_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "translation_axis_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "translation_axis_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
