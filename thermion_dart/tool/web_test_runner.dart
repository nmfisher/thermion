// Single entry point to run the package:test suite on Chrome (dart2js) for the
// thermion_dart web build.
//
// For each target test it stamps out the per-file HTML host wrapper that
// package:test requires (which loads the Filament WASM module, provides the
// OffscreenCanvas the render-thread worker is handed, and links the test via
// <link rel="x-dart-test">), ensures the COOP/COEP proxy is running (see
// tool/coi_proxy.dart), runs `dart test -p chrome`, then prints a per-file
// pass/fail/skip summary parsed from the JSON reporter.
//
// Usage:
//   dart run tool/web_test_runner.dart [options] [test/foo_tests.dart ...]
//
// With no file arguments, runs every test/*_test.dart and test/*_tests.dart.
//
// Options:
//   --port=N         proxy port (default 8899)
//   --timeout=DUR    per-test timeout passed to `dart test` (default 120s)
//   --concurrency=N  parallel suites (default 1 — browser + GPU friendly)
//   --assets=DIR     directory of asset files to serve (e.g. ../examples/assets);
//                    passed to the proxy this tool starts. Required for tests
//                    that load materials/textures/glTF/IBL/skybox assets.
//   --no-proxy       assume the proxy is already running; do not start one
//   --clean          delete the wrappers this run generated when finished
//   -N <regex>       forwarded to `dart test --name=<regex>` (also --name=<regex>)
//   -n <substring>   forwarded to `dart test --plain-name=<sub>` (also --plain-name=<sub>)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Must match emscripten's OFFSCREENCANVASES_TO_PTHREAD target id.
const _canvasId = 'thermion_canvas';

String _wrapperHtml(String testFileName) =>
    '''<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>$testFileName</title>

    <!-- emscripten Filament module factory (built by `make wasm`, copied to test/). -->
    <script src="thermion_dart.js"></script>

    <!-- Standard package:test bootstrap. These must be STATIC scripts: dart.js
         locates itself via document.currentScript to find the compiled test. -->
    <link rel="x-dart-test" href="$testFileName" />
    <script src="packages/test/dart.js"></script>

    <style>
      html, body { margin: 0; padding: 0; }
    </style>
  </head>
  <body>
    <!-- The pthreads build transfers this canvas as an OffscreenCanvas to the
         render-thread worker; the id must match exactly. -->
    <canvas id="$_canvasId" width="512" height="512"></canvas>

    <script>
      // Kick off module init now that the canvas exists, and publish a readiness
      // promise the Dart side awaits (initTestBindings) before touching bindings.
      globalThis.__thermionReady = thermion_dart()
        .then(function (module) { globalThis.thermion_dart = module; })
        .catch(function (err) { console.error("[coi-diag] module init failed:", err); });
    </script>
  </body>
</html>
''';

Future<bool> _portOpen(int port) async {
  try {
    final s = await Socket.connect(InternetAddress.loopbackIPv4, port,
        timeout: const Duration(milliseconds: 500));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> _waitForPort(int port, Duration max) async {
  final deadline = DateTime.now().add(max);
  while (DateTime.now().isBefore(deadline)) {
    if (await _portOpen(port)) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

Future<void> main(List<String> args) async {
  var port = 8899;
  var timeout = '120s';
  var concurrency = 1;
  var manageProxy = true;
  var clean = false;
  String? assets;
  final files = <String>[];
  // Test-name filters passed straight through to `dart test`. Supports the
  // same forms as the underlying runner: --name=<regex> / -N <regex>
  // (substring-as-regex) and --plain-name=<str> / -n <str> (substring match).
  final passthrough = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--port=')) {
      port = int.parse(a.substring('--port='.length));
    } else if (a.startsWith('--timeout=')) {
      timeout = a.substring('--timeout='.length);
    } else if (a.startsWith('--concurrency=')) {
      concurrency = int.parse(a.substring('--concurrency='.length));
    } else if (a.startsWith('--assets=')) {
      assets = a.substring('--assets='.length);
    } else if (a == '--no-proxy') {
      manageProxy = false;
    } else if (a == '--clean') {
      clean = true;
    } else if (a.startsWith('--name=') || a.startsWith('--plain-name=')) {
      passthrough.add(a);
    } else if (a == '-N' || a == '--name') {
      if (i + 1 >= args.length) {
        stderr.writeln('$a requires a value');
        exit(64);
      }
      passthrough.addAll(['--name', args[++i]]);
    } else if (a == '-n' || a == '--plain-name') {
      if (i + 1 >= args.length) {
        stderr.writeln('$a requires a value');
        exit(64);
      }
      passthrough.addAll(['--plain-name', args[++i]]);
    } else if (a.startsWith('--')) {
      stderr.writeln('unknown option: $a');
      exit(64);
    } else {
      files.add(a);
    }
  }

  if (!Directory('test').existsSync()) {
    stderr.writeln('Run from the thermion_dart package root (no ./test found).');
    exit(1);
  }

  // 1. Resolve target test files.
  final targets = <String>[];
  if (files.isNotEmpty) {
    targets.addAll(files);
  } else {
    for (final e in Directory('test').listSync()) {
      if (e is File &&
          (e.path.endsWith('_test.dart') || e.path.endsWith('_tests.dart'))) {
        targets.add(e.path);
      }
    }
    targets.sort();
  }
  if (targets.isEmpty) {
    stderr.writeln('No test files found.');
    exit(1);
  }

  // 2. Generate the HTML wrappers.
  final generated = <File>[];
  for (final t in targets) {
    final name = t.split(Platform.pathSeparator).last; // foo_tests.dart
    final base = name.substring(0, name.length - '.dart'.length);
    final html = File('test/$base.html');
    final existed = html.existsSync();
    html.writeAsStringSync(_wrapperHtml(name));
    if (!existed) generated.add(html);
  }
  stderr.writeln('Wrappers: ${targets.length} written '
      '(${generated.length} new).');

  // 3. Ensure the COOP/COEP proxy is up.
  Process? proxy;
  if (await _portOpen(port)) {
    stderr.writeln('Proxy: reusing listener on $port.');
    if (assets != null) {
      stderr.writeln('  note: --assets is ignored when reusing an existing '
          'proxy; restart it with --assets=$assets to serve those assets.');
    }
  } else if (manageProxy) {
    stderr.writeln(
      'Proxy: starting coi_proxy on $port'
      '${assets != null ? ' (assets <- $assets)' : ''} ...',
    );
    proxy = await Process.start('dart', [
      'run',
      'tool/coi_proxy.dart',
      '$port',
      if (assets != null) '--assets=$assets',
    ], mode: ProcessStartMode.normal);
    unawaited(proxy.stdout.drain<void>());
    unawaited(proxy.stderr.drain<void>());
    if (!await _waitForPort(port, const Duration(seconds: 120))) {
      stderr.writeln('Proxy did not bind on $port; aborting.');
      proxy.kill();
      exit(1);
    }
    stderr.writeln('Proxy: listening on $port.');
  } else {
    stderr.writeln('Proxy: nothing on $port and --no-proxy set. '
        'Start tool/coi_proxy.dart $port first.');
    exit(1);
  }

  // 4. Run the tests (live output) while collecting machine-readable results.
  final jsonPath = 'test/.web_test_results.json';
  var exitCode = 1;
  try {
    final proc = await Process.start('dart', [
      'test',
      '-p',
      'chrome',
      '-j',
      '$concurrency',
      '--timeout',
      timeout,
      '--reporter=expanded',
      '--file-reporter=json:$jsonPath',
      ...passthrough,
      ...targets,
    ], mode: ProcessStartMode.inheritStdio);
    exitCode = await proc.exitCode;
  } finally {
    proxy?.kill();
  }

  // 5. Per-file summary.
  _printSummary(jsonPath, targets);

  // 6. Optional cleanup of freshly generated wrappers.
  if (clean) {
    for (final f in generated) {
      if (f.existsSync()) f.deleteSync();
    }
    stderr.writeln('Removed ${generated.length} generated wrappers.');
  }

  exit(exitCode);
}

void _printSummary(String jsonPath, List<String> targets) {
  final f = File(jsonPath);
  if (!f.existsSync()) {
    stderr.writeln('\nNo JSON results at $jsonPath (did the run start?).');
    return;
  }
  final suitePath = <int, String>{}; // suiteID -> path
  final testToSuite = <int, int>{}; // testID -> suiteID
  final testNames = <int, String>{}; // testID -> name
  final stats = <String, List<int>>{}; // path -> [pass, fail, skip]
  final failures = <String, List<String>>{}; // path -> failing test names

  for (final line in f.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    Map<String, dynamic> ev;
    try {
      ev = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
    switch (ev['type']) {
      case 'suite':
        final s = ev['suite'] as Map<String, dynamic>;
        suitePath[s['id'] as int] = (s['path'] as String?) ?? '?';
        break;
      case 'testStart':
        final t = ev['test'] as Map<String, dynamic>;
        testToSuite[t['id'] as int] = t['suiteID'] as int;
        testNames[t['id'] as int] = (t['name'] as String?) ?? '?';
        break;
      case 'testDone':
        if (ev['hidden'] == true) break;
        final id = ev['testID'] as int;
        final path = suitePath[testToSuite[id]] ?? '?';
        final s = stats.putIfAbsent(path, () => [0, 0, 0]);
        if (ev['skipped'] == true) {
          s[2]++;
        } else if (ev['result'] == 'success') {
          s[0]++;
        } else {
          s[1]++;
          failures.putIfAbsent(path, () => []).add(testNames[id] ?? '?');
        }
        break;
    }
  }

  stderr.writeln('\n=== web test summary ===');
  var totP = 0, totF = 0, totS = 0, filesWithFailures = 0;
  for (final path in targets) {
    final s = stats[path];
    if (s == null) {
      stderr.writeln('  $path : (no results — load/compile failure?)');
      filesWithFailures++;
      continue;
    }
    totP += s[0];
    totF += s[1];
    totS += s[2];
    final flag = s[1] > 0 ? 'FAIL' : 'ok';
    stderr.writeln('  [$flag] $path : +${s[0]} ~${s[2]} -${s[1]}');
    if (s[1] > 0) {
      filesWithFailures++;
      for (final name in failures[path] ?? const <String>[]) {
        stderr.writeln('         - $name');
      }
    }
  }
  stderr.writeln('------------------------');
  stderr.writeln('  files: ${targets.length}  with failures: $filesWithFailures');
  stderr.writeln('  tests: +$totP passed  ~$totS skipped  -$totF failed');
}
