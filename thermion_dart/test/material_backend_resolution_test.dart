import 'package:test/test.dart';
import 'package:thermion_dart/src/hooks/material_backend_resolution.dart';

void main() {
  group('defaults (no materials.backends)', () {
    for (final entry in {
      'ios': ('_apple', 'THERMION_MATERIAL_APPLE'),
      'macos': ('_apple', 'THERMION_MATERIAL_APPLE'),
      'android': ('_android', 'THERMION_MATERIAL_ANDROID'),
      'linux': ('_desktop', 'THERMION_MATERIAL_DESKTOP'),
      'windows': ('_desktop', 'THERMION_MATERIAL_DESKTOP'),
    }.entries) {
      test('${entry.key} -> ${entry.value.$1}', () {
        final r = resolveMaterialBackend(backendsConfig: null, targetOS: entry.key);
        expect(r.suffix, entry.value.$1);
        expect(r.define, entry.value.$2);
        expect(r.warnings, isEmpty);
      });
    }
  });

  group('single backend', () {
    test('android: [vulkan] -> _vulkan', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'android': ['vulkan'],
        },
        targetOS: 'android',
      );
      expect(r.suffix, '_vulkan');
      expect(r.define, 'THERMION_MATERIAL_VULKAN');
    });

    test('linux: [opengl] -> _opengl', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'linux': ['opengl'],
        },
        targetOS: 'linux',
      );
      expect(r.suffix, '_opengl');
      expect(r.define, 'THERMION_MATERIAL_OPENGL');
    });

    test('windows: vulkan (bare string) -> _vulkan', () {
      final r = resolveMaterialBackend(backendsConfig: {'windows': 'vulkan'}, targetOS: 'windows');
      expect(r.suffix, '_vulkan');
    });

    test('ios: metal -> _apple', () {
      final r = resolveMaterialBackend(backendsConfig: {'ios': 'metal'}, targetOS: 'ios');
      expect(r.suffix, '_apple');
      expect(r.define, 'THERMION_MATERIAL_APPLE');
    });
  });

  group('dual backend', () {
    test('android: [opengl, vulkan] -> _android', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'android': ['opengl', 'vulkan'],
        },
        targetOS: 'android',
      );
      expect(r.suffix, '_android');
      expect(r.define, 'THERMION_MATERIAL_ANDROID');
    });

    test('order-independent + deduplicated', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'linux': ['vulkan', 'opengl', 'vulkan'],
        },
        targetOS: 'linux',
      );
      expect(r.suffix, '_desktop');
      expect(r.define, 'THERMION_MATERIAL_DESKTOP');
    });

    test('android: [opengl, vulkan] stays _android even though desktop shares flags', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'android': ['vulkan', 'opengl'],
        },
        targetOS: 'android',
      );
      expect(r.suffix, '_android');
    });
  });

  group('apple alias', () {
    test('apple: metal covers ios', () {
      final r = resolveMaterialBackend(backendsConfig: {'apple': 'metal'}, targetOS: 'ios');
      expect(r.suffix, '_apple');
    });

    test('apple: metal covers macos', () {
      final r = resolveMaterialBackend(backendsConfig: {'apple': 'metal'}, targetOS: 'macos');
      expect(r.suffix, '_apple');
    });

    test('explicit ios/macos key wins over apple alias', () {
      // metal is the only valid token on apple platforms, so the win is
      // observable via validation: the explicit key is the one validated.
      final r = resolveMaterialBackend(backendsConfig: {'apple': 'metal', 'macos': 'metal'}, targetOS: 'macos');
      expect(r.suffix, '_apple');
      expect(r.warnings, isEmpty);
    });
  });

  group('unlisted OS falls back to platform default', () {
    test('config for android does not affect linux', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'android': ['vulkan'],
        },
        targetOS: 'linux',
      );
      expect(r.suffix, '_desktop');
      expect(r.warnings, isEmpty);
    });

    test('config for ios does not affect android', () {
      final r = resolveMaterialBackend(backendsConfig: {'ios': 'metal'}, targetOS: 'android');
      expect(r.suffix, '_android');
    });
  });

  group('validation errors', () {
    test('unknown OS key throws', () {
      expect(
        () => resolveMaterialBackend(
          backendsConfig: {
            'androi': ['vulkan'],
          },
          targetOS: 'linux',
        ),
        throwsA(isA<MaterialBackendError>().having((e) => e.message, 'message', contains('androi'))),
      );
    });

    test('metal on android throws naming the token and OS', () {
      expect(
        () => resolveMaterialBackend(
          backendsConfig: {
            'android': ['vulkan', 'metal'],
          },
          targetOS: 'android',
        ),
        throwsA(
          isA<MaterialBackendError>().having(
            (e) => e.message,
            'message',
            allOf(contains('metal'), contains('android')),
          ),
        ),
      );
    });

    test('opengl on ios throws', () {
      expect(
        () => resolveMaterialBackend(
          backendsConfig: {
            'ios': ['opengl'],
          },
          targetOS: 'ios',
        ),
        throwsA(isA<MaterialBackendError>()),
      );
    });

    test('empty list throws', () {
      expect(
        () => resolveMaterialBackend(backendsConfig: {'android': []}, targetOS: 'android'),
        throwsA(isA<MaterialBackendError>()),
      );
    });

    test('webgpu-only list strips to empty and throws', () {
      expect(
        () => resolveMaterialBackend(
          backendsConfig: {
            'android': ['webgpu'],
          },
          targetOS: 'android',
        ),
        throwsA(isA<MaterialBackendError>()),
      );
    });

    test('non-string entry throws', () {
      expect(
        () => resolveMaterialBackend(
          backendsConfig: {
            'linux': [42],
          },
          targetOS: 'linux',
        ),
        throwsA(isA<MaterialBackendError>()),
      );
    });

    test('unsupported combination on ios throws', () {
      expect(
        () => resolveMaterialBackend(
          backendsConfig: {
            'ios': ['metal', 'opengl'],
          },
          targetOS: 'ios',
        ),
        throwsA(isA<MaterialBackendError>()),
      );
    });
  });

  group('web is out of scope', () {
    test('web key warns and is ignored', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'web': ['webgpu'],
          'linux': ['vulkan'],
        },
        targetOS: 'linux',
      );
      expect(r.suffix, '_vulkan');
      expect(r.warnings.any((w) => w.contains('web')), isTrue);
    });

    test('webgpu token in an OS list warns and is stripped', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'android': ['vulkan', 'webgpu'],
        },
        targetOS: 'android',
      );
      expect(r.suffix, '_vulkan');
      expect(r.warnings.any((w) => w.contains('webgpu')), isTrue);
    });
  });

  group('coexistence with flat backend override', () {
    test('override alone (no backends config) selects its variant', () {
      final r = resolveMaterialBackend(backendsConfig: null, targetOS: 'linux', backendOverride: 'webgpu');
      expect(r.suffix, '_webgpu');
      expect(r.define, 'THERMION_MATERIAL_WEBGPU');
      expect(r.warnings, isEmpty);
    });

    test('override applies when backends does not cover the target OS', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'android': ['vulkan'],
        },
        targetOS: 'linux',
        backendOverride: 'webgpu',
      );
      expect(r.suffix, '_webgpu');
      expect(r.warnings.where((w) => w.contains('precedence')), isEmpty);
    });

    test('warns when both cover the target; materials.backends wins', () {
      final r = resolveMaterialBackend(
        backendsConfig: {
          'linux': ['vulkan'],
        },
        targetOS: 'linux',
        backendOverride: 'webgpu',
      );
      expect(r.suffix, '_vulkan');
      expect(r.warnings.any((w) => w.contains('precedence')), isTrue);
    });

    test('unknown override value throws', () {
      expect(
        () => resolveMaterialBackend(backendsConfig: null, targetOS: 'linux', backendOverride: 'voodoographics'),
        throwsA(isA<MaterialBackendError>()),
      );
    });
  });

  group('backend user define (flat string + per-OS map)', () {
    test('null → native (no warning)', () {
      final r = resolveBackendUserDefine(raw: null, targetOS: 'linux');
      expect(r.backend, 'native');
      expect(r.warnings, isEmpty);
    });

    test('string form keeps working for every OS', () {
      for (final os in ['ios', 'macos', 'android', 'linux', 'windows', 'web']) {
        final r = resolveBackendUserDefine(raw: 'webgpu', targetOS: os);
        expect(r.backend, 'webgpu', reason: 'os=$os');
        expect(r.warnings, isEmpty);
      }
    });

    test('string values are case-insensitive and trimmed; combined → hybrid', () {
      expect(resolveBackendUserDefine(raw: 'WebGPU', targetOS: 'macos').backend, 'webgpu');
      expect(resolveBackendUserDefine(raw: ' webgl2 ', targetOS: 'web').backend, 'webgl2');
      expect(resolveBackendUserDefine(raw: 'combined', targetOS: 'web').backend, 'hybrid');
      expect(resolveBackendUserDefine(raw: 'native', targetOS: 'linux').backend, 'native');
    });

    test('unknown string warns and falls back to native', () {
      final r = resolveBackendUserDefine(raw: 'voodoographics', targetOS: 'linux');
      expect(r.backend, 'native');
      expect(r.warnings.single, contains('voodoographics'));
    });

    test('legacy webgpu: true maps to webgpu', () {
      for (final legacy in [true, 'true', 1, '1']) {
        final r = resolveBackendUserDefine(raw: null, targetOS: 'linux', legacyWebgpu: legacy);
        expect(r.backend, 'webgpu', reason: 'legacy=$legacy');
      }
    });

    test('explicit backend beats legacy webgpu', () {
      final r = resolveBackendUserDefine(raw: 'webgl2', targetOS: 'linux', legacyWebgpu: true);
      expect(r.backend, 'webgl2');
    });

    test('per-OS entry wins; uncovered targets fall back to native', () {
      final raw = {'web': 'webgpu', 'macos': 'native'};
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'web').backend, 'webgpu');
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'macos').backend, 'native');
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'linux').backend, 'native');
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'android').backend, 'native');
    });

    test('map entry beats legacy webgpu; legacy still covers uncovered OSes', () {
      final raw = {'web': 'webgl2'};
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'web', legacyWebgpu: true).backend, 'webgl2');
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'linux', legacyWebgpu: true).backend, 'webgpu');
    });

    test('keys and values are case-insensitive', () {
      final r = resolveBackendUserDefine(raw: {'Web': 'WebGPU'}, targetOS: 'web');
      expect(r.backend, 'webgpu');
      expect(r.warnings, isEmpty);
    });

    test('apple alias covers ios and macos; explicit key wins', () {
      final raw = {'apple': 'webgpu', 'macos': 'webgl2'};
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'ios').backend, 'webgpu');
      expect(resolveBackendUserDefine(raw: raw, targetOS: 'macos').backend, 'webgl2');
    });

    test('unknown OS key throws (even when it does not affect the target)', () {
      expect(
        () => resolveBackendUserDefine(raw: {'androi': 'webgpu'}, targetOS: 'linux'),
        throwsA(isA<MaterialBackendError>().having((e) => e.message, 'message', contains('androi'))),
      );
    });

    test('unknown map value throws naming the key', () {
      expect(
        () => resolveBackendUserDefine(raw: {'web': 'voodoographics'}, targetOS: 'web'),
        throwsA(isA<MaterialBackendError>().having((e) => e.message, 'message', contains('backend.web'))),
      );
    });

    test('non-string map value throws', () {
      expect(() => resolveBackendUserDefine(raw: {'web': true}, targetOS: 'web'), throwsA(isA<MaterialBackendError>()));
    });
  });
}
