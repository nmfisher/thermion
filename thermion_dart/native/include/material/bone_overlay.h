#ifndef BONE_OVERLAY_H_
#define BONE_OVERLAY_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "bone_overlay_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "bone_overlay_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "bone_overlay_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "bone_overlay_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "bone_overlay_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "bone_overlay_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "bone_overlay_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "bone_overlay_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
