import 'package:thermion_dart/thermion_dart.dart';
import 'intent_action.dart';
import 'key_binding.dart';
import 'mouse_button_binding.dart';


/// Configuration for input processing.
///
/// This can be modified at runtime to change keybindings and behavior.
class InputConfiguration {
  /// List of key bindings
  final List<KeyBinding> keyBindings;

  /// List of mouse button bindings
  final List<MouseButtonBinding> mouseButtonBindings;

  /// Mouse sensitivity multiplier
  double mouseSensitivity;

  /// Whether to invert the Y axis for mouse look
  bool invertMouseY;

  InputConfiguration({
    List<KeyBinding>? keyBindings,
    List<MouseButtonBinding>? mouseButtonBindings,
    this.mouseSensitivity = 1.0,
    this.invertMouseY = false,
  }) : keyBindings = keyBindings ?? [],
       mouseButtonBindings = mouseButtonBindings ?? [];

  /// Add a keybinding to the configuration
  void addBinding(LogicalKey key, IntentAction action, {double value = 1.0}) {
    keyBindings.add(KeyBinding(key: key, action: action, value: value));
  }

  /// Add a mouse button binding to the configuration
  void addMouseButtonBinding(MouseButton button, IntentAction action, {double value = 1.0}) {
    mouseButtonBindings.add(MouseButtonBinding(button: button, action: action, value: value));
  }

  /// Remove all bindings for a specific key
  void removeBindingsForKey(LogicalKey key) {
    keyBindings.removeWhere((binding) => binding.key == key);
  }

  /// Remove all bindings for a specific mouse button
  void removeBindingsForMouseButton(MouseButton button) {
    mouseButtonBindings.removeWhere((binding) => binding.button == button);
  }

  /// Remove all bindings for a specific action
  void removeBindingsForAction(IntentAction action) {
    keyBindings.removeWhere((binding) => binding.action == action);
    mouseButtonBindings.removeWhere((binding) => binding.action == action);
  }

  /// Clear all keybindings (both keyboard and mouse button)
  void clearBindings() {
    keyBindings.clear();
    mouseButtonBindings.clear();
  }

  /// Get all bindings for a specific key
  List<KeyBinding> getBindingsForKey(LogicalKey key) {
    return keyBindings.where((binding) => binding.key == key).toList();
  }

  /// Get all bindings for a specific action
  List<KeyBinding> getBindingsForAction(IntentAction action) {
    return keyBindings.where((binding) => binding.action == action).toList();
  }

  @override
  String toString() =>
      'InputConfiguration(keyBindings: ${keyBindings.length}, mouseButtonBindings: ${mouseButtonBindings.length}, mouseSensitivity: $mouseSensitivity, invertMouseY: $invertMouseY)';
}

/// Factory function to create default WASD configuration.
///
/// This provides the standard PC gaming control scheme:
/// - W/A/S/D for movement
/// - Space for jump
/// - Shift for sprint
InputConfiguration createDefaultConfiguration() {
  return InputConfiguration(
    keyBindings: [
      KeyBinding(key: LogicalKey.w, action: IntentAction.moveForward),
      KeyBinding(key: LogicalKey.s, action: IntentAction.moveBackward),
      KeyBinding(key: LogicalKey.a, action: IntentAction.moveLeft),
      KeyBinding(key: LogicalKey.d, action: IntentAction.moveRight),
      KeyBinding(key: LogicalKey.space, action: IntentAction.jump),
      KeyBinding(key: LogicalKey.shiftLeft, action: IntentAction.sprint),
    ],
    mouseSensitivity: 1.0,
    invertMouseY: false,
  );
}

/// Factory function to create numpad keys configuration.
///
/// Alternative control scheme using numpad keys:
/// - Numpad 8/2/4/6 for movement
/// - Space for jump
/// - Shift for sprint
InputConfiguration createNumpadConfiguration() {
  return InputConfiguration(
    keyBindings: [
      KeyBinding(key: LogicalKey.numpad8, action: IntentAction.moveForward),
      KeyBinding(key: LogicalKey.numpad2, action: IntentAction.moveBackward),
      KeyBinding(key: LogicalKey.numpad4, action: IntentAction.moveLeft),
      KeyBinding(key: LogicalKey.numpad6, action: IntentAction.moveRight),
      KeyBinding(key: LogicalKey.space, action: IntentAction.jump),
      KeyBinding(key: LogicalKey.shiftRight, action: IntentAction.sprint),
    ],
    mouseSensitivity: 1.0,
    invertMouseY: false,
  );
}

