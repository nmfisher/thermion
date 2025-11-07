#pragma once

#include "c_api/APIExport.h"
#include "c_api/APIBoundaryTypes.h"

#include <stdint.h>

#ifdef __cplusplus
namespace thermion::plugin::input {
extern "C" {
#endif

typedef struct TMovementIntentCalculator TMovementIntentCalculator;

// Movement intent structure
typedef struct {
    // Movement intent
    float movementDirectionX;
    float movementDirectionY;
    float movementDirectionZ;
    float movementSpeed;

    // Rotation intent
    float mouseDeltaX;
    float mouseDeltaY;

    // Action intents
    int jumpIntent;      // 0 = false, non-zero = true
    int sprintIntent;    // 0 = false, non-zero = true

    // Frame metadata
    float deltaTime;
    int hasMovementIntent;  // 0 = false, non-zero = true
    int hasRotationIntent;  // 0 = false, non-zero = true
} TMovementIntent;


#ifdef __cplusplus
}
}
#endif
