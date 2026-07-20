import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';

// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';

void main() {
  group('PlatformTextureDescriptor equality', () {
    test(
      'descriptors with the same flutterTextureId match (== and hashCode)',
      () {
        // Two distinct instances that differ in every other field — only the
        // stable native reference (flutterTextureId) is shared.
        final a = _TestDescriptor(flutterTextureId: 1, hardwareId: 10);
        final b = _TestDescriptor(flutterTextureId: 1, hardwareId: 99);

        expect(a == b, isTrue);
        expect(a.hashCode, b.hashCode);
      },
    );

    test('descriptors with different flutterTextureIds do not match', () {
      expect(
        _TestDescriptor(flutterTextureId: 1) ==
            _TestDescriptor(flutterTextureId: 2),
        isFalse,
      );
    });
  });

  // [View] inherits its equality from [NativeHandle] (compare-by-native-handle),
  // so this group verifies the mechanism `descriptor.boundView` relies on for
  // matching distinct Dart wrappers around the same native view.
  group('NativeHandle equality (inherited by View)', () {
    test('handles with the same native reference match', () {
      final a = _TestNativeHandle(42);
      final b = _TestNativeHandle(42);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('handles with different native references do not match', () {
      expect(_TestNativeHandle(42) == _TestNativeHandle(43), isFalse);
    });
  });
}

class _TestDescriptor extends PlatformTextureDescriptor {
  _TestDescriptor({
    required int flutterTextureId,
    int hardwareId = 0,
  }) : super(
          flutterTextureId: flutterTextureId,
          hardwareId: hardwareId,
          width: 1,
          height: 1,
        );

  @override
  void markTextureFrameAvailable() {}

  @override
  Future destroy() async {}
}

class _TestNativeHandle extends NativeHandle<int> {
  _TestNativeHandle(this.handle);

  final int handle;

  @override
  int getNativeHandle() => handle;
}
