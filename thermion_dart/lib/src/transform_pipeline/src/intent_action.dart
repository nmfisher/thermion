import 'package:thermion_dart/thermion_dart.dart';
import '../../bindings/bindings.dart' as bindings;

/// Intent action enumeration.
///
/// Defines all possible intent actions that can be triggered by input.
/// Matches the C++ IntentAction enum and TIntentAction C enum.
enum IntentAction {
  /// Move forward (typically W key)
  moveForward(bindings.TIntentAction.INTENT_ACTION_MOVE_FORWARD),

  /// Move backward (typically S key)
  moveBackward(bindings.TIntentAction.INTENT_ACTION_MOVE_BACKWARD),

  /// Move left (typically A key)
  moveLeft(bindings.TIntentAction.INTENT_ACTION_MOVE_LEFT),

  /// Move right (typically D key)
  moveRight(bindings.TIntentAction.INTENT_ACTION_MOVE_RIGHT),

  /// Jump (typically Space key)
  jump(bindings.TIntentAction.INTENT_ACTION_JUMP),

  /// Sprint (typically Shift key)
  sprint(bindings.TIntentAction.INTENT_ACTION_SPRINT),

  /// Custom intent 1
  custom1(bindings.TIntentAction.INTENT_ACTION_CUSTOM1),

  /// Custom intent 2
  custom2(bindings.TIntentAction.INTENT_ACTION_CUSTOM2),

  /// Custom intent 3
  custom3(bindings.TIntentAction.INTENT_ACTION_CUSTOM3),

  /// Custom intent 4
  custom4(bindings.TIntentAction.INTENT_ACTION_CUSTOM4),

  /// Custom intent 5
  custom5(bindings.TIntentAction.INTENT_ACTION_CUSTOM5),

  /// Custom intent 6
  custom6(bindings.TIntentAction.INTENT_ACTION_CUSTOM6),

  /// Custom intent 7
  custom7(bindings.TIntentAction.INTENT_ACTION_CUSTOM7),

  /// Custom intent 8
  custom8(bindings.TIntentAction.INTENT_ACTION_CUSTOM8),

  /// Custom intent 9
  custom9(bindings.TIntentAction.INTENT_ACTION_CUSTOM9),

  /// Custom intent 10
  custom10(bindings.TIntentAction.INTENT_ACTION_CUSTOM10),

  /// Crouch action
  crouch(bindings.TIntentAction.INTENT_ACTION_CROUCH),

  /// Interact action (e.g., use door, pickup item)
  interact(bindings.TIntentAction.INTENT_ACTION_INTERACT),

  /// Use item action
  useItem(bindings.TIntentAction.INTENT_ACTION_USE_ITEM),

  /// Reload action
  reload(bindings.TIntentAction.INTENT_ACTION_RELOAD),

  /// Alternate fire action
  altFire(bindings.TIntentAction.INTENT_ACTION_ALT_FIRE);

  const IntentAction(this.nativeValue);

  /// The native C enum value
  final int nativeValue;

  /// Create IntentAction from native value
  static IntentAction fromNative(int value) {
    return IntentAction.values.firstWhere(
      (action) => action.nativeValue == value,
      orElse: () => throw ArgumentError('Invalid IntentAction value: $value'),
    );
  }
}
