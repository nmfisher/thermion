#ifndef LINEAR_DEPTH_H_
#define LINEAR_DEPTH_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "linear_depth_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "linear_depth_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "linear_depth_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "linear_depth_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "linear_depth_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "linear_depth_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "linear_depth_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "linear_depth_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
