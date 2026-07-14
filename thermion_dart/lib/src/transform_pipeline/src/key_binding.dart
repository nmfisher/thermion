import 'package:thermion_dart/thermion_dart.dart';
import '../../bindings/bindings.dart' as bindings;
import 'intent_action.dart';

/// Represents a keybinding that maps a logical key to an intent action.
class KeyBinding {
  /// The logical key that triggers this intent
  final LogicalKey key;

  /// The action to perform when the key is pressed
  final IntentAction action;

  /// The value/strength of this intent (default 1.0)
  final double value;

  const KeyBinding({required this.key, required this.action, this.value = 1.0});

  @override
  String toString() => 'KeyBinding(key: $key, action: $action, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyBinding &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          action == other.action &&
          value == other.value;

  @override
  int get hashCode => Object.hash(key, action, value);
}
