#ifndef LINEAR_DEPTH_H_
#define LINEAR_DEPTH_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "linear_depth_webgpu.h"
#else
#include "linear_depth_native.h"
#endif

#endif
