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
    'texture upload snapshot',
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

      test('texture upload keeps its snapshot through GPU completion', () async {
        final texture = await app.createTexture(
          1,
          1,
          textureFormat: TextureFormat.RGBA8,
          flags: {
            TextureUsage.TEXTURE_USAGE_UPLOADABLE,
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          },
        );
        final bytes = Uint8List.fromList([17, 43, 91, 255]);
        reset();
        ffi.RenderThread_addTask(wait);
        late Future<void> upload;
        try {
          upload = texture.setImage(0, bytes, 1, 1, PixelDataFormat.RGBA, PixelDataType.UBYTE);
          bytes.fillRange(0, bytes.length, 0);
        } finally {
          release();
        }
        await upload.timeout(const Duration(seconds: 5));
        final target = await app.createRenderTarget(1, 1, color: texture);
        final depth = await target.getDepthTexture();
        try {
          // Test-owned native memory stays valid through flushAndWait. This lets
          // the upload test run independently of the pixel-readback API fix.
          final pixels = ffi.calloc<Uint8>(4);
          try {
            await withVoidCallback((id, cb) {
              Renderer_readPixelsRenderThread(
                app.renderer,
                1,
                1,
                0,
                0,
                target.getNativeHandle(),
                PixelDataFormat.RGBA.value,
                PixelDataType.UBYTE.value,
                pixels,
                4,
                id,
                cb,
              );
            });
            await withVoidCallback((id, cb) => Engine_flushAndWaitRenderThread(app.engine, id, cb));
            expect(pixels.asTypedList(4), [17, 43, 91, 255]);
          } finally {
            ffi.calloc.free(pixels);
          }
        } finally {
          await target.destroy();
          await depth.destroy();
          await texture.destroy();
        }
      });
    },
    skip: fixturePath == null ? 'Set THERMION_UPLOAD_LIFETIME_FIXTURE to the native fixture library' : false,
  );
}
