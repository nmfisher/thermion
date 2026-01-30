#ifndef WIREFRAME_H_
#define WIREFRAME_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t WIREFRAME_PACKAGE[];
    extern int WIREFRAME_WIREFRAME_OFFSET;
    extern int WIREFRAME_WIREFRAME_SIZE;
#ifdef __cplusplus
}
#endif
#define WIREFRAME_WIREFRAME_DATA (WIREFRAME_PACKAGE + WIREFRAME_WIREFRAME_OFFSET)

#endif
