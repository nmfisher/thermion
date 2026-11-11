import 'dart:convert';

import 'package:test/test.dart';
import 'package:thermion_dart/src/hooks/filament_artifacts.dart';

// A valid 64-char digest reused across tests.
const shaA =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const shaB =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

void main() {
  group('parseFilamentPin', () {
    test('null/empty → empty pin, no warnings', () {
      for (final raw in [null, '', '  \n']) {
        final warnings = <String>[];
        expect(parseFilamentPin(raw, warnings: warnings), isEmpty);
        expect(warnings, isEmpty);
      }
    });

    test('valid entries parsed; digests lowercased', () {
      final warnings = <String>[];
      final pin = parseFilamentPin(
        '{"macos/release": "${shaA.toUpperCase()}", "web/debug": "$shaB"}',
        warnings: warnings,
      );
      expect(pin, {'macos/release': shaA, 'web/debug': shaB});
      expect(warnings, isEmpty);
    });

    test('all platform slugs accepted', () {
      final entries = {
        for (final p in filamentPlatforms) '$p/release': shaA,
      };
      final warnings = <String>[];
      final pin = parseFilamentPin(jsonEncode(entries), warnings: warnings);
      expect(pin.length, filamentPlatforms.length);
      expect(warnings, isEmpty);
    });

    test('malformed JSON → empty pin + warning (legacy fallback)', () {
      final warnings = <String>[];
      expect(parseFilamentPin('{oops', warnings: warnings), isEmpty);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('not valid JSON'));
    });

    test('non-object JSON → empty pin + warning', () {
      for (final raw in ['[]', '"str"', '42']) {
        final warnings = <String>[];
        expect(parseFilamentPin(raw, warnings: warnings), isEmpty);
        expect(warnings, hasLength(1));
      }
    });

    test('bad entries dropped individually, good ones kept', () {
      final warnings = <String>[];
      final pin = parseFilamentPin(
        jsonEncode({
          'macos/release': shaA, // good
          'macos/profile': shaA, // bad variant
          ' amiga/release': shaA, // unknown platform
          'web/release': 'deadbeef', // short digest
          'ios/debug': '${shaA}0', // 65 chars
          'android/release': 'g' * 64, // non-hex
          'windows/debug': 12345, // non-string
          'linux': shaA, // missing variant
        }),
        warnings: warnings,
      );
      expect(pin, {'macos/release': shaA});
      expect(warnings, hasLength(7));
    });
  });

  group('resolveFilamentArtifact', () {
    test('unpinned → legacy URL, no digest, no cache suffix', () {
      final r = resolveFilamentArtifact('v1.77.2', 'macos', 'release', {});
      expect(r.zipName, 'filament-v1.77.2-macos-release.zip');
      expect(r.url,
          'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-v1.77.2-macos-release.zip');
      expect(r.sha256, isNull);
      expect(r.cacheSuffix, '');
      expect(r.warnings, isEmpty);
    });

    test('pinned → hash-suffixed URL + full digest + cache suffix', () {
      final r = resolveFilamentArtifact(
          'v1.77.2', 'macos', 'release', {'macos/release': shaA});
      expect(r.zipName,
          'filament-v1.77.2-macos-release-0123456789abcdef.zip');
      expect(r.url, endsWith(r.zipName));
      expect(r.sha256, shaA);
      expect(r.cacheSuffix, '-0123456789abcdef');
    });

    test('pin entries are platform/variant-scoped', () {
      final pin = {'macos/release': shaA};
      // Same platform, other variant → legacy.
      expect(
          resolveFilamentArtifact('v1.77.2', 'macos', 'debug', pin).sha256,
          isNull);
      // Other platform → legacy.
      expect(
          resolveFilamentArtifact('v1.77.2', 'linux', 'release', pin).sha256,
          isNull);
    });

    test('different digests → different names and cache suffixes', () {
      final a = resolveFilamentArtifact(
          'v1.77.2', 'web', 'release', {'web/release': shaA});
      final b = resolveFilamentArtifact(
          'v1.77.2', 'web', 'release', {'web/release': shaB});
      expect(a.zipName, isNot(b.zipName));
      expect(a.cacheSuffix, isNot(b.cacheSuffix));
    });

    test('ios-simulator and linux-arm64 slugs resolve', () {
      final pin = {'ios-simulator/debug': shaA, 'linux-arm64/release': shaB};
      expect(
          resolveFilamentArtifact('v1.77.2', 'ios-simulator', 'debug', pin)
              .zipName,
          'filament-v1.77.2-ios-simulator-debug-0123456789abcdef.zip');
      expect(
          resolveFilamentArtifact('v1.77.2', 'linux-arm64', 'release', pin)
              .cacheSuffix,
          '-ffffffffffffffff');
    });
  });

  group('encodeFilamentPin', () {
    test('sorted keys, stable output, trailing newline', () {
      final encoded = encodeFilamentPin({
        'web/release': shaB,
        'macos/release': shaA,
      });
      expect(encoded, endsWith('\n'));
      final decoded = jsonDecode(encoded) as Map;
      expect(decoded.keys.toList(), ['macos/release', 'web/release']);
      // Re-encoding a parsed pin is a fixed point (stable CI diffs).
      expect(encodeFilamentPin(parseFilamentPin(encoded)), encoded);
    });

    test('empty pin encodes as {}', () {
      expect(encodeFilamentPin({}), '{}\n');
    });
  });
}
