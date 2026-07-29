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

  group('destroyRenderTargetResourcesInOrder', () {
    test('destroys the target before its attachment textures', () async {
      final events = <String>[];

      await destroyRenderTargetResourcesInOrder(
        destroyRenderTarget: () async => events.add('render-target'),
        destroyColorTexture: () async => events.add('color'),
        destroyDepthTexture: () async => events.add('depth'),
      );

      expect(events, ['render-target', 'color', 'depth']);
    });

    test(
      'keeps attachment textures alive when target destruction fails',
      () async {
        final events = <String>[];

        await expectLater(
          destroyRenderTargetResourcesInOrder(
            destroyRenderTarget: () async {
              events.add('render-target');
              throw StateError('expected');
            },
            destroyColorTexture: () async => events.add('color'),
            destroyDepthTexture: () async => events.add('depth'),
          ),
          throwsStateError,
        );

        expect(events, ['render-target']);
      },
    );
  });
}
