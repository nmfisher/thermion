import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';

void main() {
  group(
    'KTX input validation',
    () {
      late FFIFilamentApp app;
      late Uint8List source;
      setUpAll(() async {
        source = await File('../examples/assets/default_env_skybox.ktx').readAsBytes();
        await FFIFilamentApp.create(
          config: FFIFilamentConfig(backend: Platform.isMacOS ? Backend.METAL : Backend.DEFAULT),
        );
        app = FilamentApp.instance! as FFIFilamentApp;
      });
      tearDownAll(() async => app.destroy());

      test('truncated header reports a Dart decode error', () async {
        await expectLater(
          FFIKtx1Bundle.create(app, Uint8List(12)),
          throwsA(
            isA<Exception>().having((error) => error.toString(), 'message', contains('Failed to decode KTX texture')),
          ),
        );
        // A rejected input must not prevent the next bundle from being decoded.
        final bundle = await FFIKtx1Bundle.create(app, source);
        await bundle.destroy();
      });

      for (final field in {'width': 36, 'height': 40}.entries) {
        test('zero ${field.key} releases data and reports the preflight error', () async {
          final data = Uint8List.fromList(source);
          data.buffer.asByteData().setUint32(field.value, 0, Endian.little);
          final bundle = await FFIKtx1Bundle.create(app, data);
          late Future<Texture> created;
          final released = withVoidCallback((id, callback) {
            created = bundle.createTexture(onTextureUploadComplete: callback, textureUploadCompleteRequestId: id);
          });
          try {
            await expectLater(
              created.timeout(const Duration(seconds: 5)),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  'Invalid KTX texture dimensions or mip count',
                ),
              ),
            );
          } finally {
            await released.timeout(const Duration(seconds: 5));
            await bundle.destroy();
          }
        });
      }
    },
    skip: Platform.environment['THERMION_TASK_ERROR_FIXTURE'] == null
        ? 'Set THERMION_TASK_ERROR_FIXTURE; see native/test/rendering/README.md'
        : false,
  );
}
