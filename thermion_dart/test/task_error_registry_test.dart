import 'dart:async';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/task_error_registry.dart';

void main() {
  for (final asyncSetup in [false, true]) {
    test('polls native completions with async setup=$asyncSetup', () async {
      final scopes = <int>[];
      final callbacks = <void Function()>[];
      final registry = TaskErrorRegistry(
        install: scopes.add,
        clear: () {
          scopes.removeLast();
          return 0;
        },
      );
      final done = Completer<int>();
      var pumps = 0;
      final future = registry.invoke(
        done,
        asyncSetup
            ? () async {
                callbacks.add(() => done.complete(42));
              }
            : () {
                callbacks.add(() => done.complete(42));
              },
        pump: () {
          expect(scopes, isEmpty, reason: 'pumping must not retain the dispatch scope');
          pumps++;
          if (callbacks.isNotEmpty) callbacks.removeAt(0)();
        },
      );
      expect(await future.timeout(const Duration(seconds: 1)), 42);
      expect(pumps, greaterThan(0));
      expect(registry.pendingRequestCount, 0);
    });
  }

  test('setup failure stops polling and releases listener keep-alive', () async {
    final active = <bool>[];
    final registry = TaskErrorRegistry(install: (_) {}, clear: () => 0, onPendingChanged: active.add);
    var pumps = 0;
    final future = registry.invoke(
      Completer<void>(),
      () async {
        await Future<void>.delayed(Duration.zero);
        throw StateError('setup failed');
      },
      pump: () {
        pumps++;
      },
    );
    await expectLater(future, throwsA(isA<StateError>()));
    final stoppedAt = pumps;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(pumps, stoppedAt);
    expect(registry.pendingRequestCount, 0);
    expect(active, [true, false]);
  });

  test('pump failure settles the request', () async {
    final registry = TaskErrorRegistry(install: (_) {}, clear: () => 0);
    final done = Completer<void>();
    await expectLater(
      registry.invoke(
        done,
        () {},
        pump: () {
          throw StateError('proxy queue failed');
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(done.isCompleted, isTrue);
    expect(registry.pendingRequestCount, 0);
  });

  for (final asyncFailure in [false, true]) {
    test('dispatch failure retains queued callback: async=$asyncFailure', () async {
      final active = <bool>[];
      final done = Completer<int>();
      final registry = TaskErrorRegistry(install: (_) {}, clear: () => 1, onPendingChanged: active.add);
      var returned = false;
      var pumps = 0;
      final future = registry.invoke(
        done,
        () {
          if (asyncFailure) return Future<void>.error(StateError('setup failed after enqueue'));
          throw StateError('setup failed after enqueue');
        },
        pump: () {
          pumps++;
        },
      );
      final assertion = expectLater(
        future.whenComplete(() {
          returned = true;
        }),
        throwsA(isA<StateError>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(returned, isFalse);
      expect(done.isCompleted, isFalse);
      expect(registry.pendingRequestCount, 1);
      expect(active, [true]);
      expect(pumps, greaterThan(1));
      done.complete(42);
      await assertion;
      expect(active, [true, false]);
      expect(registry.pendingRequestCount, 0);
    });
  }

  test('listener stays active until all concurrent requests settle', () async {
    final active = <bool>[];
    final registry = TaskErrorRegistry(install: (_) {}, clear: () => 0, onPendingChanged: active.add);
    final first = Completer<void>();
    final second = Completer<void>();
    final a = registry.invoke(first, () {});
    final b = registry.invoke(second, () {});
    second.complete();
    await b;
    expect(active, [true]);
    first.complete();
    await a;
    expect(active, [true, false]);
  });

  test('typed errors settle and release requests, including late duplicates', () async {
    final scopes = <int>[];
    final registry = TaskErrorRegistry(
      install: scopes.add,
      clear: () {
        scopes.removeLast();
        return 0;
      },
    );
    final result = Completer<int>();
    late int requestId;
    final future = registry.invoke(result, () {
      requestId = scopes.single;
    });
    expect(scopes, isEmpty);
    final assertion = expectLater(future, throwsA(isA<StateError>()));
    registry.fail(requestId, 'typed operation failed');
    await assertion;
    expect(registry.pendingRequestCount, 0);
    registry.fail(requestId, 'late duplicate');
  });

  test('success and synchronous dispatch errors always release scopes', () async {
    final scopes = <int>[];
    final registry = TaskErrorRegistry(
      install: scopes.add,
      clear: () {
        scopes.removeLast();
        return 0;
      },
    );
    final success = Completer<String>();
    expect(await registry.invoke(success, () => success.complete('done')), 'done');
    await expectLater(
      registry.invoke(Completer<void>(), () => throw StateError('dispatch failed')),
      throwsA(isA<StateError>()),
    );
    expect(scopes, isEmpty);
    expect(registry.pendingRequestCount, 0);
  });

  test('nested dispatch scopes and out-of-order completions stay distinct', () async {
    final scopes = <int>[];
    final registry = TaskErrorRegistry(
      install: scopes.add,
      clear: () {
        scopes.removeLast();
        return 0;
      },
    );
    final outer = Completer<void>();
    final inner = Completer<int>();
    late int outerId;
    late int innerId;
    late Future<int> innerFuture;
    final outerFuture = registry.invoke(outer, () {
      outerId = scopes.single;
      innerFuture = registry.invoke(inner, () {
        expect(scopes.length, 2);
        innerId = scopes.last;
      });
      expect(scopes.single, outerId);
    });
    expect(scopes, isEmpty);
    final outerAssertion = expectLater(outerFuture, throwsA(isA<StateError>()));
    final innerAssertion = expectLater(innerFuture, throwsA(isA<StateError>()));
    registry.fail(innerId, 'shared native operation failed');
    registry.fail(outerId, 'shared native operation failed');
    await Future.wait([outerAssertion, innerAssertion]);
    expect(registry.pendingRequestCount, 0);
  });

  test('async dispatch failures settle requests without leaking native scopes', () async {
    final scopes = <int>[];
    final registry = TaskErrorRegistry(
      install: scopes.add,
      clear: () {
        scopes.removeLast();
        return 0;
      },
    );
    final future = registry.invoke(Completer<void>(), () async {
      expect(scopes, hasLength(1));
      await Future<void>.delayed(Duration.zero);
      expect(scopes, isEmpty);
      throw StateError('upload setup failed');
    });
    expect(scopes, isEmpty);
    await expectLater(future, throwsA(isA<StateError>()));
    expect(registry.pendingRequestCount, 0);
  });

  test('native failure waits for dispatch to stop using its callback', () async {
    final scopes = <int>[];
    final registry = TaskErrorRegistry(
      install: scopes.add,
      clear: () {
        scopes.removeLast();
        return 0;
      },
    );
    final setup = Completer<void>();
    late int requestId;
    final future = registry.invoke(Completer<void>(), () {
      requestId = scopes.single;
      return setup.future;
    });
    final assertion = expectLater(future, throwsA(isA<StateError>()));
    registry.fail(requestId, 'native failure during setup');
    await Future<void>.delayed(Duration.zero);
    expect(registry.pendingRequestCount, 1);
    setup.completeError(StateError('late setup failure must be observed'));
    await assertion;
    expect(registry.pendingRequestCount, 0);
    await Future<void>.delayed(Duration.zero);
  });
}
