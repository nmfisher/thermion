import 'dart:async';
import 'dart:ffi';

import 'native_task_errors.dart';

/// Dispatches native void callbacks through one long-lived FFI trampoline.
///
/// The registry owns pending completers only until native code invokes their
/// request ID. A single trampoline is retained for the registry lifetime so
/// concurrent native requests cannot call metadata from a collected
/// [NativeCallable].
/// The trampoline keeps the isolate alive while requests are pending, but an
/// idle registry does not prevent process exit. Stop native workers before
/// killing the owning isolate. close() requires all native callbacks to be done.
class VoidCallbackRegistry {
  int _nextRequestId = 0;
  final _requests = <int, Completer<void>>{};

  late final NativeCallable<Void Function(Int32)> _nativeCallable = NativeCallable<Void Function(Int32)>.listener(
    _complete,
  )..keepIsolateAlive = false;

  int get pendingRequestCount => _requests.length;

  void _complete(int requestId) {
    // Consume the entry before completing the future. Keeping completed
    // completers here retains every FFI request for the registry lifetime,
    // including one entry per rendered frame.
    final completer = _requests.remove(requestId);
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> invoke(Function(int, Pointer<NativeFunction<Void Function(Int32)>>) dispatch) async {
    while (_requests.containsKey(_nextRequestId)) {
      _nextRequestId = (_nextRequestId + 1) & 0x7fffffff;
    }
    final requestId = _nextRequestId;
    _nextRequestId = (_nextRequestId + 1) & 0x7fffffff;
    final completer = Completer<void>();
    _requests[requestId] = completer;

    try {
      _nativeCallable.keepIsolateAlive = true;
      await nativeTaskErrors.invoke(completer, () {
        return dispatch.call(requestId, _nativeCallable.nativeFunction.cast());
      });
    } finally {
      _requests.remove(requestId);
      if (_requests.isEmpty) _nativeCallable.keepIsolateAlive = false;
    }
  }

  void close() {
    if (_requests.isNotEmpty) throw StateError('Cannot close a registry with pending callbacks');
    _nativeCallable.close();
  }
}
