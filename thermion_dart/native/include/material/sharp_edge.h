#ifndef SHARP_EDGE_H_
#define SHARP_EDGE_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "sharp_edge_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "sharp_edge_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "sharp_edge_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "sharp_edge_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "sharp_edge_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "sharp_edge_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "sharp_edge_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "sharp_edge_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
