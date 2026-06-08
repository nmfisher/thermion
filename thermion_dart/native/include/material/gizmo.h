#ifndef GIZMO_H_
#define GIZMO_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "gizmo_material_webgpu.h"
#else
#include "gizmo_material_native.h"
#endif

#endif
