// ignore_for_file: avoid_print, implementation_imports, unnecessary_import

import 'dart:async';
import 'dart:ffi';
import 'dart:io' show File, Platform;
import 'dart:isolate';
import 'dart:math';

import 'package:sdl3/sdl3.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

/// Thermion in a "Flutter Zero" app: a plain Dart process with no Flutter
/// engine, using raw SDL3 for windowing/input and `thermion_dart` (not
/// `thermion_flutter`) for rendering.
///
/// What this demonstrates, in order:
///
/// 1.  Boot an SDL3 window (no Flutter engine, no widgets).
/// 2.  Extract the window's *native* surface handle — the CAMetalLayer on
///     macOS, the X11 Window XID on Linux — and hand it to Filament.
/// 3.  Bootstrap `FFIFilamentApp`, create a swapchain over that surface, and
///     attach a `ThermionViewerFFI` to it.
/// 4.  Build a small scene: two direct lights and a cube.
/// 5.  Drive continuous rendering with Thermion's port-based
///     `FrameScheduler`, orbiting the camera and pumping SDL events.
///
/// IMPORTANT — frames are not free-running on native: `setRendering(true)`
/// only attaches a view to a swapchain, it does not start a render loop.
/// Something must call `FilamentApp.render()` every frame. Under Flutter,
/// Thermion hooks the engine's vsync; in a Flutter Zero app *you* own the
/// frame pacing. Here we use the port-based `FrameScheduler` (a native
/// thread posting one tick per frame to a Dart `ReceivePort`); the
/// README covers the alternatives.
///
/// Run:
///   dart run lib/main.dart                          (macOS)
///   xvfb-run -s "-screen 0 800x600x24" \
///     dart run lib/main.dart                        (Linux/headless)
///
/// Smoke test (quit after 120 frames instead of waiting for input):
///   dart run lib/main.dart --frames=120
const _width = 800;
const _height = 600;
const _targetFps = 60;

Future<void> main(List<String> args) async {
  // Optional smoke-test escape hatch: `--frames=N` quits after N frames.
  int? maxFrames;
  for (final arg in args) {
    if (arg.startsWith('--frames=')) {
      maxFrames = int.tryParse(arg.substring('--frames='.length));
    }
  }

  if (!Platform.isMacOS && !Platform.isLinux) {
    print(
      'This example supports macOS and Linux '
      '(got ${Platform.operatingSystem}). Windows would follow the same '
      'pattern with a DXGI swapchain handle.',
    );
    return;
  }

  // 1. SDL3 setup ----------------------------------------------------------
  final sdlPath = _findSdlPath();
  if (sdlPath != null) {
    SdlDynamicLibraryService().set('sdl', sdlPath);
  }

  if (!sdlInit(SDL_INIT_VIDEO)) {
    print('Failed to initialize SDL: ${sdlGetError()}');
    return;
  }

  var windowFlags = SDL_WINDOW_RESIZABLE;
  if (Platform.isMacOS) windowFlags |= SDL_WINDOW_METAL;

  final window = SdlWindowEx.create(
    title: 'Thermion + Flutter Zero (SDL3)',
    w: _width,
    h: _height,
    flags: windowFlags,
  );
  if (window == nullptr) {
    print('Failed to create window: ${sdlGetError()}');
    sdlQuit();
    return;
  }

  // 2. Native surface acquisition -------------------------------------------
  // Filament does not know about SDL; it renders to a platform surface.
  // We dig the raw handle out of the SDL window and wrap it in a Pointer.
  final Pointer<NativeType> handle;
  void Function()? releaseNativeView;

  if (Platform.isMacOS) {
    final result = _acquireMetalLayer(window, sdlPath!);
    if (result == null) {
      window.destroy();
      sdlQuit();
      return;
    }
    handle = result.layer;
    releaseNativeView = result.release;
  } else {
    // Linux: hand Filament the X11 Window XID directly — Filament's Vulkan
    // backend on Linux treats the swapchain handle as an X11 Window
    // (see filament/SwapChain.h).
    final props = sdlGetWindowProperties(window);
    final xid = sdlGetNumberProperty(
      props,
      SDL_PROP_WINDOW_X11_WINDOW_NUMBER,
      0,
    );
    if (xid == 0) {
      print(
        'No X11 Window XID (running under Wayland?). '
        'This example expects an X11/XWayland session.',
      );
      window.destroy();
      sdlQuit();
      return;
    }
    handle = Pointer.fromAddress(xid);
  }

  print(
    'SDL3 window created. Native surface @ 0x'
    '${handle.address.toRadixString(16)}',
  );

  // 3. Filament bootstrap ----------------------------------------------------
  await FFIFilamentApp.create();

  final swapChain = await FilamentApp.instance!.createSwapChain(handle.cast());

  final viewer = ThermionViewerFFI(
    app: FilamentApp.instance! as FFIFilamentApp,
  );
  await viewer.initialized;
  await FilamentApp.instance!.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setFrustumCullingEnabled(false);
  await viewer.setViewport(_width, _height);
  await viewer.setBackgroundColor(0.117, 0.117, 0.180, 1.0);

  // 4. Scene: two lights and a cube at the origin ---------------------------
  // Key light (warm). Intensity is kept below what would clip LDR output
  // to flat white.
  await viewer.addDirectLight(
    DirectLight.sun(
      intensity: 25000.0,
      color: const LinearColor(1.0, 0.95, 0.85),
      direction: Vector3(-0.4, -0.7, -0.6)..normalize(),
      castShadows: false,
    ),
  );
  // Fill light from the opposite side so back faces are not pitch black.
  await viewer.addDirectLight(
    DirectLight.sun(
      intensity: 8000.0,
      color: const LinearColor(0.6, 0.7, 1.0),
      direction: Vector3(0.5, -0.3, 0.5)..normalize(),
      castShadows: false,
    ),
  );

  // `createGeometry` without explicit materials uses the default ubershader
  // material — PBR-lit white.
  await viewer.createGeometry(GeometryUtils.cube());

  // Perspective projection with default lens parameters.
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection();

  final stopwatch = Stopwatch()..start();

  // 5. Port-based frame loop -------------------------------------------------
  // `FrameScheduler_startWithPort` spawns a native scheduler thread that
  // posts an int to `sendPort.nativePort` once per frame (at `_targetFps`).
  // Each tick wakes Dart's event loop; the listener below pumps SDL events,
  // moves the camera, and renders.
  FrameScheduler_initDartApi(NativeApi.initializeApiDLData);

  final framePort = ReceivePort();
  final quit = Completer<void>();
  var frames = 0;

  framePort.listen((_) async {
    if (quit.isCompleted) return;

    // Pump SDL events: close window or Escape quits.
    SdlxEvent? event;
    while ((event = sdlxPollEvent()) != null) {
      if (event is SdlxQuitEvent) {
        if (!quit.isCompleted) quit.complete();
        return;
      }
      if (event is SdlxKeyboardEvent &&
          event.type == SdlkEvent.keyDown &&
          event.scancode == SdlkScancode.escape) {
        if (!quit.isCompleted) quit.complete();
        return;
      }
    }

    // Orbit the camera around the cube (one revolution every 12 s).
    final t = stopwatch.elapsedMilliseconds / 1000.0;
    final angle = t * (2 * pi / 12);
    await camera.lookAt(Vector3(4 * sin(angle), 2.5, 4 * cos(angle)));

    await FilamentApp.instance!.render();
    frames++;
    if (frames % _targetFps == 0) print('  frame $frames');
    if (maxFrames != null && frames >= maxFrames && !quit.isCompleted) {
      print('Reached --frames=$maxFrames, quitting.');
      quit.complete();
    }
  });

  FrameScheduler_startWithPort(framePort.sendPort.nativePort, _targetFps);
  print('Rendering. Press Escape or close the window to quit.');

  await quit.future;

  // 6. Cleanup ----------------------------------------------------------------
  print('Shutting down...');
  FrameScheduler_stop();
  framePort.close();

  await viewer.dispose();
  await FilamentApp.instance!.destroySwapChain(swapChain);
  await FilamentApp.instance!.destroy();

  releaseNativeView?.call();
  window.destroy();
  sdlQuit();

  print('Goodbye!');
  Isolate.current.kill();
}

class _NativeView {
  _NativeView(this.layer, this.release);
  final Pointer<NativeType> layer;
  final void Function() release;
}

/// macOS: `SDL_Metal_CreateView` returns an NSView, and
/// `SDL_Metal_GetLayer` returns its backing CAMetalLayer*, which is what
/// Filament's Metal backend wants as the swapchain handle.
///
/// The sdl3 package's Dart bindings for these two functions have broken
/// signatures (verified through 2.11: they drop the view argument), so we
/// call them with raw FFI against the SDL dylib we already loaded.
_NativeView? _acquireMetalLayer(Pointer<SdlWindow> window, String sdlPath) {
  final libSdl = DynamicLibrary.open(sdlPath);
  final create = libSdl
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('SDL_Metal_CreateView');
  final getLayer = libSdl
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('SDL_Metal_GetLayer');
  final destroy = libSdl
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('SDL_Metal_DestroyView');

  final view = create(window.cast());
  if (view == nullptr) {
    print('SDL_Metal_CreateView failed: ${sdlGetError()}');
    return null;
  }
  final layer = getLayer(view);
  if (layer == nullptr) {
    print('SDL_Metal_GetLayer failed');
    destroy(view);
    return null;
  }
  return _NativeView(layer, () => destroy(view));
}

/// Common install locations for the SDL3 shared library. When none matches,
/// we leave the sdl3 package's own auto-loader to find it.
String? _findSdlPath() {
  const candidates = [
    // macOS (Homebrew, apple silicon / intel)
    '/opt/homebrew/lib/libSDL3.dylib',
    '/usr/local/lib/libSDL3.dylib',
    // Linux (the auto-loader normally finds these, but be explicit)
    '/usr/local/lib/libSDL3.so.0',
    '/usr/local/lib/libSDL3.so',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}