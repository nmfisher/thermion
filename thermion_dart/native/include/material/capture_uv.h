#ifndef CAPTURE_UV_H_
#define CAPTURE_UV_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "capture_uv_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "capture_uv_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "capture_uv_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "capture_uv_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "capture_uv_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "capture_uv_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "capture_uv_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "capture_uv_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
