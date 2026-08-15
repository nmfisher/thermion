#ifndef IMAGE_H_
#define IMAGE_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "image_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "image_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "image_desktop.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "image_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "image_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "image_web_combined.h"
#elif defined(THERMION_MATERIAL_NATIVE)
#include "image_native.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
