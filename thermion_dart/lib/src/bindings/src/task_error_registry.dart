import 'dart:async';

/// Matches error completions to the request that installed a native dispatch
/// scope. Success callbacks retain their existing ABI and complete the same
/// completer. Each scope is cleared before yielding back to the event loop.
class TaskErrorRegistry {
  TaskErrorRegistry({required this.install, required this.clear});

  final void Function(int requestId) install;
  final void Function() clear;
  final _pending = <int, void Function(Object)>{};
  int _nextRequestId = 0;
  int get pendingRequestCount => _pending.length;

  void fail(int requestId, String message) {
    _pending[requestId]?.call(StateError(message));
  }

  Future<T> invoke<T>(Completer<T> completer, FutureOr<void> Function() dispatch) async {
    while (_pending.containsKey(_nextRequestId)) {
      _nextRequestId = (_nextRequestId + 1) & 0x7fffffff;
    }
    final requestId = _nextRequestId;
    // Emscripten's i32 callbacks use signed JS numbers. Keep IDs positive on
    // both platforms and skip any ID still belonging to an active request.
    _nextRequestId = (_nextRequestId + 1) & 0x7fffffff;
    _pending[requestId] = (error) {
      if (!completer.isCompleted) completer.completeError(error);
    };
    try {
      var installed = false;
      Future<void>? asyncDispatch;
      try {
        install(requestId);
        installed = true;
        final result = dispatch();
        if (result is Future<void>) asyncDispatch = result;
      } catch (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      } finally {
        if (installed) clear();
      }
      // Some upload helpers perform several awaited requests before returning.
      // Observe their failures without keeping thread-local state across await.
      if (asyncDispatch != null) {
        await Future.wait<void>([asyncDispatch, completer.future.then<void>((_) {})], eagerError: true);
      }
      return await completer.future;
    } finally {
      _pending.remove(requestId);
    }
  }
}
