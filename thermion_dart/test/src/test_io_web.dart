import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:thermion_dart/thermion_dart.dart' show Backend;
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart'
    show NativeLibrary;

export 'dart:typed_data';

/// On web the JS-interop bindings must be pointed at the emscripten module
/// (loaded onto `globalThis.thermion_dart` by the host page) before use. The
/// host page exposes `globalThis.__thermionReady`, a promise that resolves once
/// the module is instantiated; we wait for (and on) it before binding.
Future<void> initTestBindings() async {
  var ready = globalContext['__thermionReady'];
  // The host page sets the promise during body parse; the compiled test may
  // reach here first, so poll briefly for it to appear.
  for (var i = 0; ready == null && i < 2000; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    ready = globalContext['__thermionReady'];
  }
  if (ready != null) {
    await (ready as JSPromise).toDart;
  }
  NativeLibrary.initBindings("thermion_dart");
}

/// WebGL is the only backend available in the browser.
Backend get defaultTestBackend => Backend.OPENGL;

bool get platformIsWindows => false;
bool get platformIsLinux => false;
bool get isWeb => true;
String get currentDirPath => ".";

/// Sentinel host the COI proxy serves local asset files from (--assets dir).
const _assetsHost = 'thermion.assets';

/// Loads bytes for a resource. Real http(s) URLs are fetched directly; asset
/// references (file:// URIs, or local paths under the test assets dir) are
/// routed to the COI proxy's asset server, which reads them from its --assets
/// directory — the browser has no filesystem of its own.
Future<Uint8List> loadResourceBytes(String uri) async {
  final Uri target;
  if (uri.startsWith('http://') || uri.startsWith('https://')) {
    target = Uri.parse(uri);
  } else {
    target = Uri.http(_assetsHost, '/', {'path': _assetRelPath(uri)});
  }
  final response = await http.get(target);
  if (response.statusCode != 200) {
    throw Exception('Failed to load resource "$uri" '
        '(HTTP ${response.statusCode} via ${target.host}${target.path})');
  }
  return response.bodyBytes;
}

/// Reduces an asset URI to its path relative to the test assets directory. The
/// web TestHelper computes assetsDir as ".../examples/assets", so any asset URI
/// (optionally file://-prefixed) contains "examples/assets/<rel>"; <rel> is
/// what the proxy resolves against its --assets dir. Falls back to the basename.
String _assetRelPath(String uri) {
  final path =
      uri.startsWith('file://') ? uri.substring('file://'.length) : uri;
  const marker = 'examples/assets/';
  final i = path.indexOf(marker);
  if (i >= 0) return path.substring(i + marker.length);
  return path.split('/').where((s) => s.isNotEmpty).last;
}

Uint8List readFileBytesSync(String path) => throw UnsupportedError(
    "Synchronous file reads are not supported on web: $path. "
    "Use loadResourceBytes (async, HTTP-backed) instead.");

/// Sentinel host the COI proxy intercepts as its capture sink. POSTs here are
/// written to disk by `tool/coi_proxy.dart` rather than forwarded upstream.
const _captureSinkHost = 'thermion.output';

/// No filesystem on web, so captured output is persisted out-of-band: POST the
/// encoded bytes to the COI proxy's capture sink, which writes them under its
/// output root (by default the same `test/output/...` tree the native harness
/// uses). Best-effort — logs a warning if the sink is unreachable (e.g. the
/// proxy isn't running) rather than failing the test.
Future<void> writeFileBytes(String path, Uint8List bytes) async {
  try {
    final res = await http.post(
      Uri.http(_captureSinkHost, '/', {'path': path}),
      body: bytes,
    );
    if (res.statusCode != 200) {
      print('[capture-sink] unexpected status ${res.statusCode} for $path');
    }
  } catch (e) {
    print('[capture-sink] failed to persist "$path": $e — is '
        'tool/coi_proxy.dart running?');
  }
}

void createDirSync(String path) {}

/// Returns a dummy file URI. The package-root path is only used to derive
/// filesystem locations for assets/output, which are unused on web (assets are
/// fetched over HTTP, output is dropped). Must be a `file:` URI so callers can
/// safely invoke `.toFilePath()`.
Uri findPackageRoot(String packageName) => Uri.file("/");
