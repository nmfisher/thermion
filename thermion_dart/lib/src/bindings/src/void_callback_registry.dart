import 'dart:async';
import 'dart:ffi';

/// Dispatches native void callbacks through one long-lived FFI trampoline.
///
/// The registry owns pending completers only until native code invokes their
/// request ID. A single trampoline is retained for the registry lifetime so
/// concurrent native requests cannot call metadata from a collected
/// [NativeCallable].
class VoidCallbackRegistry {
  int _nextRequestId = 0;
  final _requests = <int, Completer<void>>{};

  late final NativeCallable<Void Function(Int32)> _nativeCallable = NativeCallable<Void Function(Int32)>.listener(
    _complete,
  );

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
      dispatch.call(requestId, _nativeCallable.nativeFunction.cast());
    } catch (_) {
      _requests.remove(requestId);
      rethrow;
    }

    await completer.future;
  }

  void close() {
    _nativeCallable.close();
  }
}
