/// Web-only Thermion entrypoint: WebGPU device export and offscreen
/// (present-skip) swapchains for JavaScript compositing.
///
/// Import this library IN ADDITION to `thermion_dart.dart` (it is not
/// re-exported there). It compiles on every platform, but the features
/// only work on web targets:
///
/// ```dart
/// import 'package:thermion_dart/thermion_dart.dart';
/// import 'package:thermion_dart/thermion_dart_web.dart';
/// ```
///
/// Everything here is a no-op / null on non-WebGPU backends: the extension
/// never touches the DOM or calls into the engine unless the app runs the
/// WebGPU backend on web. [ThermionWebFilamentApp.createOffscreenSwapChain]
/// throws [UnsupportedError] anywhere else (including native builds, where
/// the web implementation is not compiled in).
library thermion_dart_web;

import 'package:thermion_dart/thermion_dart.dart';

import 'src/filament/src/implementation/ffi_filament_app.dart';
import 'src/web/gpu_device.dart';
import 'src/web/offscreen_swapchain.dart' as offscreen;

export 'src/web/gpu_device.dart' show GPUDevice;

extension ThermionWebFilamentApp on FilamentApp {
  /// The browser `GPUDevice` driving this engine's WebGPU backend, or null
  /// when this is not a WebGPU web engine (native, WebGL2, or no engine).
  ///
  /// The engine exports the device to JavaScript
  /// (`Module['thermionWebGPUDevice']`); a sidecar renderer can import it to
  /// share GPU resources (queues, buffers, textures) with Thermion.
  GPUDevice? get webGPUDevice {
    if (backend != Backend.WEBGPU) return null;
    return exportWebGPUDevice();
  }

  /// Selector ("#id") of the hidden canvas that receives this engine's
  /// offscreen ([createOffscreenSwapChain]) frames.
  ///
  /// The engine resolves its viewer canvas from the selector its job
  /// thread was created with (`FFIFilamentApp.create(canvasSelector: ...)`,
  /// defaulting to "#thermion_canvas"), so this always matches what
  /// [createOffscreenSwapChain] renders into — also in multi-viewer apps
  /// with one engine per canvas.
  ///
  /// The hidden canvas is created on first use and kept for the page's
  /// lifetime. JavaScript composites the frames itself: either draw the
  /// canvas (e.g. `drawImage` onto the visible canvas), or — on a WebGPU
  /// sidecar — copy the hidden canvas context's `getCurrentTexture()` into
  /// a texture you own. Do NOT bind `getCurrentTexture()` directly as a
  /// sampled texture: canvas surfaces only carry RENDER_ATTACHMENT
  /// (+ COPY_SRC), never TEXTURE_BINDING, so sampling fails WebGPU
  /// validation. Copy with `copyTextureToTexture` /
  /// `copyExternalImageToTexture` first.
  ///
  /// Returns null WITHOUT touching the DOM when offscreen swapchains are
  /// unavailable: non-WebGPU backends, WebGL2 engine builds, native builds,
  /// or a page with no document body.
  String? get offscreenCanvasSelector {
    if (backend != Backend.WEBGPU || !offscreen.supportsSkipPresent) return null;
    final app = this;
    if (app is! FFIFilamentApp) return null;
    return offscreen.offscreenCanvasSelector(app.jobThreadHandle.address);
  }

  /// Creates an offscreen (present-skip) swapchain: every frame is rendered
  /// into the hidden canvas reported by [offscreenCanvasSelector] and never
  /// presented, so JavaScript can composite the frames itself.
  ///
  /// The engine renders to its own canvas, like `createSwapChain(nullptr)`.
  /// WebGPU engines on web only (a WebGL2 engine build reports the feature
  /// unavailable); throws [UnsupportedError] synchronously everywhere else.
  Future<SwapChain> createOffscreenSwapChain({bool hasStencilBuffer = false}) {
    if (backend != Backend.WEBGPU || !offscreen.supportsSkipPresent) {
      throw UnsupportedError(
        'Offscreen (present-skip) swapchains are only supported by the WebGPU engine in web builds.',
      );
    }
    final app = this;
    if (app is! FFIFilamentApp) {
      throw UnsupportedError('Offscreen swapchains require the FFI filament app.');
    }
    // The engine's web-only Thermion_createOffscreenSwapChain export, run as
    // a job on the engine's thread; the swapchain is registered for teardown
    // like any other.
    return offscreen
        .createOffscreenSwapChain(app.jobThreadHandle.address, app.engine.address, hasStencilBuffer: hasStencilBuffer)
        .then(app.adoptSwapChain);
  }
}
