import 'dart:ffi';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/void_callback_registry.dart';

void main() {
  test('completed void callbacks are removed from the request registry', () async {
    final registry = VoidCallbackRegistry();
    late int completedRequestId;
    late void Function(int) invokeCallback;

    await registry.invoke((requestId, nativeCallback) {
      completedRequestId = requestId;
      invokeCallback = nativeCallback.asFunction<void Function(int)>();
      invokeCallback(requestId);
    });
    expect(registry.pendingRequestCount, 0);

    // A late or duplicate native callback must not find and complete the old
    // Completer again. The test framework will fail this test if the listener
    // throws an asynchronous "Future already completed" error.
    invokeCallback(completedRequestId);
    await Future<void>.delayed(Duration.zero);
    registry.close();
  });
}
