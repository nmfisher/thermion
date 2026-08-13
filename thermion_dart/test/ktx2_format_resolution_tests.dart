// S3-2 verification: the KTX2 albedo lane must actually load.
//
// Re-runs the AoA "M2" measurement against the same producer blobs, but inside
// thermion's own harness so the result is a property of the loader rather than
// of any consumer.
//
// Before this change, an sRGB-tagged UASTC albedo resolved to NO supported
// internal format on desktop and `loadKtx2` returned null: thermion's requested
// format ladder had no sRGB ASTC and no BC/DXT family at all, and the LINEAR
// retry was rejected by Ktx2Reader because the blob's DFD is binding.
//
// Fixture (override with KTX2_FIXTURE_DIR):
//   <producer>/Ktx2Sample/layers/00_ktx2_sample/{albedo,normal,depth}.ktx2
//     albedo — UASTC + zstd, DFD transfer function = sRGB,   11 mip levels
//     normal — UASTC + zstd, DFD transfer function = linear, 11 mip levels
//     depth  — uncompressed r16_unorm + zstd (NOT BasisU; unsupported by design)
//
// Backend (override with THERMION_BACKEND=gl|vulkan): the format ladder is
// resolved against real driver capabilities, so the backend is part of the
// result and every reported format is only claimed for the backend named in the
// output.
@Timeout(Duration(seconds: 120))
library;

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';
import 'src/ktx2_staging_debug.dart';

const _defaultFixtureDir =
    r'D:\UE to Table\.test_capture_interactive\ktx2_sample\Ktx2Sample\layers\00_ktx2_sample';

Backend _backendFromEnv() {
  switch (testEnvironment('THERMION_BACKEND')?.toLowerCase()) {
    case 'gl':
    case 'opengl':
      return Backend.OPENGL;
    case 'vulkan':
    case 'vk':
      return Backend.VULKAN;
    default:
      return defaultTestBackend;
  }
}

String get _fixtureDir =>
    isWeb ? '.' : testEnvironment('KTX2_FIXTURE_DIR') ?? _defaultFixtureDir;

String _fixturePath(String name) => isWeb ? name : '$_fixtureDir/$name';

void _report(String label, Ktx2LoadResult result) {
  print(
    '[S3-2] $label :: loaded=${result.isLoaded} '
    'sourceTransfer=${result.sourceTransfer.name} '
    'resolvedFormat=${result.resolvedFormat?.name} '
    'hardwareSrgbDecode=${result.hardwareSrgbDecode} '
    'alphaMode=${result.alphaMode.name} '
    'sourceChannelCount=${result.sourceChannelCount} '
    'uploadedMipCount=${result.uploadedMipCount} '
    'sourceMipCount=${result.sourceMipCount}',
  );
}

/// Internal formats that carry fewer than three channels.
///
/// A source with three or more channels must never resolve to one of these:
/// the transcode would silently discard the channels that do not fit. thermion's
/// original flat linear ladder put [TextureFormat.EAC_R11] second, so a
/// 3-channel linear normal map resolved to a ONE-channel format on any backend
/// advertising EAC but not ASTC — which desktop GL does.
const _channelLosingFormats = <TextureFormat>{
  TextureFormat.EAC_R11,
  TextureFormat.EAC_R11_SIGNED,
  TextureFormat.EAC_RG11,
  TextureFormat.EAC_RG11_SIGNED,
  TextureFormat.RED_RGTC1,
  TextureFormat.SIGNED_RED_RGTC1,
  TextureFormat.RED_GREEN_RGTC2,
  TextureFormat.SIGNED_RED_GREEN_RGTC2,
};

void main() async {
  final backend = _backendFromEnv();
  final testHelper = TestHelper('ktx2_format_resolution');
  await testHelper.setup(backend: backend, logLevel: Level.INFO);

  print('[S3-2] backend=${backend.name} fixtureDir=$_fixtureDir');

  Future<Ktx2LoadResult> load(
    String name, {
    int maxMipLevels = 1,
    Ktx2TransferFunction? expectTransfer,
  }) async {
    final path = _fixturePath(name);
    final data = await loadResourceBytes(path);
    late Ktx2LoadResult result;
    await ViewerBuilder(testHelper).execute((_) async {
      result = await FilamentApp.instance!.loadKtx2WithResult(
        data,
        maxMipLevels: maxMipLevels,
        expectTransfer: expectTransfer,
      );
    });
    _report('$name (maxMipLevels=$maxMipLevels)', result);
    return result;
  }

  test(
    'TextureFormat.isCompressed uses the explicit compressed allow-list',
    () {
      const expectedCompressed = <TextureFormat>{
        TextureFormat.EAC_R11,
        TextureFormat.EAC_R11_SIGNED,
        TextureFormat.EAC_RG11,
        TextureFormat.EAC_RG11_SIGNED,
        TextureFormat.ETC2_RGB8,
        TextureFormat.ETC2_SRGB8,
        TextureFormat.ETC2_RGB8_A1,
        TextureFormat.ETC2_SRGB8_A1,
        TextureFormat.ETC2_EAC_RGBA8,
        TextureFormat.ETC2_EAC_SRGBA8,
        TextureFormat.DXT1_RGB,
        TextureFormat.DXT1_RGBA,
        TextureFormat.DXT3_RGBA,
        TextureFormat.DXT5_RGBA,
        TextureFormat.DXT1_SRGB,
        TextureFormat.DXT1_SRGBA,
        TextureFormat.DXT3_SRGBA,
        TextureFormat.DXT5_SRGBA,
        TextureFormat.RGBA_ASTC_4x4,
        TextureFormat.RGBA_ASTC_5x4,
        TextureFormat.RGBA_ASTC_5x5,
        TextureFormat.RGBA_ASTC_6x5,
        TextureFormat.RGBA_ASTC_6x6,
        TextureFormat.RGBA_ASTC_8x5,
        TextureFormat.RGBA_ASTC_8x6,
        TextureFormat.RGBA_ASTC_8x8,
        TextureFormat.RGBA_ASTC_10x5,
        TextureFormat.RGBA_ASTC_10x6,
        TextureFormat.RGBA_ASTC_10x8,
        TextureFormat.RGBA_ASTC_10x10,
        TextureFormat.RGBA_ASTC_12x10,
        TextureFormat.RGBA_ASTC_12x12,
        TextureFormat.SRGB8_ALPHA8_ASTC_4x4,
        TextureFormat.SRGB8_ALPHA8_ASTC_5x4,
        TextureFormat.SRGB8_ALPHA8_ASTC_5x5,
        TextureFormat.SRGB8_ALPHA8_ASTC_6x5,
        TextureFormat.SRGB8_ALPHA8_ASTC_6x6,
        TextureFormat.SRGB8_ALPHA8_ASTC_8x5,
        TextureFormat.SRGB8_ALPHA8_ASTC_8x6,
        TextureFormat.SRGB8_ALPHA8_ASTC_8x8,
        TextureFormat.SRGB8_ALPHA8_ASTC_10x5,
        TextureFormat.SRGB8_ALPHA8_ASTC_10x6,
        TextureFormat.SRGB8_ALPHA8_ASTC_10x8,
        TextureFormat.SRGB8_ALPHA8_ASTC_10x10,
        TextureFormat.SRGB8_ALPHA8_ASTC_12x10,
        TextureFormat.SRGB8_ALPHA8_ASTC_12x12,
        TextureFormat.RED_RGTC1,
        TextureFormat.SIGNED_RED_RGTC1,
        TextureFormat.RED_GREEN_RGTC2,
        TextureFormat.SIGNED_RED_GREEN_RGTC2,
        TextureFormat.RGB_BPTC_SIGNED_FLOAT,
        TextureFormat.RGB_BPTC_UNSIGNED_FLOAT,
        TextureFormat.RGBA_BPTC_UNORM,
        TextureFormat.SRGB_ALPHA_BPTC_UNORM,
      };

      expect(
        TextureFormat.values.where((format) => format.isCompressed).toSet(),
        expectedCompressed,
      );
      expect(TextureFormat.RGBA8.isCompressed, isFalse);
      expect(TextureFormat.SRGB8_A8.isCompressed, isFalse);
    },
  );

  test(
    'albedo.ktx2 (sRGB UASTC) loads and resolves to an sRGB format',
    () async {
      final result = await load(
        'albedo.ktx2',
        expectTransfer: Ktx2TransferFunction.srgb,
      );

      // The headline: this returned null before the patch.
      expect(result.isLoaded, isTrue, reason: 'albedo.ktx2 must load');

      // The transfer function must come from the DFD, not from a guess.
      expect(result.sourceTransfer, Ktx2TransferFunction.srgb);

      // requestFormat() == SUCCESS proves only that Filament knows the target.
      // Assert on what was actually resolved, otherwise a silent SRGB8_A8
      // fallback is indistinguishable from the BC7 we asked for.
      expect(result.resolvedFormat, isNotNull);
      expect(result.resolvedFormat!.isCompressed, isTrue);
      expect(
        result.hardwareSrgbDecode,
        isTrue,
        reason:
            'an sRGB-tagged blob must resolve to an sRGB internal format, '
            'otherwise the sampler hands the shader display-encoded values',
      );

      // Base level only: the producer emits an 11-level chain and the consumer's
      // NEAREST sampler never minifies, so the rest is dead payload.
      expect(result.sourceMipCount, greaterThan(1));
      expect(result.uploadedMipCount, 1);

      final texture = result.texture!;
      expect(await texture.getWidth(), 1280);
      expect(await texture.getHeight(), 1280);
    },
  );

  test('albedo.ktx2 uploads the full chain when maxMipLevels is 0', () async {
    final result = await load('albedo.ktx2', maxMipLevels: 0);
    expect(result.isLoaded, isTrue);
    expect(result.uploadedMipCount, result.sourceMipCount);
    expect(result.uploadedMipCount, greaterThan(1));
  });

  test('normal.ktx2 (linear UASTC) loads without losing channels', () async {
    final result = await load(
      'normal.ktx2',
      expectTransfer: Ktx2TransferFunction.linear,
    );
    expect(result.isLoaded, isTrue, reason: 'normal.ktx2 must not regress');
    expect(result.sourceTransfer, Ktx2TransferFunction.linear);
    expect(result.hardwareSrgbDecode, isFalse);
    expect(result.resolvedFormat, isNotNull);
    expect(result.resolvedFormat!.isCompressed, isTrue);

    // The blob's DFD declares UASTC channel id 0 (RGB).
    expect(result.sourceChannelCount, 3);

    // The defect this guards: before the linear ladder was gated on channel
    // count, this resolved to EAC_R11 on desktop GL and threw away G and B.
    expect(
      _channelLosingFormats.contains(result.resolvedFormat),
      isFalse,
      reason:
          'a ${result.sourceChannelCount}-channel source resolved to '
          '${result.resolvedFormat?.name}, which cannot represent all of its '
          'channels',
    );
  });

  test('depth.ktx2 (uncompressed r16) still fails, as designed', () async {
    // Not a regression: BasisU only handles UASTC/ETC1S payloads, and this blob
    // is an uncompressed r16_unorm. Recorded so the expectation stays explicit.
    final result = await load('depth.ktx2');
    expect(result.isLoaded, isFalse);
    expect(result.texture, isNull);
  });

  test(
    'web wrapper releases staged inputs across success and unsupported loads',
    () async {
      final baseline = debugKtx2StagedInputBytes;

      for (var iteration = 0; iteration < 8; iteration++) {
        final albedo = await load('albedo.ktx2');
        expect(albedo.isLoaded, isTrue);
        expect(albedo.resolvedFormat?.isCompressed, isTrue);
        expect(debugKtx2StagedInputBytes, baseline);
        await albedo.texture!.destroy();

        final normal = await load('normal.ktx2');
        expect(normal.isLoaded, isTrue);
        expect(normal.resolvedFormat?.isCompressed, isTrue);
        expect(debugKtx2StagedInputBytes, baseline);
        await normal.texture!.destroy();

        final unsupported = await load('depth.ktx2');
        expect(unsupported.isLoaded, isFalse);
        expect(unsupported.texture, isNull);
        expect(debugKtx2StagedInputBytes, baseline);
      }
    },
    skip: isWeb ? false : 'WASM staging ownership applies only in browsers',
  );
}
