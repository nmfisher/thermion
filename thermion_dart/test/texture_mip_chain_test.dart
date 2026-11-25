import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart' as ffi;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

import 'src/test_io.dart';

/// A solid opaque RGBA8 level of [width] x [height] texels.
TextureMipLevel _solidLevel(int width, int height, int r, int g, int b) {
  final data = Uint8List(width * height * 4);
  for (var i = 0; i < data.length; i += 4) {
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = 255;
  }
  return TextureMipLevel(
    data: data,
    width: width,
    height: height,
    format: PixelDataFormat.RGBA,
    type: PixelDataType.UBYTE,
  );
}

/// Reads the level-0 texels of [texture] back through a render target that
/// attaches it as the color buffer (the only level a render target can read).
Future<List<int>> _readLevel0(FFIFilamentApp app, RenderTarget target, int width, int height) async {
  final length = width * height * 4;
  final pixels = ffi.calloc<Uint8>(length);
  try {
    await withVoidCallback(
      (id, cb) => Renderer_readPixelsJobThread(
        app.jobThreadHandle,
        app.renderer,
        width,
        height,
        0,
        0,
        target.getNativeHandle(),
        PixelDataFormat.RGBA.value,
        PixelDataType.UBYTE.value,
        pixels,
        length,
        id,
        cb,
      ),
    );
    await withVoidCallback((id, cb) => Engine_flushAndWaitJobThread(app.jobThreadHandle, app.engine, id, cb));
    return pixels.asTypedList(length).toList();
  } finally {
    ffi.calloc.free(pixels);
  }
}

Future<void> _expectSolid(List<int> pixels, List<int> rgba) async {
  for (var i = 0; i < pixels.length; i += 4) {
    expect(pixels.sublist(i, i + 4), rgba, reason: 'texel ${i ~/ 4}');
  }
}

void main() {
  group('Texture.setMipChain', () {
    late FFIFilamentApp app;

    setUpAll(() async {
      await FFIFilamentApp.create(
        config: FFIFilamentConfig(backend: defaultTestBackend, loadResource: loadResourceBytes),
      );
      app = FilamentApp.instance! as FFIFilamentApp;
    });
    tearDownAll(() => app.destroy());

    Future<Texture> createTexture(int levels) => app.createTexture(
      8,
      8,
      levels: levels,
      textureFormat: TextureFormat.RGBA8,
      // BLIT_SRC is required by Renderer_readPixels on the render target.
      flags: {
        TextureUsage.TEXTURE_USAGE_UPLOADABLE,
        TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
      },
    );

    test('uploads every level and snapshots the pixels before returning', () async {
      // 8x8 with three levels: 8x8, 4x4 and 2x2. The upload validates every
      // entry against its level's real size, so a chain that fits proves the
      // levels exist (Texture_getWidth/Height ignore the level argument).
      final texture = await createTexture(3);
      expect(await texture.getLevels(), 3);
      expect(await texture.getWidth(), 8);
      expect(await texture.getHeight(), 8);
      final levels = [_solidLevel(8, 8, 255, 0, 0), _solidLevel(4, 4, 0, 255, 0), _solidLevel(2, 2, 0, 0, 255)];

      final upload = texture.setMipChain(levels);
      // The whole chain is copied inside the call, so overwriting the caller's
      // buffers immediately afterwards must not leak into the texture.
      for (final level in levels) {
        level.data.fillRange(0, level.data.lengthInBytes, 0);
      }
      await upload;

      final target = await app.createRenderTarget(8, 8, color: texture);
      final depth = await target.getDepthTexture();
      try {
        await _expectSolid(await _readLevel0(app, target, 8, 8), [255, 0, 0, 255]);
      } finally {
        await target.destroy();
        await depth.destroy();
        await texture.destroy();
      }
    });

    test('replaces a previously uploaded chain', () async {
      final texture = await createTexture(2);
      await texture.setMipChain([_solidLevel(8, 8, 0, 0, 0), _solidLevel(4, 4, 0, 0, 0)]);
      await texture.setMipChain([_solidLevel(8, 8, 255, 255, 0), _solidLevel(4, 4, 255, 255, 0)]);

      final target = await app.createRenderTarget(8, 8, color: texture);
      final depth = await target.getDepthTexture();
      try {
        await _expectSolid(await _readLevel0(app, target, 8, 8), [255, 255, 0, 255]);
      } finally {
        await target.destroy();
        await depth.destroy();
        await texture.destroy();
      }
    });

    test('leaves the texture unchanged and reports failure for an invalid chain', () async {
      final texture = await createTexture(2);
      await texture.setMipChain([_solidLevel(8, 8, 0, 255, 255), _solidLevel(4, 4, 0, 255, 255)]);

      // More levels than the texture has.
      await expectLater(
        texture.setMipChain([_solidLevel(8, 8, 0, 0, 0), _solidLevel(4, 4, 0, 0, 0), _solidLevel(2, 2, 0, 0, 0)]),
        throwsA(isA<Exception>()),
      );
      // Level 1 is 4x4, so an 8x8 region does not fit it. Level 0 of this
      // chain is valid, which proves the chain is validated before any upload.
      await expectLater(
        texture.setMipChain([_solidLevel(8, 8, 0, 0, 0), _solidLevel(8, 8, 0, 0, 0)]),
        throwsA(isA<Exception>()),
      );
      await expectLater(texture.setMipChain([]), throwsA(isA<ArgumentError>()));

      final target = await app.createRenderTarget(8, 8, color: texture);
      final depth = await target.getDepthTexture();
      try {
        await _expectSolid(await _readLevel0(app, target, 8, 8), [0, 255, 255, 255]);
      } finally {
        await target.destroy();
        await depth.destroy();
        await texture.destroy();
      }
    });

    test('rejects a short buffer in a later level without uploading any level', () async {
      final texture = await createTexture(3);
      await texture.setMipChain([
        _solidLevel(8, 8, 0, 255, 255),
        _solidLevel(4, 4, 0, 255, 255),
        _solidLevel(2, 2, 0, 255, 255),
      ]);

      // Levels 0 and 1 are valid; level 2 claims 2x2 RGBA8 (16 bytes) but its
      // buffer holds only 15. The whole chain must be rejected before the
      // first setImage, so level 0 keeps its previous pixels — a partial
      // upload would show red here (and Filament would read past the buffer).
      final shortLevel = TextureMipLevel(
        data: Uint8List(2 * 2 * 4 - 1),
        width: 2,
        height: 2,
        format: PixelDataFormat.RGBA,
        type: PixelDataType.UBYTE,
      );
      await expectLater(
        texture.setMipChain([_solidLevel(8, 8, 255, 0, 0), _solidLevel(4, 4, 255, 0, 0), shortLevel]),
        throwsA(isA<Exception>()),
      );

      final target = await app.createRenderTarget(8, 8, color: texture);
      final depth = await target.getDepthTexture();
      try {
        await _expectSolid(await _readLevel0(app, target, 8, 8), [0, 255, 255, 255]);
      } finally {
        await target.destroy();
        await depth.destroy();
        await texture.destroy();
      }
    });

    test('rejects a short buffer in level 0 without uploading any level', () async {
      final texture = await createTexture(2);
      await texture.setMipChain([_solidLevel(8, 8, 30, 60, 90), _solidLevel(4, 4, 30, 60, 90)]);

      await expectLater(
        texture.setMipChain([
          TextureMipLevel(
            data: Uint8List(8 * 8 * 4 - 1),
            width: 8,
            height: 8,
            format: PixelDataFormat.RGBA,
            type: PixelDataType.UBYTE,
          ),
          _solidLevel(4, 4, 255, 0, 0),
        ]),
        throwsA(isA<Exception>()),
      );

      final target = await app.createRenderTarget(8, 8, color: texture);
      final depth = await target.getDepthTexture();
      try {
        await _expectSolid(await _readLevel0(app, target, 8, 8), [30, 60, 90, 255]);
      } finally {
        await target.destroy();
        await depth.destroy();
        await texture.destroy();
      }
    });

    test('single-level setImage still uploads', () async {
      final texture = await createTexture(1);
      await texture.setImage(0, _solidLevel(8, 8, 0, 255, 0).data, 8, 8, PixelDataFormat.RGBA, PixelDataType.UBYTE);

      final target = await app.createRenderTarget(8, 8, color: texture);
      final depth = await target.getDepthTexture();
      try {
        await _expectSolid(await _readLevel0(app, target, 8, 8), [0, 255, 0, 255]);
      } finally {
        await target.destroy();
        await depth.destroy();
        await texture.destroy();
      }
    });
  });
}
