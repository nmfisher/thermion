import 'package:thermion_dart/thermion_dart.dart';

/// Web stub for the assimp-backed load_via_assimp example.
///
/// assimp_dart is a native-only package (dart:ffi against libassimp), so the
/// glue in load_via_assimp_io.dart is conditionally excluded from web builds.
/// The web gallery only renders the composite `galleryScenes`, so this stub
/// exists purely to keep the example registry web-compilable.
Future<void> setupLoadViaAssimp(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  throw UnsupportedError(
    'load_via_assimp requires assimp_dart, which is native-only. Run it from '
    'the headless CLI runner (examples/dart/headless_runner).',
  );
}
