#ifndef GIZMO_H_
#define GIZMO_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "gizmo_material_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "gizmo_material_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "gizmo_material_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "gizmo_material_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
