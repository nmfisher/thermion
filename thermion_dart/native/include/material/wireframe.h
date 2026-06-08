#ifndef WIREFRAME_H_
#define WIREFRAME_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "wireframe_webgpu.h"
#else
#include "wireframe_native.h"
#endif

#endif
