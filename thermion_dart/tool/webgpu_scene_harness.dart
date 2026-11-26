// Browser harness for scripts/check-webgpu-canvas.py: hosts the WebGPU scene
// package:test suite (test/chrome_webgpu_scene_test.dart) in a plain static
// page — no `dart test` runner — and reports the outcome back to the harness
// server as POST /result {passed, message}. This keeps ONE source of truth
// for the scene asserts while build-filament.yml's verify-webgpu-engine job
// keeps its top-level-page Chromium check.
//
// Compiled by that job:
//   dart compile js tool/webgpu_scene_harness.dart -o <site>/app.js
// The page loads the engine (publishing __thermionReady), then app.js as a
// plain deferred script; the suite awaits __thermionReady itself.
//
// Uses package:test_core's runner engine directly (the same machinery
// `dart test` drives) because the declarer/invoker layer a browser test
// normally runs on requires the package:test websocket host.
// ignore_for_file: deprecated_member_use, implementation_imports
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test_api/backend.dart' show Declarer, Runtime, Status, SuitePlatform;
import 'package:test_api/src/backend/state.dart' show Result;
import 'package:test_core/backend.dart' show SuiteConfiguration;
import 'package:test_core/src/runner/engine.dart';
import 'package:test_core/src/runner/plugin/environment.dart';
import 'package:test_core/src/runner/runner_suite.dart';

import '../test/chrome_webgpu_scene_test.dart' as scene;

Future<void> main() async {
  var passed = false;
  final messages = <String>[];
  try {
    final declarer = Declarer();
    declarer.declare(scene.main);
    final suite = RunnerSuite(
      const PluginEnvironment(),
      SuiteConfiguration.empty,
      declarer.build(),
      SuitePlatform(Runtime.chrome),
      path: 'chrome_webgpu_scene_test.dart',
    );
    final engine = Engine();
    engine.suiteSink.add(suite);
    engine.suiteSink.close();
    engine.onTestStarted.listen((liveTest) {
      liveTest.onStateChange.listen((state) {
        if (state.status == Status.complete && state.result != Result.success) {
          messages.add('${liveTest.test.name}: ${state.result}');
        }
      });
      liveTest.onError.listen((error) {
        messages.add('${liveTest.test.name}: ${error.error}\n${error.stackTrace}');
      });
      liveTest.onMessage.listen((message) => messages.add(message.text));
    });
    passed = (await engine.run()) ?? false;
    if (passed) messages.insert(0, 'Chromium WebGPU scene test passed.');
  } catch (error, stack) {
    passed = false;
    messages.add('$error\n$stack');
  }
  await (globalContext.callMethod(
            'fetch'.toJS,
            '/result'.toJS,
            {
                  'method': 'POST',
                  'body': jsonEncode({'passed': passed, 'message': messages.join('\n')}),
                }.jsify()
                as JSObject,
          )
          as JSPromise)
      .toDart;
}
