#ifndef GIZMO_H_
#define GIZMO_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "gizmo_material_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "gizmo_material_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "gizmo_material_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "gizmo_material_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "gizmo_material_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "gizmo_material_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "gizmo_material_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "gizmo_material_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
