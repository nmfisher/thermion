import 'dart:async';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/task_error_registry.dart';

void main() {
  test('typed errors settle and release requests, including late duplicates', () async {
    final scopes = <int>[];
    final registry = TaskErrorRegistry(install: scopes.add, clear: () => scopes.removeLast());
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
    final registry = TaskErrorRegistry(install: scopes.add, clear: () => scopes.removeLast());
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
    final registry = TaskErrorRegistry(install: scopes.add, clear: () => scopes.removeLast());
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
    final registry = TaskErrorRegistry(install: scopes.add, clear: () => scopes.removeLast());
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

  test('native failure settles while async setup is still pending', () async {
    final scopes = <int>[];
    final registry = TaskErrorRegistry(install: scopes.add, clear: () => scopes.removeLast());
    final setup = Completer<void>();
    late int requestId;
    final future = registry.invoke(Completer<void>(), () {
      requestId = scopes.single;
      return setup.future;
    });
    final assertion = expectLater(future, throwsA(isA<StateError>()));
    registry.fail(requestId, 'native failure during setup');
    await assertion;
    expect(registry.pendingRequestCount, 0);
    setup.completeError(StateError('late setup failure must be observed'));
    await Future<void>.delayed(Duration.zero);
  });
}
