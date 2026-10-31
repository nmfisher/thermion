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

  group('caller-owned view-name buffers', () {
    late FFIFilamentApp app;

    setUpAll(() async {
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
      test('copied buffer survives ${destroy ? 'destruction' : 'rename'} before Dart reads it', () async {
        final view = await ffi.withPointerCallback<ffi.TView>(
          (callback) => ffi.Engine_createViewJobThread(app.jobThreadHandle, app.engine, callback),
        );
        final original = List.filled(128, 'original view name Ω🚗').join();
        final bytes = utf8.encode(original);
        final input = original.toNativeUtf8();
        final replacement = 'replacement'.toNativeUtf8();
        final output = ffi.calloc<ffi.Uint8>(bytes.length + 1);
        try {
          await ffi.withVoidCallback(
            (id, callback) => ffi.View_setNameJobThread(app.jobThreadHandle, view, input.cast(), id, callback),
          );
          final name = ffi.withSizeCallback(
            (callback) =>
                ffi.View_getNameJobThread(app.jobThreadHandle, view, output.cast(), bytes.length + 1, callback),
          );
          final changed = ffi.withVoidCallback((id, callback) {
            if (destroy) {
              ffi.Engine_destroyViewJobThread(app.jobThreadHandle, app.engine, view, id, callback);
            } else {
              ffi.View_setNameJobThread(app.jobThreadHandle, view, replacement.cast(), id, callback);
            }
          });
          // Wait for the queued mutation before reading the caller-owned bytes.
          // The completion callback only returns a size, so its delivery order
          // cannot affect the lifetime of this buffer.
          await changed;
          expect(await name, bytes.length + 1);
          expect(utf8.decode(output.asTypedList(bytes.length)), original);
        } finally {
          if (!destroy)
            await ffi.withVoidCallback(
              (id, callback) => ffi.Engine_destroyViewJobThread(app.jobThreadHandle, app.engine, view, id, callback),
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
          ffi.View_getNameJobThread(app.jobThreadHandle, view.getNativeHandle(), output, capacity, callback);
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
          (id, callback) =>
              ffi.View_setNameJobThread(app.jobThreadHandle, view.getNativeHandle(), text.cast(), id, callback),
        );
        final read = view.getName();
        final destroyed = view.destroy();
        await expectLater(read, throwsFormatException);
        await destroyed;
      } finally {
        ffi.calloc.free(text);
      }
    });
  });
}
