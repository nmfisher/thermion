#ifndef GRID_H_
#define GRID_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "grid_webgpu.h"
#else
#include "grid_native.h"
#endif

#endif
