#ifndef SILHOUETTE_H_
#define SILHOUETTE_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "silhouette_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "silhouette_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "silhouette_desktop.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "silhouette_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "silhouette_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "silhouette_web_combined.h"
#elif defined(THERMION_MATERIAL_NATIVE)
#include "silhouette_native.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
