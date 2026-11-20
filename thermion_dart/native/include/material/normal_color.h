#ifndef NORMAL_COLOR_H_
#define NORMAL_COLOR_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "normal_color_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "normal_color_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "normal_color_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "normal_color_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "normal_color_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "normal_color_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "normal_color_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "normal_color_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
