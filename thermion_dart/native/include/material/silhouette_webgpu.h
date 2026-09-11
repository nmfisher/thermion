#ifndef SILHOUETTE_WEBGPU_H_
#define SILHOUETTE_WEBGPU_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t SILHOUETTE_PACKAGE[];
#ifdef __cplusplus
}
#endif

#define SILHOUETTE_SILHOUETTE_OFFSET 0
#define SILHOUETTE_SILHOUETTE_SIZE 41278
#define SILHOUETTE_SILHOUETTE_DATA (SILHOUETTE_PACKAGE + SILHOUETTE_SILHOUETTE_OFFSET)

#endif
