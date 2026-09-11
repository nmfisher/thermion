import 'dart:async';
import 'dart:ffi';

/// Dispatches native void callbacks through one long-lived FFI trampoline.
///
/// The registry owns pending completers only until native code invokes their
/// request ID. A single trampoline is retained for the registry lifetime so
/// concurrent native requests cannot call metadata from a collected
/// [NativeCallable].
/// The listener keeps the isolate alive while requests are pending, but lets
/// it exit after successful completion. Stop native workers before killing
/// their isolate or closing this registry.
class VoidCallbackRegistry {
  int _nextRequestId = 0;
  final _requests = <int, Completer<void>>{};
  bool _dispatchFailed = false;

  late final NativeCallable<Void Function(Int32)> _nativeCallable = NativeCallable<Void Function(Int32)>.listener(
    _complete,
  )..keepIsolateAlive = false;

  int get pendingRequestCount => _requests.length;

  void _complete(int requestId) {
    // Consume the entry before completing the future. Keeping completed
    // completers here retains every FFI request for the registry lifetime,
    // including one entry per rendered frame.
    final completer = _requests.remove(requestId);
    completer?.complete();
  }

  Future<void> invoke(Function(int, Pointer<NativeFunction<Void Function(Int32)>>) dispatch) async {
    final requestId = _nextRequestId;
    _nextRequestId++;
    final completer = Completer<void>();
    _requests[requestId] = completer;

    try {
      _nativeCallable.keepIsolateAlive = true;
      dispatch.call(requestId, _nativeCallable.nativeFunction.cast());
      await completer.future;
    } catch (_) {
      // Dispatch may have submitted native work before throwing. Without a
      // completion guarantee, preserve the listener's previous keep-alive
      // behavior until the caller stops its workers and closes the registry.
      _dispatchFailed = true;
      rethrow;
    } finally {
      _requests.remove(requestId);
      _nativeCallable.keepIsolateAlive = _requests.isNotEmpty || _dispatchFailed;
    }
  }

  void close() {
    if (_requests.isNotEmpty) throw StateError('Cannot close a registry with pending callbacks');
    _nativeCallable.close();
  }
}
