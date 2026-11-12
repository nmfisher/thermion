@TestOn('vm')
library;

import 'dart:async';
import 'dart:ffi';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/pending_callback.dart';

void main() {
  test('disposal retains the listener until all pending native results arrive', () async {
    final delivered = Completer<void>();
    var notifications = 0;
    var handlerCalls = 0;
    var disposeHooks = 0;
    var closes = 0;
    late PendingCallback lifetime;
    final listener = NativeCallable<Void Function(Int32)>.listener((int result) {
      lifetime.complete();
      if (!lifetime.isDisposed) handlerCalls++;
      if (++notifications == 2) delivered.complete();
    });
    expect(listener.keepIsolateAlive, isTrue);
    lifetime = PendingCallback(
      () {
        closes++;
        listener.close();
      },
      onDispose: () {
        disposeHooks++;
        listener.keepIsolateAlive = false;
      },
    );
    lifetime.begin();
    lifetime.begin();
    final invoke = listener.nativeFunction.asFunction<void Function(int)>();
    lifetime.dispose();
    lifetime.dispose();
    expect(disposeHooks, 1);
    expect(listener.keepIsolateAlive, isFalse);
    expect(closes, 0);
    expect(lifetime.begin, throwsStateError);

    // These would call a closed trampoline with the old immediate-dispose path.
    invoke(1);
    invoke(2);
    await delivered.future.timeout(const Duration(seconds: 2));
    expect(notifications, 2);
    expect(handlerCalls, 0);
    expect(disposeHooks, 1);
    expect(closes, 1);
    lifetime.dispose();
    expect(disposeHooks, 1);
    expect(closes, 1);
  });

  test('normal delivery keeps the callback open until disposal', () async {
    final delivered = Completer<void>();
    var closes = 0;
    late PendingCallback lifetime;
    final listener = NativeCallable<Void Function()>.listener(() {
      lifetime.complete();
      expect(lifetime.isDisposed, isFalse);
      delivered.complete();
    });
    lifetime = PendingCallback(() {
      closes++;
      listener.close();
    });
    lifetime.begin();
    listener.nativeFunction.asFunction<void Function()>()();
    await delivered.future.timeout(const Duration(seconds: 2));
    expect(closes, 0);
    lifetime.dispose();
    expect(closes, 1);
  });
}
