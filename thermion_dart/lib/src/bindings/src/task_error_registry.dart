import 'dart:async';

/// Matches error completions to the request that installed a native dispatch
/// scope. Success callbacks retain their existing ABI and complete the same
/// completer. Each scope is cleared before yielding back to the event loop.
class TaskErrorRegistry {
  TaskErrorRegistry({required this.install, required this.clear, this.onPendingChanged});

  final void Function(int requestId) install;
  final int Function() clear;

  /// Called on transitions between idle and pending work. Native listeners use
  /// this to keep their isolate alive only while a request is outstanding.
  final void Function(bool active)? onPendingChanged;
  final _pending = <int, void Function(Object)>{};
  int _nextRequestId = 0;
  int get pendingRequestCount => _pending.length;

  void fail(int requestId, String message) {
    _pending[requestId]?.call(StateError(message));
  }

  /// Native calls using this callback must be queued synchronously in dispatch.
  /// The scope is cleared before yielding. Async orchestration belongs outside
  /// the callback helper; calls after await need their own helper and scope.
  ///
  /// A Dart dispatch error is not native completion. If dispatch submitted work,
  /// keep its callback, buffers, and (on web) completion pump alive until the
  /// native success/error callback arrives. Native failures affect only their
  /// own scope; awaiting a child Future propagates errors to its parent.
  Future<T> invoke<T>(Completer<T> completer, FutureOr<void> Function() dispatch, {void Function()? pump}) async {
    while (_pending.containsKey(_nextRequestId)) {
      _nextRequestId = (_nextRequestId + 1) & 0x7fffffff;
    }
    final requestId = _nextRequestId;
    _nextRequestId = (_nextRequestId + 1) & 0x7fffffff;
    _pending[requestId] = (error) {
      if (!completer.isCompleted) completer.completeError(error);
    };
    Object? dispatchError;
    StackTrace? dispatchStack;
    var queuedTasks = 0;
    Future<void>? asyncDispatch;
    void failedDispatch(Object error, StackTrace stack) {
      dispatchError ??= error;
      dispatchStack ??= stack;
      if (queuedTasks == 0 && !completer.isCompleted) {
        completer.completeError(error, stack);
      }
    }

    try {
      if (_pending.length == 1) onPendingChanged?.call(true);
      var installed = false;
      try {
        install(requestId);
        installed = true;
        final result = dispatch();
        if (result is Future<void>) asyncDispatch = result;
      } catch (error, stack) {
        // Read the scope's submission count before deciding whether it is safe
        // to finish. Dispatch may have queued work before it threw.
        dispatchError = error;
        dispatchStack = stack;
      } finally {
        if (installed) queuedTasks = clear();
      }
      if (dispatchError != null) failedDispatch(dispatchError!, dispatchStack!);

      Future<void> observeSetup() async {
        try {
          await asyncDispatch;
        } catch (error, stack) {
          failedDispatch(error, stack);
        }
      }

      Future<void> poll() async {
        while (!completer.isCompleted) {
          try {
            pump!();
          } catch (error, stack) {
            // A pump error cannot cancel queued native work. Keep draining it
            // before callers can release callbacks or buffers on this Future.
            failedDispatch(error, stack);
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }

      try {
        if (asyncDispatch != null || pump != null) {
          await Future.wait<void>([
            completer.future.then<void>((_) {}),
            if (asyncDispatch != null) observeSetup(),
            if (pump != null) poll(),
          ]);
        }
        final result = await completer.future;
        if (dispatchError != null) Error.throwWithStackTrace(dispatchError!, dispatchStack!);
        return result;
      } catch (_) {
        if (dispatchError != null) Error.throwWithStackTrace(dispatchError!, dispatchStack!);
        rethrow;
      }
    } finally {
      _pending.remove(requestId);
      if (_pending.isEmpty) onPendingChanged?.call(false);
    }
  }
}
