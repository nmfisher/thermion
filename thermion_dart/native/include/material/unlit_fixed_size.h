#ifndef UNLIT_FIXED_SIZE_H_
#define UNLIT_FIXED_SIZE_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "unlit_fixed_size_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "unlit_fixed_size_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "unlit_fixed_size_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "unlit_fixed_size_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "unlit_fixed_size_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "unlit_fixed_size_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "unlit_fixed_size_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "unlit_fixed_size_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
