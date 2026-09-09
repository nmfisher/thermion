import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

void main() {
  test(
    'Filament texture creation failure reaches Dart and the worker recovers',
    () async {
      await FFIFilamentApp.create(
        config: FFIFilamentConfig(backend: Platform.isMacOS ? Backend.METAL : Backend.DEFAULT),
      );
      final app = FilamentApp.instance! as FFIFilamentApp;
      try {
        // Exercise Filament's existing builder check through the production
        // Texture_buildRenderThread path. No KTX data or upload is involved.
        await expectLater(
          app.createTexture(0, 1).timeout(const Duration(seconds: 5)),
          throwsA(isA<StateError>().having((error) => error.message, 'message', contains('invalid dimensions'))),
        );
        final texture = await app.createTexture(1, 1).timeout(const Duration(seconds: 5));
        try {
          expect(await texture.getWidth(), 1);
        } finally {
          await texture.destroy();
        }
      } finally {
        await app.destroy();
      }
    },
    skip: Platform.environment['THERMION_TASK_ERROR_FIXTURE'] == null
        ? 'Set THERMION_TASK_ERROR_FIXTURE; see native/test/rendering/README.md'
        : false,
  );
}
