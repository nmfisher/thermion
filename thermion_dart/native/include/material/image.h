#ifndef IMAGE_H_
#define IMAGE_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "image_webgpu.h"
#else
#include "image_native.h"
#endif

#endif
