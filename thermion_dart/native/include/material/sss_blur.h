#ifndef SSS_BLUR_H_
#define SSS_BLUR_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "sss_blur_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "sss_blur_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "sss_blur_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "sss_blur_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "sss_blur_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "sss_blur_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "sss_blur_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "sss_blur_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
