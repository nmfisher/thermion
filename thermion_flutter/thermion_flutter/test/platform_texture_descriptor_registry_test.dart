import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_dart/thermion_dart.dart' show View;
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor_registry.dart';

void main() {
  group('PlatformTextureDescriptorRegistry', () {
    test('creates, tracks, marks, and destroys descriptors', () async {
      late _TestDescriptor descriptor;
      final registry = PlatformTextureDescriptorRegistry(
        allocator: (width, height) {
          return descriptor = _TestDescriptor(width: width, height: height);
        },
      );

      final created = await registry.create(20, 10);

      expect(created, same(descriptor));
      expect(registry.contains(descriptor), isTrue);
      registry.markFrameAvailable();
      expect(descriptor.markFrameAvailableCount, 1);

      await registry.destroy(descriptor);

      expect(registry.contains(descriptor), isFalse);
      expect(descriptor.releaseBindingCount, 1);
      expect(descriptor.destroyCount, 1);
    });

    test(
      'forgets directly destroyed descriptors before frame notification',
      () async {
        final descriptor = _TestDescriptor(width: 1, height: 1);
        final registry = PlatformTextureDescriptorRegistry(
          allocator: (_, __) => descriptor,
        );
        await registry.create(1, 1);
        await descriptor.destroy();

        registry.markFrameAvailable();

        expect(registry.contains(descriptor), isFalse);
        expect(descriptor.markFrameAvailableCount, 0);
      },
    );

    test('reports unavailable surfaces', () async {
      final descriptor = _TestDescriptor(width: 1, height: 1);
      final registry = PlatformTextureDescriptorRegistry(
        allocator: (_, __) => descriptor,
      );
      await registry.create(1, 1);

      expect(registry.hasUnavailableSurfaces, isFalse);
      descriptor.markSurfaceUnavailable();
      expect(registry.hasUnavailableSurfaces, isTrue);
    });

    test('tracks equal descriptors by identity', () async {
      final registry = PlatformTextureDescriptorRegistry(
        allocator: (width, height) =>
            _TestDescriptor(width: width, height: height, flutterTextureId: 1),
      );

      final first = await registry.create(1, 1) as _TestDescriptor;
      final second = await registry.create(1, 1) as _TestDescriptor;

      expect(registry.descriptors.toList(), [same(first), same(second)]);

      await registry.destroy(second);

      expect(registry.descriptors.single, same(first));
      expect(first.destroyCount, 0);
      expect(second.destroyCount, 1);
    });

    test('rejects an equal but unregistered descriptor', () async {
      final registered = _TestDescriptor(width: 1, height: 1);
      final registry = PlatformTextureDescriptorRegistry(
        allocator: (_, __) => registered,
      );
      await registry.create(1, 1);
      final unregistered = _TestDescriptor(width: 1, height: 1);

      await expectLater(
        registry.bindToView(unregistered, _TestView()),
        throwsStateError,
      );
    });

    test('replaces and releases bindings for one view', () async {
      var nextTextureId = 1;
      final registry = PlatformTextureDescriptorRegistry(
        allocator: (width, height) => _TestDescriptor(
          width: width,
          height: height,
          flutterTextureId: nextTextureId++,
        ),
      );
      final view = _TestView();
      final first = await registry.create(1, 1) as _TestDescriptor;
      final second = await registry.create(1, 1) as _TestDescriptor;

      await registry.bindToView(first, view);
      await registry.bindToView(second, view);

      expect(first.boundView, isNull);
      expect(first.releaseBindingCount, 1);
      expect(second.boundView, same(view));

      final released = await registry.releaseBindingsForView(view);

      expect(released.single, same(second));
      expect(second.boundView, isNull);
      expect(second.releaseBindingCount, 1);
      expect(registry.descriptors.single, same(first));
    });

    test('serializes operations and continues after failures', () async {
      final registry = PlatformTextureDescriptorRegistry(
        allocator: (width, height) =>
            _TestDescriptor(width: width, height: height),
      );
      final gate = Completer<void>();
      final events = <String>[];

      final first = registry.serialized(() async {
        events.add('first-start');
        await gate.future;
        events.add('first-end');
      });
      final second = registry.serialized(() async {
        events.add('second');
        throw StateError('expected');
      });
      final third = registry.serialized(() async {
        events.add('third');
        return 3;
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, ['first-start']);
      gate.complete();

      await first;
      await expectLater(second, throwsStateError);
      expect(await third, 3);
      expect(events, ['first-start', 'first-end', 'second', 'third']);
    });
  });
}

class _TestDescriptor extends PlatformTextureDescriptor {
  _TestDescriptor({
    required super.width,
    required super.height,
    int flutterTextureId = 1,
  }) : super(flutterTextureId: flutterTextureId, hardwareId: 2);

  int markFrameAvailableCount = 0;
  int releaseBindingCount = 0;
  int destroyCount = 0;
  bool _destroyed = false;
  bool _surfaceAvailable = true;

  @override
  bool get destroyed => _destroyed;

  @override
  bool get isSurfaceAvailable => _surfaceAvailable;

  @override
  void markTextureFrameAvailable() {
    markFrameAvailableCount++;
  }

  @override
  void markSurfaceUnavailable() {
    _surfaceAvailable = false;
  }

  @override
  Future<void> releaseBinding() async {
    releaseBindingCount++;
    await super.releaseBinding();
  }

  @override
  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    destroyCount++;
  }
}

class _TestView implements View<int> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
