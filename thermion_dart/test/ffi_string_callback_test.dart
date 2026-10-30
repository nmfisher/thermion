@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart' as ffi;
import 'package:thermion_dart/src/bindings/string_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';

void main() {
  test('zero required bytes produces null', () async {
    final result = await readString(
      (_, _) => ffi.withSizeCallback((callback) {
        callback.asFunction<void Function(int)>()(0);
      }),
    );
    expect(result, isNull);
  });

  test('string dispatch failure reaches the returned Future', () async {
    final error = StateError('string dispatch failed');
    await expectLater(readString((_, _) => ffi.withSizeCallback((_) => throw error)), throwsA(same(error)));
  });

  final fixturePath = Platform.environment['THERMION_STRING_CALLBACK_FIXTURE'];
  group(
    'caller-owned view-name buffers',
    () {
      late FFIFilamentApp app;
      late void Function() reset;
      late bool Function() wait;
      late ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>> completed;

      setUpAll(() async {
        final fixture = ffi.DynamicLibrary.open(fixturePath!);
        reset = fixture.lookupFunction<ffi.Void Function(), void Function()>('resetTaskCompletion');
        wait = fixture.lookupFunction<ffi.Bool Function(), bool Function()>('waitForTaskCompletion');
        completed = fixture.lookup('markTaskCompleted');
        await FFIFilamentApp.create(
          config: FFIFilamentConfig(
            backend: Platform.isMacOS ? Backend.METAL : Backend.DEFAULT,
            loadResource: (uri) => File(uri).readAsBytes(),
          ),
        );
        app = FilamentApp.instance! as FFIFilamentApp;
      });
      tearDownAll(() => app.destroy());

      for (final destroy in [false, true]) {
        test('copied buffer survives ${destroy ? 'destruction' : 'rename'} before Dart delivery', () async {
          final view = await ffi.withPointerCallback<ffi.TView>(
            (callback) => ffi.Engine_createViewJobThread(app.engine, callback),
          );
          final original = List.filled(128, 'original view name Ω🚗').join();
          final bytes = utf8.encode(original);
          final input = original.toNativeUtf8();
          final replacement = 'replacement'.toNativeUtf8();
          final output = ffi.calloc<ffi.Uint8>(bytes.length + 1);
          try {
            await ffi.withVoidCallback((id, callback) => ffi.View_setNameJobThread(view, input.cast(), id, callback));
            reset();
            final name = ffi.withSizeCallback(
              (callback) => ffi.View_getNameJobThread(view, output.cast(), bytes.length + 1, callback),
            );
            final changed = ffi.withVoidCallback((id, callback) {
              if (destroy) {
                ffi.Engine_destroyViewJobThread(app.engine, view, id, callback);
              } else {
                ffi.View_setNameJobThread(view, replacement.cast(), id, callback);
              }
            });
            ffi.JobThread_addTask(completed);
            // Force the native mutation to finish before Dart can handle either
            // completion. The output belongs to Dart and must still be readable.
            expect(wait(), isTrue);
            expect(await name, bytes.length + 1);
            expect(utf8.decode(output.asTypedList(bytes.length)), original);
            await changed;
          } finally {
            if (!destroy)
              await ffi.withVoidCallback(
                (id, callback) => ffi.Engine_destroyViewJobThread(app.engine, view, id, callback),
              );
            ffi.calloc.free(input);
            ffi.calloc.free(replacement);
            ffi.calloc.free(output);
          }
        });

        test('resize retries finish before ${destroy ? 'destruction' : 'rename'}', () async {
          final view = await app.createView() as FFIView;
          final original = List.filled(128, 'long view name Ω🚗').join();
          await view.setName(original);
          final read = view.getName();
          final changed = destroy ? view.destroy() : view.setName('replacement');
          try {
            expect(await read, original);
            await changed;
            if (destroy) {
              await expectLater(view.getName(), throwsStateError);
            } else {
              expect(await view.getName(), 'replacement');
            }
          } finally {
            await changed;
            if (!destroy) await view.destroy();
          }
        });
      }

      test('capacity checks leave undersized buffers and guard bytes unchanged', () async {
        final view = await app.createView() as FFIView;
        const name = 'UTF-8 Ω🚗';
        final bytes = utf8.encode(name);
        final required = bytes.length + 1;
        final buffer = ffi.calloc<ffi.Uint8>(required + 8);
        try {
          await view.setName(name);
          Future<int> read(ffi.Pointer<ffi.Char> output, int capacity) => ffi.withSizeCallback((callback) {
            ffi.View_getNameJobThread(view.getNativeHandle(), output, capacity, callback);
          });
          expect(await read(ffi.nullptr, 0), required);
          buffer.asTypedList(required + 8).fillRange(0, required + 8, 0x5a);
          expect(await read(buffer.cast(), required - 1), required);
          expect(buffer.asTypedList(required + 8), everyElement(0x5a));
          expect(await read(buffer.cast(), required), required);
          expect(buffer.asTypedList(required), [...bytes, 0]);
          expect(buffer.asTypedList(required + 8).skip(required), everyElement(0x5a));
        } finally {
          ffi.calloc.free(buffer);
          await view.destroy();
        }
      });

      test('empty names are distinct from null', () async {
        final view = await app.createView() as FFIView;
        try {
          await view.setName('');
          expect(await view.getName(), '');
        } finally {
          await view.destroy();
        }
      });

      test('invalid UTF-8 does not block view destruction', () async {
        final view = await app.createView() as FFIView;
        final text = ffi.calloc<ffi.Uint8>(2)..[0] = 0xff;
        try {
          await ffi.withVoidCallback(
            (id, callback) => ffi.View_setNameJobThread(view.getNativeHandle(), text.cast(), id, callback),
          );
          final read = view.getName();
          final destroyed = view.destroy();
          await expectLater(read, throwsFormatException);
          await destroyed;
        } finally {
          ffi.calloc.free(text);
        }
      });
    },
    skip: fixturePath == null ? 'Set THERMION_STRING_CALLBACK_FIXTURE; see native/test/rendering/README.md' : false,
  );
}
