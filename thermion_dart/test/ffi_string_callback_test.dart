@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart' as ffi;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';

void main() {
  test('null string callback returns null', () async {
    final result = await ffi.withStringCallback((callback) {
      callback.asFunction<void Function(ffi.Pointer<ffi.Char>)>()(ffi.nullptr);
    });
    expect(result, isNull);
  });

  test('string dispatch failure reaches the returned Future', () async {
    final error = StateError('string dispatch failed');
    await expectLater(ffi.withStringCallback((_) => throw error), throwsA(same(error)));
  });

  final fixturePath = Platform.environment['THERMION_STRING_CALLBACK_FIXTURE'];
  group(
    'owned view-name callbacks',
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
        test('name survives ${destroy ? 'destruction' : 'rename'} before Dart delivery', () async {
          final view = await app.createView() as FFIView;
          final original = List.filled(128, 'original view name Ω🚗').join();
          await view.setName(original);
          reset();
          final pendingName = view.getName();
          final changed = destroy ? app.destroyView(view) : view.setName('replacement');
          try {
            ffi.JobThread_addTask(completed);
            // Do not await before this barrier. Both queued operations must
            // finish while Dart is unable to receive the name callback.
            expect(wait(), isTrue, reason: 'The native job queue did not reach the barrier');
            expect(await pendingName, original);
          } finally {
            await changed;
            if (!destroy) await app.destroyView(view);
          }
        });
      }

      test('invalid UTF-8 reaches the returned Future', () async {
        final view = await app.createView() as FFIView;
        final text = ffi.calloc<ffi.Uint8>(2);
        text[0] = 0xff;
        try {
          await ffi.withVoidCallback((id, callback) {
            ffi.View_setNameJobThread(view.getNativeHandle(), text.cast(), id, callback);
          });
          await expectLater(view.getName(), throwsFormatException);
        } finally {
          ffi.calloc.free(text);
          await app.destroyView(view);
        }
      });
    },
    skip: fixturePath == null ? 'Set THERMION_STRING_CALLBACK_FIXTURE; see native/test/rendering/README.md' : false,
  );
}
