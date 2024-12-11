#ifndef GIZMO_GLB_H_
#define GIZMO_GLB_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t GIZMO_GLB_PACKAGE[];
    extern int GIZMO_GLB_GIZMO_OFFSET;
    extern int GIZMO_GLB_GIZMO_SIZE;
}
#define GIZMO_GLB_GIZMO_DATA (GIZMO_GLB_PACKAGE + GIZMO_GLB_GIZMO_OFFSET)

#endif
