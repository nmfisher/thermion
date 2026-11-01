import 'package:test/test.dart';
import 'package:thermion_dart/src/hooks/web_artifacts.dart';

void main() {
  group('resolveWebVariant', () {
    test('null → default (no warning)', () {
      final r = resolveWebVariant(null);
      expect(r.zipSuffix, '');
      expect(r.cacheSuffix, '');
      expect(r.warnings, isEmpty);
    });

    test('unset-ish raw values → default (no warning)', () {
      for (final raw in ['', ' ', 'worker', 'default']) {
        final r = resolveWebVariant(raw);
        expect(r.zipSuffix, '', reason: 'raw=$raw');
        expect(r.cacheSuffix, '');
        expect(r.warnings, isEmpty, reason: 'raw=$raw');
      }
    });

    test('main_thread (string, case/whitespace-insensitive)', () {
      for (final raw in ['main_thread', 'Main_Thread', ' main_thread ']) {
        final r = resolveWebVariant(raw);
        expect(r.zipSuffix, '-main-thread', reason: 'raw=$raw');
        expect(r.cacheSuffix, '-main-thread');
        expect(r.warnings, isEmpty);
      }
    });

    test('non-string truthy values (bool/int) are not main_thread', () {
      // `web_variant` is a string define, unlike web_local. A stray
      // `web_variant: true` must not silently select the variant — and,
      // matching resolveMaterialBackend's lenient handling of odd input,
      // must not crash either. Warn and fall back to the default.
      for (final raw in [true, 1]) {
        final r = resolveWebVariant(raw);
        expect(r.zipSuffix, '', reason: 'raw=$raw');
        expect(r.cacheSuffix, '');
        expect(r.warnings, hasLength(1), reason: 'raw=$raw');
      }
    });

    test('unknown values → warning + fallback to default', () {
      final r = resolveWebVariant('mono_thread');
      expect(r.zipSuffix, '');
      expect(r.cacheSuffix, '');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('mono_thread'));
      expect(r.warnings.single, contains('main_thread'));
    });
  });

  group('naming', () {
    test('zip names for both variants', () {
      expect(webArtifactZipName('9a8bbe3bf', ''), 'thermion_dart-9a8bbe3bf-web.zip');
      expect(webArtifactZipName('9a8bbe3bf', '-main-thread'), 'thermion_dart-9a8bbe3bf-web-main-thread.zip');
    });

    test('URLs compose with the R2 base', () {
      expect(
        webArtifactUrl('9a8bbe3bf', ''),
        'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/thermion_dart-9a8bbe3bf-web.zip',
      );
      expect(
        webArtifactUrl('9a8bbe3bf', '-main-thread'),
        'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/thermion_dart-9a8bbe3bf-web-main-thread.zip',
      );
    });

    test('webLocalBuildDir maps variant to its build directory', () {
      expect(webLocalBuildDir(''), 'build');
      expect(webLocalBuildDir('-main-thread'), 'build-main-thread');
    });

    test('main_thread resolution round-trips through naming helpers', () {
      final r = resolveWebVariant('main_thread');
      expect(webArtifactZipName('v', r.zipSuffix), 'thermion_dart-v-web-main-thread.zip');
      expect(webLocalBuildDir(r.zipSuffix), 'build-main-thread');
    });
  });
}
