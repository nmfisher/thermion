#ifndef EDGE_OUTLINE_H_
#define EDGE_OUTLINE_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "edge_outline_webgpu.h"
#else
#include "edge_outline_native.h"
#endif

#endif
