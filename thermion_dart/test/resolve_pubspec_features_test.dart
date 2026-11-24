import 'package:test/test.dart';
import 'package:thermion_dart/src/hooks/resolve_pubspec_features.dart';
import 'package:thermion_dart/src/hooks/material_tools.dart' show MaterialToolsError;

void main() {
  final allOn = (gltf: true, ktx: true, imageDecoding: true);

  test('absent features map -> every feature enabled, no warning', () {
    final warnings = <String>[];
    expect(resolveFeatures(null, onWarning: warnings.add), allOn);
    expect(resolveFeatures({}, onWarning: warnings.add), allOn);
    expect(disabledFeatureDefines(allOn), isEmpty);
    expect(anyFeatureDisabled(allOn), isFalse);
    expect(warnings, isEmpty);
  });

  test('each feature is independently switchable once gltf is off', () {
    final warnings = <String>[];
    final r = resolveFeatures({'gltf': false}, onWarning: warnings.add);
    expect(r, (gltf: false, ktx: true, imageDecoding: true));
    expect(disabledFeatureDefines(r), {'THERMION_ENABLE_GLTF': '0'});
    expect(anyFeatureDisabled(r), isTrue);

    expect(resolveFeatures({'gltf': false, 'ktx': false}, onWarning: warnings.add), (
      gltf: false,
      ktx: false,
      imageDecoding: true,
    ));
    expect(resolveFeatures({'gltf': false, 'image_decoding': false}, onWarning: warnings.add), (
      gltf: false,
      ktx: true,
      imageDecoding: false,
    ));
    final allOff = resolveFeatures({'gltf': false, 'ktx': false, 'image_decoding': false}, onWarning: warnings.add);
    expect(allOff, (gltf: false, ktx: false, imageDecoding: false));
    // Key order of the define map follows featureKeys, not pubspec order.
    expect(disabledFeatureDefines(allOff).keys, [
      'THERMION_ENABLE_GLTF',
      'THERMION_ENABLE_KTX',
      'THERMION_ENABLE_IMAGE_DECODING',
    ]);
    expect(disabledFeatureDefines(allOff).values, everyElement('0'));
    expect(warnings, isEmpty);
  });

  test('explicit true keeps a feature and passes no define', () {
    final r = resolveFeatures({'gltf': true, 'ktx': true, 'image_decoding': true}, onWarning: (_) {});
    expect(r, allOn);
    expect(disabledFeatureDefines(r), isEmpty);
  });

  test('unknown keys warn (forward compatibility) and are ignored', () {
    final warnings = <String>[];
    final r = resolveFeatures({'gltf': false, 'draco': false, 'basis_transcoder': true}, onWarning: warnings.add);
    expect(r, (gltf: false, ktx: true, imageDecoding: true));
    expect(warnings, hasLength(2));
    expect(warnings[0], contains('features.draco'));
    expect(warnings[1], contains('features.basis_transcoder'));
  });

  test('non-map features value is a hard error', () {
    for (final raw in [
      false,
      'gltf',
      1,
      ['gltf'],
    ]) {
      expect(
        () => resolveFeatures(raw, onWarning: (_) {}),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('features must be a map'))),
        reason: 'raw=$raw',
      );
    }
  });

  test('non-boolean values are a hard error naming the key', () {
    // Silently ignoring `gltf: "false"` would ship a ~4 MB fatter binary than
    // the user asked for, so unlike runtime_materials this never warns-and-
    // continues.
    for (final raw in [
      {'gltf': 'false'},
      {'ktx': 'true'},
      {'image_decoding': 0},
      {'gltf': 1},
      {'ktx': null},
    ]) {
      final key = (raw as Map).keys.single;
      expect(
        () => resolveFeatures(raw, onWarning: (_) {}),
        throwsA(
          isA<MaterialToolsError>().having(
            (e) => e.message,
            'message',
            allOf(contains('features.$key must be true or false'), contains('unquoted YAML boolean')),
          ),
        ),
        reason: 'raw=$raw',
      );
    }
  });

  group('gltf with a disabled decoder is rejected', () {
    test('gltf: true + ktx: false', () {
      expect(
        () => resolveFeatures({'gltf': true, 'ktx': false}, onWarning: (_) {}),
        throwsA(
          isA<MaterialToolsError>().having(
            (e) => e.message,
            'message',
            allOf(contains('features.gltf'), contains('features.ktx: false')),
          ),
        ),
      );
    });

    test('gltf: true + image_decoding: false', () {
      expect(
        () => resolveFeatures({'gltf': true, 'image_decoding': false}, onWarning: (_) {}),
        throwsA(
          isA<MaterialToolsError>().having((e) => e.message, 'message', contains('features.image_decoding: false')),
        ),
      );
    });

    test('gltf absent (default on) + a decoder off is rejected too', () {
      expect(() => resolveFeatures({'ktx': false}, onWarning: (_) {}), throwsA(isA<MaterialToolsError>()));
    });

    test('both decoders off names both keys', () {
      expect(
        () => resolveFeatures({'ktx': false, 'image_decoding': false}, onWarning: (_) {}),
        throwsA(
          isA<MaterialToolsError>().having(
            (e) => e.message,
            'message',
            allOf(contains('features.ktx: false'), contains('features.image_decoding: false')),
          ),
        ),
      );
    });

    test('the rule is skipped once gltf is explicitly disabled', () {
      expect(resolveFeatures({'gltf': false, 'ktx': false, 'image_decoding': false}, onWarning: (_) {}), (
        gltf: false,
        ktx: false,
        imageDecoding: false,
      ));
    });
  });
}
