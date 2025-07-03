#ifndef OUTLINE_H_
#define OUTLINE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t OUTLINE_PACKAGE[];
    extern int OUTLINE_OUTLINE_OFFSET;
    extern int OUTLINE_OUTLINE_SIZE;
#ifdef __cplusplus
}
#endif

#define OUTLINE_OUTLINE_DATA (OUTLINE_PACKAGE + OUTLINE_OUTLINE_OFFSET)

#endif
