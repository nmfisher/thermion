import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart';
import 'package:thermion_dart/src/bindings/src/native_task_errors.dart';

// Build native/test/rendering and point this variable at its fixture library.
// Keeping deliberate native exceptions in the fixture avoids adding test-only
// entry points to Thermion's public C API.
void main() {
  final fixturePath = Platform.environment['THERMION_TASK_ERROR_FIXTURE'];
  group(
    'native task errors',
    () {
      late DynamicLibrary fixture;
      late Pointer<NativeFunction<Void Function()>> fail;
      late Pointer<Void> thread;

      setUpAll(() {
        fixture = DynamicLibrary.open(fixturePath!);
        fail = fixture.lookup<NativeFunction<Void Function()>>('throwTaskError');
      });
      setUp(() {
        thread = RenderThread_create();
      });
      tearDown(() {
        RenderThread_destroy(thread);
      });

      test('callback C API task failures reach typed and void Dart futures', () async {
        final expected = throwsA(
          isA<StateError>().having((error) => error.message, 'message', 'expected native task failure'),
        );
        await expectLater(withIntCallback((_) => RenderThread_addTask(fail)), expected);
        await expectLater(withBoolCallback((_) => RenderThread_addTask(fail)), expected);
        await expectLater(withPointerCallback<Void>((_) => RenderThread_addTask(fail)), expected);
        await expectLater(withVoidCallback((_, __) => RenderThread_addTask(fail)), expected);
        expect(nativeTaskErrors.pendingRequestCount, 0);

        // The same worker must execute another task after those failures.
        final done = Completer<void>();
        final success = NativeCallable<Void Function()>.listener(() => done.complete());
        try {
          await nativeTaskErrors.invoke(done, () => RenderThread_addTask(success.nativeFunction));
        } finally {
          success.close();
        }
      });

      for (final asyncFailure in [false, true]) {
        test('typed callback survives dispatch failure after enqueue: async=$asyncFailure', () async {
          late Pointer<NativeFunction<Void Function(Int32)>> resultCallback;
          var delivered = false;
          final nativeWork = NativeCallable<Void Function()>.listener(() {
            resultCallback.asFunction<void Function(int)>()(42);
            delivered = true;
          });
          try {
            await expectLater(
              withIntCallback((cb) {
                resultCallback = cb;
                RenderThread_addTask(nativeWork.nativeFunction);
                if (asyncFailure) return Future<void>.error(StateError('Dart dispatch failed'));
                throw StateError('Dart dispatch failed');
              }),
              throwsA(isA<StateError>().having((e) => e.message, 'message', 'Dart dispatch failed')),
            );
            expect(delivered, isTrue);
            expect(nativeTaskErrors.pendingRequestCount, 0);
          } finally {
            nativeWork.close();
          }
        });
      }

      test('a child failure does not complete the separate upload-release callback', () async {
        late Future<int> creation;
        late void Function() finishUpload;
        var released = false;
        final uploadReleased =
            withVoidCallback((id, callback) {
              finishUpload = () => callback.asFunction<void Function(int)>()(id);
              creation = withIntCallback((_) => RenderThread_addTask(fail));
            }).then((_) {
              released = true;
            });
        try {
          await expectLater(creation, throwsA(isA<StateError>()));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(released, isFalse);
          expect(nativeTaskErrors.pendingRequestCount, 1);
        } finally {
          finishUpload();
          await uploadReleased;
        }
        expect(nativeTaskErrors.pendingRequestCount, 0);
      });

      test('unknown C++ exceptions also settle the Dart request', () async {
        final unknown = fixture.lookup<NativeFunction<Void Function()>>('throwUnknownTaskError');
        await expectLater(
          withIntCallback((_) => RenderThread_addTask(unknown)),
          throwsA(isA<StateError>().having((error) => error.message, 'message', 'Unknown native task exception')),
        );
        expect(nativeTaskErrors.pendingRequestCount, 0);
      });

      test('idle callback listeners allow a standalone process to exit', () async {
        final process = await Process.start(Platform.resolvedExecutable, [
          'run',
          'test/fixtures/task_error_exit.dart',
          fixturePath!,
        ]);
        final ready = Completer<void>();
        final output = StringBuffer();
        final stdout = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
          output.writeln(line);
          if (line == 'native workers stopped' && !ready.isCompleted) ready.complete();
        });
        final stderr = process.stderr.transform(utf8.decoder).join();
        final exited = process.exitCode.then((code) {
          if (!ready.isCompleted) ready.completeError(StateError('Child exited before finishing requests: $code'));
          return code;
        });
        try {
          // Allow the Dart native build hook to run before measuring shutdown.
          await ready.future.timeout(const Duration(minutes: 3));
          final code = await exited.timeout(const Duration(seconds: 5));
          await stdout;
          expect(code, 0, reason: '$output\n${await stderr}');
        } finally {
          process.kill();
        }
      }, timeout: const Timeout(Duration(minutes: 4)));
    },
    skip: fixturePath == null ? 'Set THERMION_TASK_ERROR_FIXTURE; see native/test/rendering/README.md' : false,
  );
}
