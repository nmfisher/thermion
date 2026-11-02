// This app intentionally exits while the plugin is alive. Run it through
// run.ps1, which checks the real process exit code after DLL teardown.
// flutter build windows --release --target integration_test/windows_process_exit/app.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

void main(List<String> arguments) {
  runZonedGuarded(() async {
    if (!Platform.isWindows || arguments.length != 2) {
      throw ArgumentError(
          'Expected Windows, shutdown mode, and readiness file');
    }
    final mode = arguments[0];
    final ready = File(arguments[1]);
    if (!['no-viewer', 'dart-exit', 'window-close'].contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      stderr.writeln(details);
      exit(2);
    };
    runApp(const ColoredBox(color: Color(0xFF204060)));
    await WidgetsBinding.instance.endOfFrame;

    if (mode == 'no-viewer') {
      ready.writeAsStringSync('flutter-ready', flush: true);
      exit(0);
    }

    final viewer = await ThermionFlutterPlugin.createViewer();
    final plugin = ThermionFlutterPlugin.instance;
    // Render explicitly so readiness proves a completed render + publication,
    // rather than relying on a startup callback or an arbitrary delay.
    plugin.pauseFrameScheduler();
    final texture =
        await plugin.createTextureAndBindToView(viewer.view, 64, 64);
    if (texture == null || texture.flutterTextureId < 0) {
      throw StateError('Failed to allocate the Windows rendering surface');
    }
    runApp(Center(
      child: SizedBox(
        width: 64,
        height: 64,
        child: Texture(textureId: texture.flutterTextureId),
      ),
    ));
    // One publication starts the lazy blit worker and is sufficient to trigger
    // the shutdown regression. Sustained blitting is a separate graphics test.
    await viewer.renderSingleFrame();
    await texture.markTextureFrameAvailable();
    await WidgetsBinding.instance.endOfFrame;

    if (mode == 'dart-exit') {
      ready.writeAsStringSync('frame-published', flush: true);
      // Do not dispose the viewer, texture, engine, or plugin before this call.
      exit(0);
    }

    // The control exercises orderly application cleanup, then lets window
    // destruction stop/join the native plugin's still-running blit worker.
    runApp(const SizedBox.expand());
    await WidgetsBinding.instance.endOfFrame;
    await plugin.destroyTextureForView(viewer.view);
    await viewer.dispose();
    await viewer.app.destroy();
    ready.writeAsStringSync('viewer-disposed', flush: true);
    // run.ps1 sends a normal window-close request after observing readiness.
  }, (error, stack) {
    stderr.writeln('$error\n$stack');
    exit(2);
  });
}
