#ifndef SOLID_H_
#define SOLID_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t SOLID_PACKAGE[];
#ifdef __cplusplus
}
#endif

#define SOLID_SOLID_OFFSET 0
#define SOLID_SOLID_SIZE 125082
#define SOLID_SOLID_DATA (SOLID_PACKAGE + SOLID_SOLID_OFFSET)

#endif
