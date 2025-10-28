import 'dart:ffi' as ffi;
import 'package:thermion_dart/thermion_dart.dart' hide NativeLibrary;
import 'package:thermion_dart/thermion_dart.dart' as t;

import '../../bindings/bindings.dart' as bindings;
// import 'bindings/src/input_handler_ffi.g.dart' as bindings;

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

/// Singleton wrapper for Thermion Input Handler system functionality.
///
/// This class provides a clean, type-safe API around the lower-level native bindings,
/// handling component management and providing proper Dart types for consumers.
///
/// Use [InputPipeline.instance] to access the singleton instance.
class InputPipeline {
  static final InputPipeline _instance = InputPipeline._internal();

  /// Gets the singleton instance of the input handler component manager.
  static InputPipeline get instance => _instance;

  InputPipeline._internal();

  bool _initialized = false;
  t.Pointer<ffi.Void>? _engine;
  ffi.Pointer<bindings.TMovementIntentExecutor>? _movementIntentExecutor;

  /// Initializes the Thermion Input Handler system with the given engine.
  ///
  /// This must be called before using any other methods.
  /// The [engine] should be a valid Thermion engine pointer.
  ///
  /// Throws [InputHandlerManagerException] if initialization fails.
  void initialize(t.Pointer<ffi.Void> engine) {
    if (_initialized) {
      throw StateError('InputPipeline is already initialized');
    }

    try {
      _engine = engine;
      bindings.input_pipeline_set_engine(engine);
      _initialized = true;
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to initialize InputPipeline: $e',
      );
    }
  }

  /// Sets the movement space for the specified entity's input handler component.
  ///
  /// [entity] - The Thermion entity whose movement space should be set
  /// [movementSpace] - The movement space to use (world or object space)
  ///
  /// Throws [InputHandlerManagerException] if the manager is not initialized or if the operation fails.
  void setMovementSpace(ThermionEntity entity, MovementSpace movementSpace) {
    try {
      bindings.input_pipeline_set_movement_space(entity, movementSpace.index);
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to set movement space for entity: $e',
      );
    }
  }

  /// Sets whether horizontal look movement should be inverted for the specified entity's input handler component.
  ///
  /// When enabled, horizontal mouse movement is reversed:
  /// - Mouse moving right causes the entity to rotate left (counterclockwise)
  /// - Mouse moving left causes the entity to rotate right (clockwise)
  ///
  /// This affects camera/look rotation, not translation movement. A/D keys always work normally.
  ///
  /// [entity] - The Thermion entity whose horizontal look inversion should be set
  /// [invert] - Whether to invert horizontal look (true) or use normal direction (false)
  ///
  /// Throws [InputHandlerManagerException] if the manager is not initialized or if the operation fails.
  void setInvertHorizontalMovement(ThermionEntity entity, bool invert) {
    try {
      bindings.input_pipeline_set_invert_horizontal_movement(
        entity,
        invert ? 1 : 0,
      );
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to set invert horizontal look for entity: $e',
      );
    }
  }

  void registerPipelineStage(Pointer<Void> stage, String name) {
    try {
      bindings.input_pipeline_register_pipeline_stage(
        stage,
        name.toNativeUtf8().cast(),
      );
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to set invert horizontal look for entity: $e',
      );
    }
  }

  /// Sets the movement speed for the specified entity's input handler component.
  ///
  /// [entity] - The Thermion entity whose movement speed should be set
  /// [speed] - The movement speed multiplier (higher values = faster movement)
  ///
  /// Throws [InputHandlerManagerException] if the manager is not initialized or if the operation fails.
  void setMovementSpeed(ThermionEntity entity, double speed) {
    try {
      bindings.input_pipeline_set_movement_speed(entity, speed);
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to set movement speed for entity: $e',
      );
    }
  }

  /// Sets the mouse sensitivity for the specified entity's input handler component.
  ///
  /// [entity] - The Thermion entity whose mouse sensitivity should be set
  /// [sensitivity] - The mouse sensitivity multiplier (higher values = faster rotation)
  ///
  /// Throws [InputHandlerManagerException] if the manager is not initialized or if the operation fails.
  void setMouseSensitivity(ThermionEntity entity, double sensitivity) {
    try {
      bindings.input_pipeline_set_mouse_sensitivity(entity, sensitivity);
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to set mouse sensitivity for entity: $e',
      );
    }
  }

  // Movement Intent Processor methods

  /// Creates a movement intent processor for handling the movement pipeline.
  ///
  /// This creates a processor that manages movement intents and executes them
  /// through registered movement executors (transform, physics, character controllers, etc.).
  ///
  /// Returns the created processor instance.
  ///
  /// Throws [InputHandlerManagerException] if the manager is not initialized or if creation fails.
  ffi.Pointer<bindings.TMovementIntentExecutor> createDefaultTransformExecutor() {
    try {
      final processor = bindings.create_default_transform_executor(
        FilamentApp.instance!.engine as Pointer<Void>,
      );
      if (processor == nullptr) {
        throw InputHandlerManagerException(
          'Failed to create movement processor: null pointer returned',
        );
      }

      // Store reference for cleanup
      _movementIntentExecutor = processor;

      return processor;
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to create movement processor: $e',
      );
    }
  }

  void registerTransformExecutor(ffi.Pointer<bindings.TMovementIntentExecutor> executor) {
      bindings.pipeline_register_movement_intent_executor(executor);
  }

  /// Sets the target entity for movement processing.
  ///
  /// This method controls which entity the movement processor will apply
  /// movement to when processing input events.
  ///
  /// [entity] - The Thermion entity that should receive movement input
  ///
  /// Throws [InputHandlerManagerException] if the manager is not initialized
  /// or if no movement processor has been created.
  void setMovementTarget(ThermionEntity entity) {
    if (_movementIntentExecutor == null) {
      throw InputHandlerManagerException(
        'No movement processor available. Call createMovementProcessor() first.',
      );
    }

    try {
      bindings.movement_intent_executor_set_target_entity(
        _movementIntentExecutor!,
        entity,
      );
    } catch (e) {
      throw InputHandlerManagerException('Failed to set movement target: $e');
    }
  }

  /// Updates the pipeline manually (fallback when automatic updates don't work).
  ///
  /// This manually triggers the pipeline update to process input events and execute movement.
  /// Use this when the automatic pipeline updates from the plugin system aren't working.
  ///
  /// [deltaTime] - The time delta since the last frame (in seconds)
  ///
  /// Throws [InputHandlerManagerException] if the update fails.
  void updatePipeline(double deltaTime) {
    try {
      bindings.input_pipeline_update_pipeline(deltaTime);
    } catch (e) {
      throw InputHandlerManagerException('Failed to update pipeline: $e');
    }
  }

  /// Cleans up the input handler component manager and releases resources.
  ///
  /// This should be called when the manager is no longer needed.
  /// After cleanup, the manager must be re-initialized before use.
  void cleanup() {
    if (!_initialized) return;

    try {
      // Clean up movement processor if it exists
      if (_movementIntentExecutor != null) {
        bindings.MovementIntentExecutor_destroy(_movementIntentExecutor!);
        _movementIntentExecutor = null;
      }

      bindings.input_pipeline_cleanup();
      _initialized = false;
      _engine = null;
    } catch (e) {
      throw InputHandlerManagerException('Failed to cleanup InputPipeline: $e');
    }
  }

  /// Gets the engine pointer used for initialization.
  ///
  /// Returns null if the manager is not initialized.
  t.Pointer<ffi.Void>? get engine => _engine;

  /// Handles input events using the unified InputEvent system.
  ///
  /// Events are global and will be broadcast to all entities with InputHandlerComponent.
  /// [event] - The input event to handle
  ///
  /// Throws [InputHandlerManagerException] if the manager is not initialized or if the operation fails.
  void onInputEvent(InputEvent event) {
    try {
      switch (event) {
        case MouseEvent():
          bindings.input_pipeline_on_mouse_event(
            event.type.index,
            event.button?.index ?? -1,
            event.localPosition.x,
            event.localPosition.y,
            event.delta.x,
            event.delta.y,
          );

        case KeyEvent():
          bindings.input_pipeline_on_key_event(
            event.type.index,
            event.logicalKey.index,
            event.physicalKey.index,
            event.synthesized ? 1 : 0,
          );

        case ScrollEvent():
          bindings.input_pipeline_on_scroll_event(
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
      throw InputHandlerManagerException('Failed to handle input event: $e');
    }
  }

  /// Checks if the manager is initialized.
  bool get isInitialized => _initialized;

  /// Disposes the manager and cleans up resources.
  void dispose() {
    cleanup();
  }
}

/// Exception thrown by InputPipeline operations.
class InputHandlerManagerException implements Exception {
  /// The error message.
  final String message;

  /// Creates a new InputHandlerManager exception with the given message.
  const InputHandlerManagerException(this.message);

  @override
  String toString() => 'InputHandlerManagerException: $message';
}
