#ifndef SSS_BLUR_WEBGPU_H_
#define SSS_BLUR_WEBGPU_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t SSS_BLUR_PACKAGE[];
#ifdef __cplusplus
}
#endif

#define SSS_BLUR_SSS_BLUR_OFFSET 0
#define SSS_BLUR_SSS_BLUR_SIZE 47103
#define SSS_BLUR_SSS_BLUR_DATA (SSS_BLUR_PACKAGE + SSS_BLUR_SSS_BLUR_OFFSET)

#endif
