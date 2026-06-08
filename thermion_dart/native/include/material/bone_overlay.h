#ifndef BONE_OVERLAY_H_
#define BONE_OVERLAY_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "bone_overlay_webgpu.h"
#else
#include "bone_overlay_native.h"
#endif

#endif
