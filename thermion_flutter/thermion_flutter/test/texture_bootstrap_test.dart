import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/widgets/src/texture_bootstrap.dart';

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
}
