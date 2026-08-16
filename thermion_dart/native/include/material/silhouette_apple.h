#ifndef SILHOUETTE_APPLE_H_
#define SILHOUETTE_APPLE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t SILHOUETTE_PACKAGE[];
#ifdef __cplusplus
}
#endif

#define SILHOUETTE_SILHOUETTE_OFFSET 0
#define SILHOUETTE_SILHOUETTE_SIZE 31033
#define SILHOUETTE_SILHOUETTE_DATA (SILHOUETTE_PACKAGE + SILHOUETTE_SILHOUETTE_OFFSET)

#endif
