import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/void_callback_registry.dart';

void main() {
  for (final mode in ['completed', 'pending', 'dispatch-failure']) {
    test('callback listener permits process exit: $mode', () async {
      final process = await Process.start(Platform.resolvedExecutable, ['test/fixtures/void_callback_exit.dart', mode]);
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      try {
        final code = await process.exitCode.timeout(const Duration(seconds: 10));
        expect(code, 0, reason: await errors);
        expect(await output, switch (mode) {
          'pending' => allOf(contains('completed 50'), contains('completed 200')),
          'dispatch-failure' => contains('dispatch failed'),
          _ => contains('completed'),
        });
      } finally {
        process.kill();
        await process.exitCode;
        await Future.wait([output, errors]);
      }
    });
  }

  test('dispatch failure preserves keep-alive even after a later successful request', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'test/fixtures/void_callback_exit.dart',
      'failed-retained',
    ]);
    final ready = Completer<void>();
    final output = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
      if (line == 'completed after failure') ready.complete();
    });
    final errors = process.stderr.transform(utf8.decoder).join();
    try {
      await ready.future.timeout(const Duration(seconds: 10));
      // A dispatch error cannot prove native completion, even if another
      // request succeeds later. Retain the previous keep-alive behavior.
      await expectLater(process.exitCode.timeout(const Duration(milliseconds: 200)), throwsA(isA<TimeoutException>()));
    } finally {
      process.kill();
      await process.exitCode;
      await output;
      await errors;
    }
  });

  test('cannot close while callbacks are pending', () async {
    final registry = VoidCallbackRegistry();
    late void Function() complete;
    final pending = registry.invoke((id, callback) {
      complete = () => callback.asFunction<void Function(int)>()(id);
    });
    expect(registry.close, throwsStateError);
    complete();
    await pending;
    registry.close();
  });

  test('completed void callbacks are removed from the request registry', () async {
    final registry = VoidCallbackRegistry();
    late int completedRequestId;
    late void Function(int) invokeCallback;

    await registry.invoke((requestId, nativeCallback) {
      completedRequestId = requestId;
      invokeCallback = nativeCallback.asFunction<void Function(int)>();
      invokeCallback(requestId);
    });
    expect(registry.pendingRequestCount, 0);

    // A late or duplicate native callback must not find and complete the old
    // Completer again. The test framework will fail this test if the listener
    // throws an asynchronous "Future already completed" error.
    invokeCallback(completedRequestId);
    await Future<void>.delayed(Duration.zero);
    registry.close();
  });
}
