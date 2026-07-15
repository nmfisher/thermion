// A minimal forward proxy that grants the browser cross-origin isolation
// (crossOriginIsolated === true) by injecting COOP/COEP/CORP response headers.
//
// `dart test -p chrome` serves the test bundle from its own server and offers
// no hook to set response headers, but the threaded (emscripten pthreads)
// Filament WASM build needs SharedArrayBuffer, which the browser gates behind
// cross-origin isolation. We point Chrome at this proxy with:
//
//   --proxy-server=127.0.0.1:<port> --proxy-bypass-list=<-loopback>
//
// so every loopback response Chrome receives gains the isolation headers.
//
// Scope is deliberately narrow: only loopback targets are proxied (external
// telemetry is refused), WebSocket upgrades are relayed untouched (that's the
// package:test result channel), and plain responses get the headers rewritten.
//
// It also doubles as the browser test harness's filesystem bridge (the browser
// has none):
//   * capture sink   — tests POST encoded image bytes to
//     `http://thermion.output/?path=<rel>`; written under the output root
//     (see _handleSink).
//   * asset server   — tests GET `http://thermion.assets/?path=<rel>`; read
//     from the --assets root (see _serveAsset).
//
// Usage: dart run tool/coi_proxy.dart [port] [outRoot] [--assets=<dir>]
//   port          listen port (default 8899)
//   outRoot       directory for captured output (default '.', the proxy's CWD,
//                 so captures land in the same test/output/... tree as native)
//   --assets=<dir> directory to serve asset files from (no default; required
//                 for asset-dependent tests, e.g. --assets=../examples/assets)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _coop = 'Cross-Origin-Opener-Policy: same-origin';
const _coep = 'Cross-Origin-Embedder-Policy: require-corp';
const _corp = 'Cross-Origin-Resource-Policy: cross-origin';

// Out-of-band capture sink (see _handleSink). The browser test harness has no
// filesystem, so capture tests POST their encoded image bytes to this sentinel
// host; we write them under [_outRoot] so they can be inspected on disk.
const _sinkHost = 'thermion.output';
String _outRoot = '.';

// Asset server (see _serveAsset). The browser can't read the local asset files,
// so the harness fetches them from this sentinel host; we read them from
// [_assetsRoot] (set explicitly via --assets=<dir>). Null = serving disabled.
const _assetsHost = 'thermion.assets';
String? _assetsRoot;

Future<void> main(List<String> args) async {
  var port = 8899;
  // Flags (--assets=<dir>) are separated from positionals ([port] [outRoot]).
  final positional = <String>[];
  for (final a in args) {
    if (a.startsWith('--assets=')) {
      _assetsRoot = a.substring('--assets='.length);
    } else {
      positional.add(a);
    }
  }
  if (positional.isNotEmpty) port = int.parse(positional[0]);
  // Optional second positional: directory under which to write captured output.
  // Defaults to the proxy's CWD so web captures land in the same
  // test/output/... tree the native harness writes to.
  if (positional.length > 1) _outRoot = positional[1];

  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
  final assetsNote = _assetsRoot == null
      ? 'assets: disabled'
      : 'assets <- ${Directory(_assetsRoot!).absolute.path}';
  stderr.writeln('coi-proxy listening on 127.0.0.1:$port'
      ' (sink -> ${Directory(_outRoot).absolute.path}, $assetsNote)');
  await for (final client in server) {
    unawaited(_handleClient(client));
  }
}

bool _isLoopback(String host) =>
    host == 'localhost' || host == '127.0.0.1' || host == '[::1]';

Future<void> _handleClient(Socket client) async {
  client.setOption(SocketOption.tcpNoDelay, true);
  final reader = _SocketReader(client);
  try {
    final requestLine = await reader.readLine();
    if (requestLine == null) return _destroy(client);
    final parts = requestLine.split(' ');
    if (parts.length < 2) return _destroy(client);
    final method = parts[0];
    final target = parts[1];
    final version = parts.length > 2 ? parts[2] : 'HTTP/1.1';
    final reqHeaders = await reader.readHeaders();
    stderr.writeln('[req] $method $target');

    if (method == 'CONNECT') {
      final hostPort = target.split(':');
      final host = hostPort.first;
      if (!_isLoopback(host)) return _refuse(client);
      final tport = int.parse(hostPort.length > 1 ? hostPort[1] : '443');
      final upstream = await _connect(host, tport, client);
      if (upstream == null) return;
      client.add(utf8.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
      await client.flush();
      _relay(reader, upstream, client); // tunnel both directions
      return;
    }

    final uri = Uri.parse(target);

    // Out-of-band capture sink: the web harness has no filesystem, so it POSTs
    // captured image bytes here. Write them under _outRoot (mirroring the path
    // the native harness uses) rather than forwarding upstream.
    if (uri.host == _sinkHost) {
      return _handleSink(client, method, uri, reqHeaders, reader);
    }

    // Asset server: serve local asset files the browser can't read directly.
    if (uri.host == _assetsHost) {
      return _serveAsset(client, method, uri);
    }

    if (!_isLoopback(uri.host)) return _refuse(client);
    final tport = uri.hasPort ? uri.port : 80;
    final upstream = await _connect(uri.host, tport, client);
    if (upstream == null) return;
    upstream.setOption(SocketOption.tcpNoDelay, true);

    final isUpgrade =
        reqHeaders.any((h) => h.toLowerCase().startsWith('upgrade:'));

    // Rewrite request target to origin-form and forward the headers.
    final path = uri.path.isEmpty ? '/' : uri.path;
    final pathQuery = uri.hasQuery ? '$path?${uri.query}' : path;
    final out = StringBuffer('$method $pathQuery $version\r\n');
    for (final h in reqHeaders) {
      final lower = h.toLowerCase();
      if (lower.startsWith('proxy-')) continue;
      // Force single response per connection so a plain (non-upgrade) response
      // ends with a clean EOF that we can detect; leave upgrades untouched.
      if (!isUpgrade &&
          (lower.startsWith('connection:') ||
              lower.startsWith('keep-alive:'))) {
        continue;
      }
      out.write('$h\r\n');
    }
    if (!isUpgrade) out.write('Connection: close\r\n');
    out.write('\r\n');
    upstream.add(utf8.encode(out.toString()));

    if (isUpgrade) {
      _relay(reader, upstream, client); // transparent WebSocket relay
      return;
    }

    // Forward any request body, then stream the response with headers injected.
    unawaited(reader.forwardTo(upstream));
    final upReader = _SocketReader(upstream);
    final statusLine = await upReader.readLine();
    stderr.writeln('[resp] $statusLine <- $target');
    if (statusLine == null) return _destroyPair(client, upstream);
    final respHeaders = await upReader.readHeaders();
    final resp = StringBuffer('$statusLine\r\n');
    for (final h in respHeaders) {
      final lower = h.toLowerCase();
      if (lower.startsWith('cross-origin-opener-policy:') ||
          lower.startsWith('cross-origin-embedder-policy:') ||
          lower.startsWith('cross-origin-resource-policy:')) {
        continue;
      }
      resp.write('$h\r\n');
    }
    resp..write('$_coop\r\n')..write('$_coep\r\n')..write('$_corp\r\n')..write('\r\n');
    client.add(utf8.encode(resp.toString()));
    await upReader.forwardTo(client); // completes on upstream EOF (Connection: close)
    // Flush gracefully before teardown: destroy() discards unsent buffered
    // bytes, which truncates large bodies (e.g. the 3.8MB wasm).
    try {
      await client.flush();
      await client.close();
    } catch (_) {}
    _destroy(upstream);
  } catch (e) {
    stderr.writeln('coi-proxy: $e');
    _destroy(client);
  }
}

Future<Socket?> _connect(String host, int port, Socket client) async {
  try {
    return await Socket.connect(host, port);
  } catch (_) {
    client.add(utf8.encode('HTTP/1.1 502 Bad Gateway\r\n\r\n'));
    await client.flush();
    _destroy(client);
    return null;
  }
}

void _refuse(Socket client) {
  client.add(utf8.encode('HTTP/1.1 502 Bad Gateway\r\n\r\n'));
  client.flush().whenComplete(() => _destroy(client));
}

// Writes a POSTed capture body to disk. The relative path comes from the `path`
// query parameter; it is sanitised (leading slashes and `..` segments dropped)
// so writes stay within _outRoot. CORS/isolation headers are added so the
// cross-origin-isolated test page's fetch is allowed to complete.
Future<void> _handleSink(Socket client, String method, Uri uri,
    List<String> reqHeaders, _SocketReader reader) async {
  if (method == 'OPTIONS') return _writeSinkResponse(client, 204, 'No Content');
  if (method != 'POST') {
    return _writeSinkResponse(client, 405, 'Method Not Allowed');
  }

  var contentLength = 0;
  for (final h in reqHeaders) {
    if (h.toLowerCase().startsWith('content-length:')) {
      contentLength = int.tryParse(h.substring(h.indexOf(':') + 1).trim()) ?? 0;
    }
  }
  final body = await reader.readBody(contentLength);

  final rel = _sanitizeRelPath(uri.queryParameters['path'] ?? 'capture.bin');
  if (rel.isEmpty) return _writeSinkResponse(client, 400, 'Bad Request');
  try {
    final file = File([_outRoot, rel].join(Platform.pathSeparator));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(body);
    stderr.writeln('[sink] wrote ${body.length} bytes -> ${file.path}');
    _writeSinkResponse(client, 200, 'OK');
  } catch (e) {
    stderr.writeln('[sink] write failed for $rel: $e');
    _writeSinkResponse(client, 500, 'Internal Server Error');
  }
}

String _sanitizeRelPath(String raw) => raw
    .replaceAll('\\', '/')
    .split('/')
    .where((s) => s.isNotEmpty && s != '.' && s != '..')
    .join(Platform.pathSeparator);

// Serves an asset file (GET http://thermion.assets/?path=<rel>) from
// _assetsRoot. The path is sanitised so reads stay within the root. CORS /
// isolation headers are added so the cross-origin-isolated test page can fetch.
Future<void> _serveAsset(Socket client, String method, Uri uri) async {
  if (method == 'OPTIONS') return _writeSinkResponse(client, 204, 'No Content');
  if (method != 'GET') {
    return _writeSinkResponse(client, 405, 'Method Not Allowed');
  }
  if (_assetsRoot == null) {
    stderr.writeln('[assets] request but no --assets root configured');
    return _writeSinkResponse(client, 503, 'No Asset Root');
  }
  final rel = _sanitizeRelPath(uri.queryParameters['path'] ?? '');
  if (rel.isEmpty) return _writeSinkResponse(client, 400, 'Bad Request');
  final file = File([_assetsRoot!, rel].join(Platform.pathSeparator));
  if (!file.existsSync()) {
    stderr.writeln('[assets] 404 -> ${file.path}');
    return _writeSinkResponse(client, 404, 'Not Found');
  }
  try {
    final bytes = await file.readAsBytes();
    stderr.writeln('[assets] served ${bytes.length} bytes <- ${file.path}');
    final head = StringBuffer('HTTP/1.1 200 OK\r\n')
      ..write('Access-Control-Allow-Origin: *\r\n')
      ..write('Content-Type: application/octet-stream\r\n')
      ..write('$_coop\r\n')
      ..write('$_coep\r\n')
      ..write('$_corp\r\n')
      ..write('Content-Length: ${bytes.length}\r\n')
      ..write('Connection: close\r\n')
      ..write('\r\n');
    client.add(utf8.encode(head.toString()));
    client.add(bytes);
    await client.flush();
    await client.close();
  } catch (e) {
    stderr.writeln('[assets] read failed for ${file.path}: $e');
    _writeSinkResponse(client, 500, 'Internal Server Error');
  }
}

void _writeSinkResponse(Socket client, int code, String reason) {
  final resp = StringBuffer('HTTP/1.1 $code $reason\r\n')
    ..write('Access-Control-Allow-Origin: *\r\n')
    ..write('Access-Control-Allow-Methods: POST, OPTIONS\r\n')
    ..write('Access-Control-Allow-Headers: *\r\n')
    ..write('$_coop\r\n')
    ..write('$_coep\r\n')
    ..write('$_corp\r\n')
    ..write('Content-Length: 0\r\n')
    ..write('Connection: close\r\n')
    ..write('\r\n');
  client.add(utf8.encode(resp.toString()));
  client.flush().whenComplete(() => _destroy(client));
}

// Full-duplex relay: buffered front of `reader` -> `upstream`, and
// `upstream` -> `client`. Tears the pair down when either side ends.
void _relay(_SocketReader reader, Socket upstream, Socket client) {
  reader.forwardTo(upstream).whenComplete(() => _destroyPair(client, upstream));
  upstream.listen(
    client.add,
    onDone: () => _destroyPair(client, upstream),
    onError: (_) => _destroyPair(client, upstream),
    cancelOnError: true,
  );
}

void _destroy(Socket s) {
  try {
    s.destroy();
  } catch (_) {}
}

void _destroyPair(Socket a, Socket b) {
  _destroy(a);
  _destroy(b);
}

/// Pull-based reader over a single-subscription [Socket] stream. Reads request
/// lines/headers, then hands the remaining byte stream off via [forwardTo].
class _SocketReader {
  final StreamIterator<Uint8List> _it;
  final List<int> _buf = [];

  _SocketReader(Stream<Uint8List> stream) : _it = StreamIterator(stream);

  Future<bool> _fill() async {
    if (await _it.moveNext()) {
      _buf.addAll(_it.current);
      return true;
    }
    return false;
  }

  Future<String?> readLine() async {
    while (true) {
      for (var i = 0; i + 1 < _buf.length; i++) {
        if (_buf[i] == 13 && _buf[i + 1] == 10) {
          final line = ascii.decode(_buf.sublist(0, i), allowInvalid: true);
          _buf.removeRange(0, i + 2);
          return line;
        }
      }
      if (!await _fill()) return _buf.isEmpty ? null : '';
    }
  }

  Future<List<String>> readHeaders() async {
    final headers = <String>[];
    while (true) {
      final line = await readLine();
      if (line == null || line.isEmpty) break;
      headers.add(line);
    }
    return headers;
  }

  /// Reads exactly [length] body bytes (buffered read-ahead first, then stream).
  Future<Uint8List> readBody(int length) async {
    final out = BytesBuilder();
    while (out.length < length) {
      if (_buf.isEmpty && !await _fill()) break;
      final need = length - out.length;
      if (_buf.length <= need) {
        out.add(_buf);
        _buf.clear();
      } else {
        out.add(_buf.sublist(0, need));
        _buf.removeRange(0, need);
      }
    }
    return out.toBytes();
  }

  Future<void> forwardTo(Socket dest) async {
    try {
      if (_buf.isNotEmpty) {
        dest.add(Uint8List.fromList(_buf));
        _buf.clear();
      }
      while (await _it.moveNext()) {
        dest.add(_it.current);
      }
    } catch (_) {
      // peer closed mid-stream; nothing to do
    }
  }
}
