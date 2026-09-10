import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

import 'src/test_io.dart';

int readPackageVersion(Uint8List bytes) {
  try {
    return Material_getPackageVersion(bytes.address, bytes.length).toInt();
  } finally {
    if (FILAMENT_WASM) bytes.free();
  }
}

void main() {
  late Uint8List validPackage;
  late Uint8List versionChunk;

  setUpAll(() async {
    await initTestBindings();
    validPackage = await loadResourceBytes('../examples/assets/solidcolor.filamat');
    // The committed fixture starts with MAT_VERS, stored as a little-endian
    // uint64 chunk tag, a uint32 payload length, then the uint32 version.
    expect(validPackage.sublist(0, 8), 'SREV_TAM'.codeUnits);
    expect(ByteData.sublistView(validPackage).getUint32(8, Endian.little), 4);
    versionChunk = Uint8List.fromList(validPackage.sublist(0, 16));
  });

  Uint8List withVersion(int version) {
    final bytes = Uint8List.fromList(validPackage);
    ByteData.sublistView(bytes).setUint32(12, version, Endian.little);
    return bytes;
  }

  Map<String, Uint8List> malformedPackages() {
    final oversized = Uint8List.fromList(versionChunk);
    ByteData.sublistView(oversized).setUint32(8, 0xffffffff, Endian.little);
    final shortVersion = Uint8List.fromList(versionChunk.sublist(0, 15));
    ByteData.sublistView(shortVersion).setUint32(8, 3, Endian.little);
    final longVersion = Uint8List.fromList([...versionChunk, 0]);
    ByteData.sublistView(longVersion).setUint32(8, 5, Endian.little);
    return {
      'empty': Uint8List(0),
      'truncated header': Uint8List.fromList(versionChunk.sublist(0, 11)),
      'truncated payload': Uint8List.fromList(versionChunk.sublist(0, 15)),
      'oversized chunk': oversized,
      'short version': shortVersion,
      'long version': longVersion,
      'missing version': Uint8List.fromList(validPackage.sublist(16)),
      'duplicate version': Uint8List.fromList([...validPackage, ...versionChunk]),
      'trailing partial header': Uint8List.fromList([...validPackage, 0]),
    };
  }

  group('material package metadata', () {
    test('native version matches a package built with the bundled compiler', () {
      final fixtureVersion = ByteData.sublistView(validPackage).getUint32(12, Endian.little);
      expect(Material_getSupportedVersion(), fixtureVersion);
      expect(readPackageVersion(validPackage), fixtureVersion);
    });

    test('finds version after another chunk at an unaligned offset', () {
      // A well-formed unknown chunk with a one-byte payload, then MAT_VERS.
      final prefix = Uint8List(13);
      prefix.setRange(0, 8, 'UNKNOWN '.codeUnits.reversed);
      ByteData.sublistView(prefix).setUint32(8, 1, Endian.little);
      expect(readPackageVersion(Uint8List.fromList([...prefix, ...versionChunk])), Material_getSupportedVersion());
    });

    test('distinguishes all uint32 versions from the malformed sentinel', () {
      for (final version in [0, 69, 0x80000000, 0xffffffff]) {
        expect(readPackageVersion(withVersion(version)), version);
      }
      expect(Material_getPackageVersion(nullptr, 0).toInt(), -1);
    });

    test('rejects malformed chunk layouts and ambiguous version metadata', () {
      for (final entry in malformedPackages().entries) {
        expect(readPackageVersion(entry.value), -1, reason: entry.key);
      }
    });
  });

  group('material creation', () {
    late FFIFilamentApp app;
    setUpAll(() async {
      await FFIFilamentApp.create(
        config: FFIFilamentConfig(backend: defaultTestBackend, loadResource: loadResourceBytes),
      );
      app = FilamentApp.instance! as FFIFilamentApp;
    });
    tearDownAll(() => app.destroy());

    test('reports stale and future formats through the public Dart Future', () async {
      expect(app.materialVersion, Material_getSupportedVersion());
      for (final version in [69, 0xffffffff]) {
        await expectLater(
          app.createMaterial(withVersion(version)).timeout(const Duration(seconds: 5)),
          throwsA(
            isA<FormatException>()
                .having((e) => e.message, 'actual version', contains('$version'))
                .having((e) => e.message, 'expected version', contains('${app.materialVersion}'))
                .having(
                  (e) => e.message,
                  'matching compiler',
                  contains('Recompile using matc from the same Filament release'),
                ),
          ),
        );
      }
      // Rejection must leave the engine usable, with no pending completion.
      final material = await app.createMaterial(validPackage).timeout(const Duration(seconds: 5));
      await material.destroy();
    });

    test('rejects malformed packages through the public Dart Future', () async {
      for (final entry in malformedPackages().entries) {
        await expectLater(
          app.createMaterial(entry.value).timeout(const Duration(seconds: 5)),
          throwsFormatException,
          reason: entry.key,
        );
      }
    });

    test('native render-thread path completes with null for rejected packages', () async {
      for (final bytes in [withVersion(69), ...malformedPackages().values.where((bytes) => bytes.isNotEmpty)]) {
        try {
          final material = await withPointerCallback<TMaterial>((callback) {
            Engine_buildMaterialRenderThread(app.engine, bytes.address, bytes.length, callback);
          }).timeout(const Duration(seconds: 5));
          expect(material, nullptr);
        } finally {
          if (FILAMENT_WASM) bytes.free();
        }
      }
      final material = await app.createMaterial(validPackage).timeout(const Duration(seconds: 5));
      await material.destroy();
    });

    test('builds the checked snapshot even if the caller reuses its data', () async {
      final bytes = Uint8List.fromList(validPackage);
      final created = app.createMaterial(bytes);
      bytes.fillRange(0, bytes.length, 0);
      final material = await created.timeout(const Duration(seconds: 5));
      expect(bytes.every((byte) => byte == 0), isTrue);
      await material.destroy();
    });
  });
}
