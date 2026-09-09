import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';

// Tests the boundary between native upload release and #318's native
// exception delivery. Requires a working GPU backend, like the upload suite.
void main() {
  test(
    'Filament texture failure reports creation error and releases unused data',
    () async {
      await FFIFilamentApp.create(
        config: FFIFilamentConfig(backend: Platform.isMacOS ? Backend.METAL : Backend.DEFAULT),
      );
      final app = FilamentApp.instance! as FFIFilamentApp;
      try {
        final data = await File('../examples/assets/default_env_skybox.ktx').readAsBytes();
        // The KTX1 header's pixelWidth is at offset 36. Keep the existing mip
        // payload intact and exercise texture dimension rejection. Both Filament
        // and Thermion's KTX preflight reject this before pixel submission.
        data.buffer.asByteData(data.offsetInBytes, data.length).setUint32(36, 0, Endian.little);
        final bundle = await FFIKtx1Bundle.create(app, data);
        late Future<Texture> textureCreated;
        final uploadReleased = withVoidCallback((id, callback) {
          textureCreated = bundle.createTexture(onTextureUploadComplete: callback, textureUploadCompleteRequestId: id);
        });
        try {
          await expectLater(
            textureCreated.timeout(const Duration(seconds: 5)),
            throwsA(isA<StateError>().having((error) => error.message, 'message', contains('dimensions'))),
          );
        } finally {
          await uploadReleased.timeout(const Duration(seconds: 5));
          await bundle.destroy();
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
