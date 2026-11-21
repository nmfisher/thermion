// Runs the matrix buffer Emscripten fixture in headless Chrome with COOP/COEP.
// Usage: dart run run_web_matrix_test.dart BUILD_DIR [CHROME_EXECUTABLE]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) throw ArgumentError('Expected directory containing index.html and the WASM module');
  final root = Directory(args.first).absolute;
  final chrome = args.length > 1 ? args[1] : '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  final profile = await Directory.systemTemp.createTemp('thermion-worker-test-');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    response.headers.set('Cross-Origin-Opener-Policy', 'same-origin');
    response.headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
    final name = request.uri.pathSegments.lastOrNull ?? '';
    if (name.isEmpty) {
      response.headers.contentType = ContentType.html;
      final host = File('${root.path}/index.html');
      response.write(
        await host.exists()
            ? await host.readAsString()
            : '<!doctype html><script>globalThis.testResult="pending";</script><script src="test.js"></script>',
      );
    } else if (RegExp(r'^[a-zA-Z0-9_-]+(?:\.[a-zA-Z0-9_-]+)*\.(js|wasm|ktx)$').hasMatch(name)) {
      final file = File('${root.path}/$name');
      if (await file.exists()) {
        response.headers.contentType = ContentType.parse(
          name.endsWith('.wasm')
              ? 'application/wasm'
              : name.endsWith('.ktx')
              ? 'application/octet-stream'
              : 'text/javascript',
        );
        await response.addStream(file.openRead());
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  });
  Process? process;
  WebSocket? socket;
  final client = HttpClient();
  try {
    process = await Process.start(chrome, [
      '--headless=new',
      '--no-first-run',
      '--no-default-browser-check',
      '--remote-debugging-port=0',
      '--user-data-dir=${profile.path}',
      'http://127.0.0.1:${server.port}/',
    ]);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    final portFile = File('${profile.path}/DevToolsActivePort');
    while (!await portFile.exists()) {
      if (DateTime.now().isAfter(deadline)) throw TimeoutException('Chrome did not start');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final port = (await portFile.readAsLines()).first;
    final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/json/list'));
    final targets = jsonDecode(await utf8.decoder.bind(await request.close()).join()) as List;
    final page = targets.firstWhere((target) => target['type'] == 'page');
    socket = await WebSocket.connect(page['webSocketDebuggerUrl'] as String);
    final pending = <int, Completer<Map<String, dynamic>>>{};
    socket.listen((data) {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      pending.remove(message['id'])?.complete(message);
    });
    var id = 0;
    while (DateTime.now().isBefore(deadline)) {
      final result = Completer<Map<String, dynamic>>();
      pending[++id] = result;
      socket.add(
        jsonEncode({
          'id': id,
          'method': 'Runtime.evaluate',
          'params': {'expression': 'globalThis.testResult', 'returnByValue': true},
        }),
      );
      final response = await result.future.timeout(const Duration(seconds: 5));
      final value = response['result']?['result']?['value'];
      if (value is String && value.startsWith('FAIL')) throw StateError(value);
      if (value is String && value.startsWith('PASS')) {
        stdout.writeln(value);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('Browser fixture did not finish');
  } finally {
    await socket?.close();
    process?.kill();
    if (process != null) await process.exitCode;
    client.close(force: true);
    await server.close(force: true);
    await profile.delete(recursive: true);
  }
}
