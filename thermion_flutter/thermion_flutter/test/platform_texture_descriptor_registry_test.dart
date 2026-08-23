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

    test('can retain an old binding during deferred replacement', () async {
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

      await registry.bindToView(second, view, releaseExistingBindings: false);

      expect(first.boundView, same(view));
      expect(second.boundView, same(view));

      await registry.destroyBindingsForView(view);
      expect(first.destroyCount, 1);
      expect(second.destroyCount, 1);
    });

    test('destroys platform descriptors after view-owned resources', () async {
      final events = <String>[];
      final descriptor = _TestDescriptor(
        width: 1,
        height: 1,
        lifecycleEvents: events,
      );
      final registry = PlatformTextureDescriptorRegistry(
        allocator: (_, __) => descriptor,
      );
      final view = _TestView();
      await registry.create(1, 1);
      await registry.bindToView(descriptor, view);

      await registry.destroyBindingsForView(
        view,
        beforeDescriptorDestroy: () async {
          events.add('destroy-view-resources');
        },
      );

      expect(events, [
        'release-binding',
        'destroy-view-resources',
        'destroy-platform-texture',
      ]);
      expect(registry.contains(descriptor), isFalse);
    });

    test(
      'keeps the platform texture alive when view-resource cleanup fails',
      () async {
        final descriptor = _TestDescriptor(width: 1, height: 1);
        final registry = PlatformTextureDescriptorRegistry(
          allocator: (_, __) => descriptor,
        );
        final view = _TestView();
        await registry.create(1, 1);
        await registry.bindToView(descriptor, view);

        await expectLater(
          registry.destroyBindingsForView(
            view,
            beforeDescriptorDestroy: () => throw StateError('expected'),
          ),
          throwsStateError,
        );

        expect(descriptor.releaseBindingCount, 1);
        expect(descriptor.destroyCount, 0);
        expect(descriptor.boundView, same(view));
        expect(registry.contains(descriptor), isTrue);
      },
    );

    test(
      'attempts every platform texture destroy after target cleanup',
      () async {
        var nextTextureId = 1;
        final registry = PlatformTextureDescriptorRegistry(
          allocator: (width, height) {
            return _TestDescriptor(
              width: width,
              height: height,
              flutterTextureId: nextTextureId++,
            );
          },
        );
        final view = _TestView();
        final first = await registry.create(1, 1) as _TestDescriptor;
        final second = await registry.create(1, 1) as _TestDescriptor;
        await registry.bindToView(first, view);
        await registry.bindToView(second, view, releaseExistingBindings: false);
        first.throwOnDestroy = true;

        await expectLater(
          registry.destroyBindingsForView(view),
          throwsStateError,
        );

        expect(first.destroyCount, 1);
        expect(second.destroyCount, 1);
        expect(registry.contains(first), isTrue);
        expect(registry.contains(second), isFalse);
      },
    );

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
    this.lifecycleEvents,
  }) : super(flutterTextureId: flutterTextureId, hardwareId: 2);

  final List<String>? lifecycleEvents;
  int markFrameAvailableCount = 0;
  int releaseBindingCount = 0;
  int destroyCount = 0;
  bool _destroyed = false;
  bool _surfaceAvailable = true;
  bool throwOnDestroy = false;

  @override
  bool get destroyed => _destroyed;

  @override
  bool get isSurfaceAvailable => _surfaceAvailable;

  @override
  Future<void> markTextureFrameAvailable() async {
    markFrameAvailableCount++;
  }

  @override
  void markSurfaceUnavailable() {
    _surfaceAvailable = false;
  }

  @override
  Future<void> releaseBinding() async {
    releaseBindingCount++;
    lifecycleEvents?.add('release-binding');
    await super.releaseBinding();
  }

  @override
  Future<void> destroy() async {
    if (_destroyed) return;
    destroyCount++;
    lifecycleEvents?.add('destroy-platform-texture');
    if (throwOnDestroy) {
      throw StateError('expected');
    }
    _destroyed = true;
  }
}

class _TestView implements View<int> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
