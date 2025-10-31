import 'dart:ffi' as ffi;
import 'package:thermion_dart/thermion_dart.dart' hide NativeLibrary;
import 'package:thermion_dart/thermion_dart.dart' as t;

import '../../bindings/bindings.dart' as bindings;

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

/// Wrapper class for a TMovementIntentExecutor pointer.
///
/// This class encapsulates operations on a movement intent executor,
/// providing a type-safe API for setting movement targets and managing
/// the executor lifecycle.
abstract class MovementIntentExecutor {
  final ffi.Pointer<bindings.TMovementIntentExecutor> _pointer;
  bool _disposed = false;

  /// Creates a MovementIntentExecutor wrapping the given native pointer.
  ///
  /// [pointer] - The native TMovementIntentExecutor pointer to wrap
  MovementIntentExecutor(this._pointer);

  /// Gets the underlying native pointer.
  ///
  /// Throws [StateError] if the executor has been disposed.
  ffi.Pointer<bindings.TMovementIntentExecutor> get pointer {
    if (_disposed) {
      throw StateError('MovementIntentExecutor has been disposed');
    }
    return _pointer;
  }


  /// Disposes the executor and releases native resources.
  ///
  /// After calling this, the executor cannot be used anymore.
  void dispose() {
    if (_disposed) return;

    try {
      bindings.MovementIntentExecutor_destroy(_pointer);
      _disposed = true;
    } catch (e) {
      throw InputHandlerManagerException('Failed to dispose executor: $e');
    }
  }

  /// Checks if the executor has been disposed.
  bool get isDisposed => _disposed;


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

  InputPipeline._internal();

  bool _initialized = false;
  t.Pointer<ffi.Void>? _engine;

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
      bindings.TransformPipeline_setEngine(engine);
      _initialized = true;
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to initialize InputPipeline: $e',
      );
    }
  }

  ///
  ///
  ///
  void registerPipelineStage(Pointer<Void> stage, String name) {
    try {
      bindings.TransformPipeline_registerPipelineStage(
        stage,
        name.toNativeUtf8().cast(),
      );
    } catch (e) {
      throw InputHandlerManagerException(
        'Failed to set invert horizontal look for entity: $e',
      );
    }
  }


  /// Registers a transform executor with the pipeline.
  ///
  /// [executor] - The MovementIntentExecutor to register with the pipeline
  ///
  /// Throws [InputHandlerManagerException] if registration fails.
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
  /// Throws [InputHandlerManagerException] if the update fails.
  void updatePipeline(double deltaTime) {
    try {
      bindings.TransformPipeline_update(deltaTime);
    } catch (e) {
      throw InputHandlerManagerException('Failed to update pipeline: $e');
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
