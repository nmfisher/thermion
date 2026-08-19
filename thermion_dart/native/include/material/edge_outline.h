#ifndef EDGE_OUTLINE_H_
#define EDGE_OUTLINE_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "edge_outline_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "edge_outline_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "edge_outline_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "edge_outline_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "edge_outline_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "edge_outline_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "edge_outline_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "edge_outline_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
