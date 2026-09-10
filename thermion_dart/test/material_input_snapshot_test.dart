import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart' as ffi;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

// Build native/test/rendering's upload_lifetime_fixture and set its path in
// THERMION_UPLOAD_LIFETIME_FIXTURE. No production-only test hooks are needed.
void main() {
  final fixturePath = Platform.environment['THERMION_UPLOAD_LIFETIME_FIXTURE'];
  group(
    'material input snapshot',
    () {
      late FFIFilamentApp app;
      late void Function() reset;
      late void Function() release;
      late Pointer<ffi.NativeFunction<ffi.Void Function()>> wait;

      setUpAll(() async {
        final fixture = DynamicLibrary.open(fixturePath!);
        reset = fixture.lookupFunction<ffi.Void Function(), void Function()>('resetTaskRelease');
        release = fixture.lookupFunction<ffi.Void Function(), void Function()>('allowTaskToFinish');
        wait = fixture.lookup('waitForTaskRelease');
        await FFIFilamentApp.create(
          config: FFIFilamentConfig(
            backend: Platform.isMacOS ? Backend.METAL : Backend.DEFAULT,
            loadResource: (uri) => File(uri).readAsBytes(),
          ),
        );
        app = FilamentApp.instance! as FFIFilamentApp;
      });
      tearDownAll(() => app.destroy());

      test('material package survives source overwrite while the worker is blocked', () async {
        final bytes = await File('../examples/assets/solidcolor.filamat').readAsBytes();
        reset();
        ffi.RenderThread_addTask(wait);
        late Future<Material> pending;
        try {
          pending = app.createMaterial(bytes);
          bytes.fillRange(0, bytes.length, 0xa5);
          // Force other Dart allocations while the native task still cannot read.
          for (var i = 0; i < 100; i++) {
            expect(Uint8List(8192).length, 8192);
          }
        } finally {
          release();
        }
        final material = await pending.timeout(const Duration(seconds: 5));
        await material.destroy();
      });
    },
    skip: fixturePath == null ? 'Set THERMION_UPLOAD_LIFETIME_FIXTURE to the native fixture library' : false,
  );
}
