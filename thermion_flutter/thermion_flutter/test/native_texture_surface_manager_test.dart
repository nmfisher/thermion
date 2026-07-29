import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/native_texture_surface_manager.dart';

void main() {
  group('shouldDeferNativeTextureBinding', () {
    test('prefers an immediately available Linux hardware handle', () {
      expect(
        shouldDeferNativeTextureBinding(
          managesFilamentSurface: false,
          hardwareId: 0x1234,
          supportsDeferredBinding: true,
        ),
        isFalse,
      );
    });

    test('defers only when no hardware handle is available', () {
      expect(
        shouldDeferNativeTextureBinding(
          managesFilamentSurface: false,
          hardwareId: 0,
          supportsDeferredBinding: true,
        ),
        isTrue,
      );
    });

    test('does not defer descriptor-managed surfaces', () {
      expect(
        shouldDeferNativeTextureBinding(
          managesFilamentSurface: true,
          hardwareId: 0,
          supportsDeferredBinding: true,
        ),
        isFalse,
      );
    });
  });
}
