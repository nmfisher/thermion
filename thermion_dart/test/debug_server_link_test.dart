import 'package:test/test.dart';
import 'package:thermion_dart/src/hooks/debug_server_link.dart';

void main() {
  DebugServerLinkResolution resolve(String targetOS, {required bool debug, Set<String> shipped = const {}}) {
    return resolveDebugServerLink(targetOS: targetOS, debug: debug, shipped: shipped.contains);
  }

  group('release builds', () {
    for (final os in ['windows', 'macos', 'linux', 'android', 'ios']) {
      test('$os links no debug-server archive', () {
        final r = resolve(os, debug: false, shipped: {'matdbg', 'fgviewer'});
        expect(r.archives, isEmpty);
        expect(r.matdbgLinked, isFalse);
        expect(r.notShipped, isEmpty);
      });
    }
  });

  group('iOS debug', () {
    test('links nothing (its artifact enables neither)', () {
      final r = resolve('ios', debug: true, shipped: {'matdbg', 'fgviewer'});
      expect(r.archives, isEmpty);
      expect(r.matdbgLinked, isFalse);
      expect(r.notShipped, isEmpty);
    });
  });

  group('macOS / Linux / Android debug', () {
    for (final os in ['macos', 'linux', 'android']) {
      test('$os links both archives unconditionally', () {
        // The artifact scripts build matdbg + fgviewer into every debug
        // zip, so a missing archive must fail the link, not be skipped.
        final r = resolve(os, debug: true, shipped: {});
        expect(r.archives, ['matdbg', 'fgviewer']);
        expect(r.matdbgLinked, isTrue);
        expect(r.notShipped, isEmpty);
      });
    }
  });

  group('Windows debug (artifact-driven)', () {
    test('pinned v1.77.2 zip: matdbg shipped, fgviewer absent -> matdbg only', () {
      final r = resolve('windows', debug: true, shipped: {'matdbg'});
      expect(r.archives, ['matdbg']);
      expect(r.matdbgLinked, isTrue);
      expect(r.notShipped, ['fgviewer']);
    });

    test('a zip that ships both links both', () {
      final r = resolve('windows', debug: true, shipped: {'matdbg', 'fgviewer'});
      expect(r.archives, ['matdbg', 'fgviewer']);
      expect(r.matdbgLinked, isTrue);
      expect(r.notShipped, isEmpty);
    });

    test('a zip that ships only fgviewer links it without pulling matdbg deps', () {
      final r = resolve('windows', debug: true, shipped: {'fgviewer'});
      expect(r.archives, ['fgviewer']);
      expect(r.matdbgLinked, isFalse);
      expect(r.notShipped, ['matdbg']);
    });

    test('a zip that ships neither links nothing', () {
      final r = resolve('windows', debug: true, shipped: {});
      expect(r.archives, isEmpty);
      expect(r.matdbgLinked, isFalse);
      expect(r.notShipped, ['matdbg', 'fgviewer']);
    });

    test('shipped() is consulted for fgviewer only when matdbg was checked first', () {
      final asked = <String>[];
      final r = resolveDebugServerLink(
        targetOS: 'windows',
        debug: true,
        shipped: (archive) {
          asked.add(archive);
          return archive == 'matdbg';
        },
      );
      expect(asked, ['matdbg', 'fgviewer']);
      expect(r.matdbgLinked, isTrue);
    });
  });

  group('non-Windows never consults shipped()', () {
    test('linux', () {
      final r = resolveDebugServerLink(
        targetOS: 'linux',
        debug: true,
        shipped: (_) => throw StateError('must not be called'),
      );
      expect(r.archives, ['matdbg', 'fgviewer']);
    });
  });

  group('windowsShaderCompilerArchives', () {
    test('debug: glslang targets carry the CMake DEBUG_POSTFIX "d"', () {
      expect(windowsShaderCompilerArchives(debug: true), [
        'OSDependentd',
        'glslangd',
        'SPIRVd',
        'SPIRV-Tools',
        'SPIRV-Tools-opt',
        'spirv-cross-core',
        'spirv-cross-glsl',
        'spirv-cross-msl',
      ]);
    });

    test('release: un-suffixed names', () {
      expect(windowsShaderCompilerArchives(debug: false), [
        'OSDependent',
        'glslang',
        'SPIRV',
        'SPIRV-Tools',
        'SPIRV-Tools-opt',
        'spirv-cross-core',
        'spirv-cross-glsl',
        'spirv-cross-msl',
      ]);
    });

    test('only the three glslang targets differ between modes', () {
      final debug = windowsShaderCompilerArchives(debug: true);
      final release = windowsShaderCompilerArchives(debug: false);
      expect(debug.length, release.length);
      for (var i = 0; i < debug.length; i++) {
        if (i < 3) {
          expect(debug[i], '${release[i]}d');
        } else {
          expect(debug[i], release[i]);
        }
      }
    });
  });

  test('windowsMatdbgDependencies excludes archives the hook already links', () {
    for (final alreadyLinked in ['filamat', 'filaflat', 'utils', 'smol-v', 'shaders']) {
      expect(windowsMatdbgDependencies, isNot(contains(alreadyLinked)));
    }
    expect(windowsMatdbgDependencies, containsAll(['matdbg_resources', 'civetweb']));
  });
}
