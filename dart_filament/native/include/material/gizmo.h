#ifndef GIZMO_H_
#define GIZMO_H_

#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif
    extern const uint8_t GIZMO_PACKAGE[];
    extern int GIZMO_GIZMO_OFFSET;
    extern int GIZMO_GIZMO_SIZE;
#if defined(__cplusplus)
}
#endif
#define GIZMO_GIZMO_DATA (GIZMO_PACKAGE + GIZMO_GIZMO_OFFSET)

#endif
