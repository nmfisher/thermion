#ifndef WIREFRAME_ANDROID_H_
#define WIREFRAME_ANDROID_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t WIREFRAME_PACKAGE[];
#ifdef __cplusplus
}
#endif

#define WIREFRAME_WIREFRAME_OFFSET 0
#define WIREFRAME_WIREFRAME_SIZE 83010
#define WIREFRAME_WIREFRAME_DATA (WIREFRAME_PACKAGE + WIREFRAME_WIREFRAME_OFFSET)

#endif
