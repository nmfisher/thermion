import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor_registry_native.dart';
import 'package:thermion_flutter/src/widgets/src/texture_bootstrap.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

void main() {
  testWidgets(
    'initializes only after the bootstrap texture is ready and then destroys it',
    (tester) async {
      const textureId = 7;
      final events = <String>[];
      final ready = Completer<void>();
      var destroyCount = 0;

      await tester.pumpWidget(
        ThermionTextureBootstrap(
          createContextBootstrap: () async {
            events.add('create');
            return textureId;
          },
          awaitContextBootstrap: (id) async {
            expect(id, textureId);
            events.add('await');
            await ready.future;
          },
          destroyContextBootstrap: (id) async {
            expect(id, textureId);
            events.add('destroy');
            destroyCount++;
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

      ready.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(Texture), findsNothing);
      expect(events, ['create', 'await', 'initialize', 'destroy']);
      expect(destroyCount, 1);
    },
  );

  testWidgets('disposing cancels a pending bootstrap exactly once', (
    tester,
  ) async {
    final ready = Completer<void>();
    var initializeCount = 0;
    var destroyCount = 0;

    await tester.pumpWidget(
      ThermionTextureBootstrap(
        createContextBootstrap: () async => 7,
        awaitContextBootstrap: (_) => ready.future,
        destroyContextBootstrap: (_) async {
          destroyCount++;
          if (!ready.isCompleted) {
            ready.completeError(StateError('destroyed'));
          }
        },
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

    expect(destroyCount, 1);
    expect(initializeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ThermionWidget.create waits for context bootstrap', (
    tester,
  ) async {
    final ready = Completer<void>();
    final viewer = Completer<ThermionViewer>();
    final events = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = NativePlatformTextureDescriptorRegistry.channel;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'createContextBootstrap':
          events.add('create');
          return 7;
        case 'awaitTextureReady':
          events.add('await');
          await ready.future;
          return 11;
        case 'destroyTexture':
          events.add('destroy');
          return null;
        default:
          throw MissingPluginException('Unexpected method ${call.method}');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ThermionWidget.create(
          viewerFactory: () {
            events.add('viewer');
            return viewer.future;
          },
          initial: const SizedBox(key: Key('initial')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('initial')), findsOneWidget);
    expect(find.byType(Texture), findsOneWidget);
    expect(events, ['create', 'await']);

    ready.complete();
    await tester.pump();

    expect(events, ['create', 'await', 'viewer']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(events, ['create', 'await', 'viewer', 'destroy']);
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isLinux);
}
