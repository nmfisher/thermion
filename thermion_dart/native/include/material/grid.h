#ifndef GRID_H_
#define GRID_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "grid_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "grid_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "grid_desktop.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "grid_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "grid_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "grid_web_combined.h"
#elif defined(THERMION_MATERIAL_NATIVE)
#include "grid_native.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
