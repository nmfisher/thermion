import 'package:thermion_dart/thermion_dart.dart';
import 'intent_action.dart';

/// Represents a mouse button binding that maps a mouse button to an intent action.
class MouseButtonBinding {
  /// The mouse button that triggers this intent
  final MouseButton button;

  /// The action to perform when the button is pressed
  final IntentAction action;

  /// The value/strength of this intent (default 1.0)
  final double value;

  const MouseButtonBinding({required this.button, required this.action, this.value = 1.0});

  @override
  String toString() => 'MouseButtonBinding(button: $button, action: $action, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MouseButtonBinding &&
          runtimeType == other.runtimeType &&
          button == other.button &&
          action == other.action &&
          value == other.value;

  @override
  int get hashCode => Object.hash(button, action, value);
}
