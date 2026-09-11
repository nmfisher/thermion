import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

// A relative import lets this subprocess exercise only Dart FFI, without
// running Thermion's native build hook or creating a rendering engine.
import '../../lib/src/bindings/src/void_callback_registry.dart';

final registry = VoidCallbackRegistry();

Future<void> completeFromWorker(List<int> request) async {
  await Future<void>.delayed(Duration(milliseconds: request[2]));
  final callback = Pointer<NativeFunction<Void Function(Int32)>>.fromAddress(request[0]);
  callback.asFunction<void Function(int)>()(request[1]);
}

Future<void> main(List<String> args) async {
  if (args.single == 'dispatch-failure' || args.single == 'failed-retained') {
    try {
      await registry.invoke((_, __) => throw StateError('failed before submission'));
    } on StateError {
      print('dispatch failed');
    }
    if (args.single == 'failed-retained') {
      await registry.invoke((id, callback) {
        callback.asFunction<void Function(int)>()(id);
      });
      print('completed after failure');
    } else {
      // The registry cannot know whether a failed dispatch submitted native
      // work. This fixture submitted none, so explicit close is safe.
      registry.close();
    }
  } else if (args.single == 'pending') {
    // The worker isolates keep the process alive, but must not be what keeps
    // this isolate alive. No receive port or timer is retained in this isolate.
    // If the listener is unreferenced while requests are pending, a worker will
    // call a dead isolate. The parent test confines that failure to this process.
    for (final delay in [50, 200]) {
      unawaited(
        registry
            .invoke((id, callback) {
              unawaited(Isolate.spawn(completeFromWorker, [callback.address, id, delay]));
            })
            .then((_) => print('completed $delay')),
      );
    }
  } else {
    await registry.invoke((id, callback) {
      callback.asFunction<void Function(int)>()(id);
    });
    print('completed');
  }
  // Successful cases deliberately do not close the process-wide registry:
  // production retains it after the final engine stops.
}
