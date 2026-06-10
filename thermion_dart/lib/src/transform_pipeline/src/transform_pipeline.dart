import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart' hide NativeLibrary;
import 'package:thermion_dart/thermion_dart.dart' as t;

import '../../bindings/bindings.dart' as bindings;
import 'input_configuration.dart';
import 'intent_action.dart';
import 'movement_intent_executor.dart';

/// Movement space enumeration for input handler components.
///
/// Determines whether movement is applied in world space or object/local space.
enum MovementSpace {
  /// Movement is applied in world space coordinates (default behavior).
  /// W/S moves along world Z axis, A/D moves along world X axis.
  world,

  /// Movement is applied in object/local space coordinates.
  /// Movement follows the entity's current forward direction.
  object,
}

class MovementConfig {
  MovementSpace movementSpace = MovementSpace.world;
  double baseMoveSpeed = 50.0;
  double mouseSensitivity = 0.001;
  bool invertHorizontalMovement = false;
}

/// Singleton wrapper for Thermion Input Handler system functionality.
///
/// This class provides a clean, type-safe API around the lower-level native bindings,
/// handling component management and providing proper Dart types for consumers.
///
/// Use [InputPipeline.instance] to access the singleton instance.
class InputPipeline {
  static final InputPipeline _instance = InputPipeline._internal();

  static InputPipeline get instance => _instance;

  late final _logger = Logger(this.runtimeType.toString());

  InputPipeline._internal();

  bool _initialized = false;
  t.Pointer<Void>? _engine;

  /// Initializes the Thermion Input Handler system with the given engine.
  ///
  /// This must be called before using any other methods.
  /// The [engine] should be a valid Thermion engine pointer.
  ///
  /// Throws [Exception] if initialization fails.
  void initialize(t.Pointer<Void> engine) {
    if (_initialized) {
      throw StateError('InputPipeline is already initialized');
    }

    try {
      _engine = engine;
      bindings.TransformPipeline_setEngine(engine);
      _initialized = true;
    } catch (e) {
      throw Exception(
        'Failed to initialize InputPipeline: $e',
      );
    }
  }

  ///
  ///
  ///
  void registerPipelineStage(Pointer<Void> stage, String name) {
    final ptr = name.toNativeUtf8().cast();
    try {
      bindings.TransformPipeline_registerPipelineStage(stage, ptr.cast());
    } catch (e) {
      throw Exception(
        'Failed to set invert horizontal look for entity: $e',
      );
    } finally {
      free(ptr);
    }
  }

  /// Registers a transform executor with the pipeline.
  ///
  /// [executor] - The MovementIntentExecutor to register with the pipeline
  ///
  /// Throws [Exception] if registration fails.
  void registerMovementIntentExecutor(MovementIntentExecutor executor) {
    bindings.Pipeline_registerMovementIntentExecutor(executor.pointer);
  }

  /// Updates the pipeline manually (fallback when automatic updates don't work).
  ///
  /// This manually triggers the pipeline update to process input events and execute movement.
  /// Use this when the automatic pipeline updates from the plugin system aren't working.
  ///
  /// [deltaTime] - The time delta since the last frame (in seconds)
  ///
  /// Throws [Exception] if the update fails.
  void updatePipeline(double deltaTime) {
    try {
      bindings.TransformPipeline_update(deltaTime);
    } catch (e) {
      throw Exception('Failed to update pipeline: $e');
    }
  }

  /// Cleans up the input handler component manager and releases resources.
  ///
  /// This should be called when the manager is no longer needed.
  /// After cleanup, the manager must be re-initialized before use.
  void cleanup() {
    try {
      bindings.TransformPipeline_cleanup();
      _initialized = false;
      _engine = null;
    } catch (e) {
      _logger.severe(e);
      _logger.severe(e);
      rethrow;
    }
  }

  /// Gets the engine pointer used for initialization.
  ///
  /// Returns null if the manager is not initialized.
  t.Pointer<Void>? get engine => _engine;

  /// Handles input events using the unified InputEvent system.
  ///
  /// Events are global and will be broadcast to all entities with InputHandlerComponent.
  /// [event] - The input event to handle
  ///
  /// Throws [Exception] if the manager is not initialized or if the operation fails.
  void onInputEvent(InputEvent event) {
    try {
      switch (event) {
        case MouseEvent():
          bindings.TransformPipeline_onMouseEvent(
            event.type.index,
            event.button?.index ?? -1,
            event.localPosition.x,
            event.localPosition.y,
            event.delta.x,
            event.delta.y,
          );

        case KeyEvent():
          bindings.TransformPipeline_onKeyEvent(
            event.type.index,
            event.logicalKey.index,
            event.physicalKey.index,
            event.synthesized ? 1 : 0,
          );

        case ScrollEvent():
          bindings.TransformPipeline_onScrollEvent(
            event.localPosition.x,
            event.localPosition.y,
            event.delta,
          );

        case TouchEvent():
          // Touch events not yet supported by native bindings
          // TODO: Implement native touch event handling when available
          break;

        case ScaleStartEvent():
        case ScaleUpdateEvent():
        case ScaleEndEvent():
          // Scale events not yet supported by native bindings
          // TODO: Implement native scale event handling when available
          break;
      }
    } catch (e) {
      throw Exception('Failed to handle input event: $e');
    }
  }

  /// Checks if the manager is initialized.
  bool get isInitialized => _initialized;

  /// Disposes the manager and cleans up resources.
  void dispose() {
    cleanup();
  }

  // Input configuration methods

  /// Add a keybinding to the input calculator configuration.
  ///
  /// [key] - The logical key to bind
  /// [action] - The intent action to trigger
  /// [value] - Optional value multiplier (default 1.0)
  ///
  /// Throws [Exception] if the operation fails.
  void addKeyBinding(LogicalKey key, IntentAction action,
      {double value = 1.0}) {
    try {
      bindings.TransformPipeline_addKeyBinding(
          key.index, action.nativeValue, value);
    } catch (e) {
      throw Exception('Failed to add key binding: $e');
    }
  }

  /// Remove all keybindings for a specific key.
  ///
  /// [key] - The logical key whose bindings should be removed
  ///
  /// Throws [Exception] if the operation fails.
  void removeKeyBindingsForKey(LogicalKey key) {
    try {
      bindings.TransformPipeline_removeKeyBindingsForKey(key.index);
    } catch (e) {
      throw Exception('Failed to remove key bindings for key: $e');
    }
  }

  /// Remove all keybindings for a specific action.
  ///
  /// [action] - The intent action whose bindings should be removed
  ///
  /// Throws [Exception] if the operation fails.
  void removeKeyBindingsForAction(IntentAction action) {
    try {
      bindings.TransformPipeline_removeKeyBindingsForAction(action.nativeValue);
    } catch (e) {
      throw Exception('Failed to remove key bindings for action: $e');
    }
  }

  /// Clear all keybindings from the input calculator configuration.
  ///
  /// Throws [Exception] if the operation fails.
  void clearKeyBindings() {
    try {
      bindings.TransformPipeline_clearKeyBindings();
    } catch (e) {
      throw Exception('Failed to clear key bindings: $e');
    }
  }

  /// Set the mouse sensitivity multiplier.
  ///
  /// [sensitivity] - Mouse sensitivity value (typically 0.1 to 2.0)
  ///
  /// Throws [Exception] if the operation fails.
  void setMouseSensitivity(double sensitivity) {
    try {
      bindings.TransformPipeline_setMouseSensitivity(sensitivity);
    } catch (e) {
      throw Exception('Failed to set mouse sensitivity: $e');
    }
  }

  /// Set whether to invert the mouse Y axis.
  ///
  /// [invert] - True to invert Y axis, false for normal behavior
  ///
  /// Throws [Exception] if the operation fails.
  void setInvertMouseY(bool invert) {
    try {
      bindings.TransformPipeline_setInvertMouseY(invert ? 1 : 0);
    } catch (e) {
      throw Exception('Failed to set invert mouse Y: $e');
    }
  }

  /// Add a mouse button binding to the input calculator configuration.
  ///
  /// [button] - The mouse button to bind
  /// [action] - The intent action to trigger
  /// [value] - Optional value multiplier (default 1.0)
  ///
  /// Throws [Exception] if the operation fails.
  void addMouseButtonBinding(MouseButton button, IntentAction action,
      {double value = 1.0}) {
    try {
      bindings.TransformPipeline_addMouseButtonBinding(
          button.index, action.nativeValue, value);
    } catch (e) {
      throw Exception('Failed to add mouse button binding: $e');
    }
  }

  /// Remove all bindings for a specific mouse button.
  ///
  /// [button] - The mouse button whose bindings should be removed
  ///
  /// Throws [Exception] if the operation fails.
  void removeMouseButtonBindings(MouseButton button) {
    try {
      bindings.TransformPipeline_removeMouseButtonBindings(button.index);
    } catch (e) {
      throw Exception('Failed to remove mouse button bindings: $e');
    }
  }

  /// Apply a complete input configuration.
  ///
  /// This is a convenience method that clears existing bindings and applies
  /// the provided configuration all at once.
  ///
  /// [config] - The input configuration to apply
  ///
  /// Throws [Exception] if the operation fails.
  void setInputConfiguration(InputConfiguration config) {
    try {
      // Clear existing bindings
      clearKeyBindings();

      // Add all keybindings from config
      for (final binding in config.keyBindings) {
        addKeyBinding(binding.key, binding.action, value: binding.value);
      }

      // Add all mouse button bindings from config
      for (final binding in config.mouseButtonBindings) {
        addMouseButtonBinding(binding.button, binding.action,
            value: binding.value);
      }

      // Set mouse settings
      setMouseSensitivity(config.mouseSensitivity);
      setInvertMouseY(config.invertMouseY);

      _logger.info(
          'Applied input configuration with ${config.keyBindings.length} key bindings and ${config.mouseButtonBindings.length} mouse button bindings');
    } catch (e) {
      throw Exception('Failed to set input configuration: $e');
    }
  }
}
