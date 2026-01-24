#ifndef SILHOUETTE_H_
#define SILHOUETTE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t SILHOUETTE_PACKAGE[];
    extern int SILHOUETTE_SILHOUETTE_OFFSET;
    extern int SILHOUETTE_SILHOUETTE_SIZE;
#ifdef __cplusplus
}
#endif
#define SILHOUETTE_SILHOUETTE_DATA (SILHOUETTE_PACKAGE + SILHOUETTE_SILHOUETTE_OFFSET)

#endif
