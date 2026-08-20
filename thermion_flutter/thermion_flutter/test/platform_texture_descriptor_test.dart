import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/android_platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/darwin_platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/method_channel_platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/options.dart';

// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Darwin texture registration', () {
    test('accepts zero as the first valid iOS texture ID', () {
      expect(
        didDarwinTextureRegistrationFail(isIOS: true, textureId: 0),
        isFalse,
      );
    });

    test('treats zero as a macOS registration failure', () {
      expect(
        didDarwinTextureRegistrationFail(isIOS: false, textureId: 0),
        isTrue,
      );
    });

    test('accepts non-zero texture IDs on both platforms', () {
      expect(
        didDarwinTextureRegistrationFail(isIOS: true, textureId: 1),
        isFalse,
      );
      expect(
        didDarwinTextureRegistrationFail(isIOS: false, textureId: 1),
        isFalse,
      );
    });
  });

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
  test('Android frame publication does not send a platform message', () async {
    const channel = MethodChannel('thermion.test.texture');
    var methodCallCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCallCount++;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final descriptor = AndroidPlatformTextureDescriptor(
      channel,
      flutterTextureId: 1,
      hardwareId: 2,
      windowHandle: 3,
      width: 4,
      height: 5,
    );

    descriptor.markTextureFrameAvailable();
    await Future<void>.delayed(Duration.zero);

    expect(methodCallCount, 0);
  });

  test('awaitable frame publication waits for platform work', () async {
    const channel = MethodChannel('thermion.test.texture.presentation');
    final platformGate = Completer<void>();
    var completed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'markTextureFrameAvailable');
          await platformGate.future;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final descriptor = MethodChannelPlatformTextureDescriptor(
      channel,
      flutterTextureId: 1,
      hardwareId: 2,
      windowHandle: 3,
      width: 4,
      height: 5,
    );
    final publication = descriptor.markTextureFrameAvailableAndWait().then(
      (_) => completed = true,
    );

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    platformGate.complete();
    await publication;
    expect(completed, isTrue);
  });

  for (final (textureSource, expectedSurfaceProducer) in [
    (AndroidTextureSource.surfaceTexture, false),
    (AndroidTextureSource.surfaceProducer, true),
  ]) {
    test('Android allocation requests ${textureSource.name}', () async {
      const channel = MethodChannel('thermion.test.texture.allocation');
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return <int>[11, 11, 22];
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final descriptor = await AndroidPlatformTextureDescriptor.allocate(
        channel,
        640,
        480,
        textureSource,
      );

      expect(receivedCall?.method, 'createTexture');
      expect(receivedCall?.arguments, <Object?>[
        640,
        480,
        0,
        0,
        expectedSurfaceProducer,
      ]);
      expect(descriptor.flutterTextureId, 11);
      expect(descriptor.windowHandle, 22);
    });
  }
}

class _TestDescriptor extends PlatformTextureDescriptor {
  _TestDescriptor({required int flutterTextureId, int hardwareId = 0})
    : super(
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
