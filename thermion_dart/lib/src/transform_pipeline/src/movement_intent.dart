import 'package:thermion_dart/thermion_dart.dart';
import '../../bindings/bindings.dart' as bindings;
import 'intent_action.dart';

/// Dart wrapper around the native TMovementIntent//MovementIntent struct
/// (represents what the player wants to do this frame).
///
/// You probably don't need to use this - a MovementIntent is calculated
/// every frame (see Pipeline.hpp and MovementIntentCalculator.hpp). This Dart
/// wrapper is intended for testing only.
///

/// You
class MovementIntent {
  /// Normalized movement direction vector
  Vector3 movementDirection;

  /// Current speed multiplier (0-1)
  double movementSpeed;

  /// Camera rotation intent (mouse delta)
  Vector2 mouseDelta;

  /// Jump intent
  bool jumpIntent;

  /// Sprint intent
  bool sprintIntent;

  /// Whether there is any movement intent
  bool hasMovementIntent;

  /// Whether there is any rotation intent
  bool hasRotationIntent;

  /// Custom intents map (action -> value)
  final Map<IntentAction, double> customIntents;

  MovementIntent({
    Vector3? movementDirection,
    this.movementSpeed = 0.0,
    Vector2? mouseDelta,
    this.jumpIntent = false,
    this.sprintIntent = false,
    this.hasMovementIntent = false,
    this.hasRotationIntent = false,
    Map<IntentAction, double>? customIntents,
  })  : movementDirection = movementDirection ?? Vector3.zero(),
        mouseDelta = mouseDelta ?? Vector2.zero(),
        customIntents = customIntents ?? {};

  /// Check if a custom intent is active
  bool hasCustomIntent(IntentAction action) {
    return customIntents.containsKey(action);
  }

  /// Get the value of a custom intent (returns 0.0 if not present)
  double getCustomIntentValue(IntentAction action) {
    return customIntents[action] ?? 0.0;
  }

  /// Set a custom intent value
  void setCustomIntent(IntentAction action, double value) {
    if (value != 0.0) {
      customIntents[action] = value;
    } else {
      customIntents.remove(action);
    }
  }

  /// Convert this Dart MovementIntent to a native TMovementIntent struct
  bindings.TMovementIntent toNative() {
    final native = Struct.create<bindings.TMovementIntent>();

    // Movement direction
    native.movementDirectionX = movementDirection.x;
    native.movementDirectionY = movementDirection.y;
    native.movementDirectionZ = movementDirection.z;
    native.movementSpeed = movementSpeed;

    // Rotation intent
    native.mouseDeltaX = mouseDelta.x;
    native.mouseDeltaY = mouseDelta.y;

    // Pack intent states into bitmask
    int intentStates = 0;
    if (hasMovementIntent) intentStates |= bindings.MOVEMENT_INTENT_MASK;
    if (hasRotationIntent) intentStates |= bindings.ROTATION_INTENT_MASK;
    if (jumpIntent) intentStates |= bindings.JUMP_INTENT_MASK;
    if (sprintIntent) intentStates |= bindings.SPRINT_INTENT_MASK;
    native.intentStates = intentStates;

    // Custom intents - convert map to parallel arrays
    int count = 0;
    for (final entry in customIntents.entries) {
      if (count >= bindings.MAX_CUSTOM_INTENTS) break;

      native.customIntentActions[count] = entry.key.nativeValue;
      native.customIntentValues[count] = entry.value;
      count++;
    }
    native.customIntentCount = count;

    return native;
  }

  /// Create a Dart MovementIntent from a native TMovementIntent struct
  static MovementIntent fromNative(bindings.TMovementIntent native) {
    // Convert custom intents from parallel arrays to map
    final customIntents = <IntentAction, double>{};
    for (int i = 0;
        i < native.customIntentCount && i < bindings.MAX_CUSTOM_INTENTS;
        i++) {
      final action = IntentAction.fromNative(native.customIntentActions[i]);
      customIntents[action] = native.customIntentValues[i];
    }

    // Unpack intent states from bitmask
    final intentStates = native.intentStates;

    return MovementIntent(
      movementDirection: Vector3(
        native.movementDirectionX,
        native.movementDirectionY,
        native.movementDirectionZ,
      ),
      movementSpeed: native.movementSpeed,
      mouseDelta: Vector2(native.mouseDeltaX, native.mouseDeltaY),
      jumpIntent: (intentStates & bindings.JUMP_INTENT_MASK) != 0,
      sprintIntent: (intentStates & bindings.SPRINT_INTENT_MASK) != 0,
      hasMovementIntent: (intentStates & bindings.MOVEMENT_INTENT_MASK) != 0,
      hasRotationIntent: (intentStates & bindings.ROTATION_INTENT_MASK) != 0,
      customIntents: customIntents,
    );
  }

  @override
  String toString() {
    return 'MovementIntent('
        'dir: $movementDirection, '
        'speed: $movementSpeed, '
        'mouse: $mouseDelta, '
        'jump: $jumpIntent, '
        'sprint: $sprintIntent, '
        'customIntents: ${customIntents.length}'
        ')';
  }
}
