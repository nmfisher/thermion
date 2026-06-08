#ifndef TRANSLATION_AXIS_H_
#define TRANSLATION_AXIS_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "translation_axis_webgpu.h"
#else
#include "translation_axis_native.h"
#endif

#endif
