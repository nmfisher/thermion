#ifndef WIREFRAME_H_
#define WIREFRAME_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "wireframe_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "wireframe_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "wireframe_desktop.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "wireframe_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "wireframe_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "wireframe_web_combined.h"
#elif defined(THERMION_MATERIAL_NATIVE)
#include "wireframe_native.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
