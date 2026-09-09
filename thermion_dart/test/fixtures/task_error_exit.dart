import 'dart:async';
import 'package:thermion_dart/src/bindings/src/ffi.dart';

// Deliberately return from main instead of calling exit(): a leaked listener
// keeps this process alive and makes the parent regression test time out.
Future<void> main(List<String> args) async {
  final fixture = DynamicLibrary.open(args.single);
  final fail = fixture.lookup<NativeFunction<Void Function()>>('throwTaskError');
  final thread = RenderThread_create();
  try {
    var failed = false;
    try {
      await withIntCallback((_) => RenderThread_addTask(fail));
    } on StateError {
      failed = true;
    }
    if (!failed) throw StateError('Native exception was lost');
    await withVoidCallback((id, callback) {
      callback.asFunction<void Function(int)>()(id);
    });
  } finally {
    // Stop the worker before allowing its owning Dart isolate to go away.
    RenderThread_destroy(thread);
  }
  print('native workers stopped');
}
