import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/widgets/src/texture_bootstrap.dart';

void main() {
  testWidgets(
    'initializes only after the bootstrap texture is ready and then destroys it',
    (tester) async {
      final descriptor = _BootstrapDescriptor();
      final events = <String>[];
      descriptor.events = events;

      await tester.pumpWidget(
        ThermionTextureBootstrap(
          createContextBootstrap: () async {
            events.add('create');
            return descriptor;
          },
          destroyContextBootstrap: (descriptor) async {
            events.add('destroy');
            await descriptor.destroy();
          },
          initialize: () async {
            events.add('initialize');
          },
          child: const SizedBox.expand(),
        ),
      );
      await tester.pump();

      expect(find.byType(Texture), findsOneWidget);
      expect(events, ['create', 'await']);

      descriptor.completeReady(42);
      await tester.pump();
      await tester.pump();

      expect(descriptor.hardwareId, 42);
      expect(find.byType(Texture), findsNothing);
      expect(events, ['create', 'await', 'initialize', 'destroy']);
      expect(descriptor.destroyCount, 1);
    },
  );

  testWidgets('disposing cancels a pending bootstrap exactly once', (
    tester,
  ) async {
    final descriptor = _BootstrapDescriptor();
    var initializeCount = 0;

    await tester.pumpWidget(
      ThermionTextureBootstrap(
        createContextBootstrap: () async => descriptor,
        initialize: () async {
          initializeCount++;
        },
        child: const SizedBox.expand(),
      ),
    );
    await tester.pump();
    expect(find.byType(Texture), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(descriptor.destroyCount, 1);
    expect(initializeCount, 0);
    expect(tester.takeException(), isNull);
  });
}

class _BootstrapDescriptor extends PlatformTextureDescriptor {
  _BootstrapDescriptor()
    : super(flutterTextureId: 7, hardwareId: 0, width: 1, height: 1);

  final _ready = Completer<int>();
  int destroyCount = 0;
  bool _destroyed = false;
  List<String>? events;

  @override
  bool get deferred => true;

  @override
  bool get destroyed => _destroyed;

  @override
  Future<int> awaitTextureReady() {
    events?.add('await');
    return _ready.future;
  }

  void completeReady(int textureId) {
    if (!_ready.isCompleted) {
      _ready.complete(textureId);
    }
  }

  @override
  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    destroyCount++;
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('destroyed'));
    }
  }

  @override
  void markTextureFrameAvailable() {}
}
