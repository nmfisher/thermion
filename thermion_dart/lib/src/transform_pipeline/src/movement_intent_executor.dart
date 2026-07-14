import 'package:logging/logging.dart';
import '../../bindings/bindings.dart';
import 'movement_intent.dart';

/// Wrapper class for a TMovementIntentExecutor pointer.
///
/// This class encapsulates operations on a movement intent executor,
/// providing a type-safe API for setting movement targets and managing
/// the executor lifecycle.
abstract class MovementIntentExecutor {
  late final _logger = Logger(this.runtimeType.toString());

  final Pointer<TMovementIntentExecutor> _pointer;

  bool _disposed = false;

  /// Creates a MovementIntentExecutor wrapping the given native pointer.
  ///
  /// [pointer] - The native TMovementIntentExecutor pointer to wrap
  MovementIntentExecutor(this._pointer);

  /// Gets the underlying native pointer.
  ///
  /// Throws [StateError] if the executor has been disposed.
  Pointer<TMovementIntentExecutor> get pointer {
    if (_disposed) {
      throw StateError('MovementIntentExecutor has been disposed');
    }
    return _pointer;
  }

  /// Process a movement intent.
  ///
  /// Sends the intent to the native executor for processing.
  /// [intent] - The movement intent to process
  /// [deltaTime] - Time delta since last frame in seconds
  ///
  /// Throws [StateError] if the executor has been disposed.
  ///
  /// You probably don't need to call this directly; if this instance has been
  /// registered with the [InputPipeline], this will be called on every frame.
  void process(MovementIntent intent, double deltaTime) {
    if (_disposed) {
      throw StateError('MovementIntentExecutor has been disposed');
    }

    try {
      final nativeIntent = intent.toNative();
      final deltaTimeNanos = (deltaTime * 1000000000).round();

      MovementIntentExecutor_process(
        _pointer,
        nativeIntent.address,
        deltaTimeNanos,
      );
    } catch (e) {
      throw Exception('Failed to process movement intent: $e');
    }
  }

  /// Disposes the executor and releases native resources.
  ///
  /// After calling this, the executor cannot be used anymore.
  void dispose() {
    if (_disposed) return;

    try {
      MovementIntentExecutor_destroy(_pointer);
      _disposed = true;
    } catch (e) {
      throw Exception('Failed to dispose executor: $e');
    }
  }

  /// Checks if the executor has been disposed.
  bool get isDisposed => _disposed;
}
