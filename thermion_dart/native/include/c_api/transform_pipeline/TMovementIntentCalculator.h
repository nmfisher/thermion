#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TMovementIntentCalculator TMovementIntentCalculator;

// Intent action enumeration matching C++ IntentAction
typedef enum {
    INTENT_ACTION_MOVE_FORWARD = 0,
    INTENT_ACTION_MOVE_BACKWARD = 1,
    INTENT_ACTION_MOVE_LEFT = 2,
    INTENT_ACTION_MOVE_RIGHT = 3,
    INTENT_ACTION_JUMP = 4,
    INTENT_ACTION_SPRINT = 5,
    INTENT_ACTION_CUSTOM1 = 6,
    INTENT_ACTION_CUSTOM2 = 7,
    INTENT_ACTION_CUSTOM3 = 8,
    INTENT_ACTION_CUSTOM4 = 9,
    INTENT_ACTION_CUSTOM5 = 10,
    INTENT_ACTION_CUSTOM6 = 11,
    INTENT_ACTION_CUSTOM7 = 12,
    INTENT_ACTION_CUSTOM8 = 13,
    INTENT_ACTION_CUSTOM9 = 14,
    INTENT_ACTION_CUSTOM10 = 15,
    INTENT_ACTION_CROUCH = 16,
    INTENT_ACTION_INTERACT = 17,
    INTENT_ACTION_USE_ITEM = 18,
    INTENT_ACTION_RELOAD = 19,
    INTENT_ACTION_ALT_FIRE = 20
} TIntentAction;

// Maximum number of custom intents that can be stored in parallel arrays
#define MAX_CUSTOM_INTENTS 16

// Intent state bitmasks (matching C++ implementation)
#define MOVEMENT_INTENT_MASK 0x00000001  // bit 0
#define ROTATION_INTENT_MASK 0x00000002  // bit 1
#define JUMP_INTENT_MASK     0x00000004  // bit 2
#define SPRINT_INTENT_MASK   0x00000008  // bit 3

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

    // Intent state bitmask (32 bits: first 4 for standard intents, remaining 28 for custom)
    uint32_t intentStates;

    // Frame metadata
    float deltaTime;

    // Custom intents - using parallel arrays for C compatibility
    int customIntentActions[MAX_CUSTOM_INTENTS];  // Array of TIntentAction values
    float customIntentValues[MAX_CUSTOM_INTENTS]; // Array of intent values
    int customIntentCount;                         // Number of valid custom intents
} TMovementIntent;


#ifdef __cplusplus
}
#endif
