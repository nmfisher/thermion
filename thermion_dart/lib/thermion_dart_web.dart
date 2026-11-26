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
  /// [canvasSelector] identifies the viewer canvas the offscreen frames
  /// belong to; it defaults to the engine's default canvas,
  /// "#thermion_canvas" (the same fallback the C++ engine uses when no
  /// selector was passed to `FFIFilamentApp.create`).
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
  /// unavailable: non-WebGPU backends, native builds, or a page with no
  /// document body.
  String? offscreenCanvasSelector({String canvasSelector = '#thermion_canvas'}) {
    if (!offscreen.supportsSkipPresent || backend != Backend.WEBGPU) return null;
    return offscreen.offscreenCanvasSelector(canvasSelector);
  }

  /// Creates an offscreen (present-skip) swapchain: every frame is rendered
  /// into the hidden canvas reported by [offscreenCanvasSelector] and never
  /// presented, so JavaScript can composite the frames itself.
  ///
  /// [windowAddress] is the raw native window handle address
  /// (`Pointer.address`); pass 0 on web — the engine renders to its own
  /// canvas, like `createSwapChain(nullptr)`. Web + WebGPU backend only;
  /// throws [UnsupportedError] everywhere else.
  Future<SwapChain> createOffscreenSwapChain(int windowAddress, {bool hasStencilBuffer = false}) {
    if (!offscreen.supportsSkipPresent || backend != Backend.WEBGPU) {
      throw UnsupportedError(
        'Offscreen (present-skip) swapchains are only supported by the WebGPU backend in web builds.',
      );
    }
    final app = this;
    if (app is! FFIFilamentApp) {
      throw UnsupportedError('Offscreen swapchains require the FFI filament app.');
    }
    return offscreen.createOffscreenSwapChain(app, windowAddress, hasStencilBuffer: hasStencilBuffer);
  }
}
