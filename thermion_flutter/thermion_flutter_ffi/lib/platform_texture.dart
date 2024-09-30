import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'thermion_flutter_method_channel_interface.dart';

class FlutterPlatformTexture extends MethodChannelFlutterTexture {
  final _logger = Logger("ThermionFlutterTexture");

  final ThermionViewer viewer;
  final View view;

  int flutterId = -1;
  int _lastFlutterId = -1;
  int _lastHardwareId = -1;
  int hardwareId = -1;
  int width = -1;
  int height = -1;

  SwapChain? swapChain;

  RenderTarget? _renderTarget;

  late bool destroySwapChainOnResize;

  FlutterPlatformTexture(
      super.channel, this.viewer, this.view, this.swapChain) {
    if (swapChain == null) {
      destroySwapChainOnResize = true;
    } else {
      destroySwapChainOnResize = false;
    }
  }

  @override
  Future<void> resize(
      int newWidth, int newHeight, int newLeft, int newTop) async {
    if (newWidth == this.width &&
        newHeight == this.height &&
        newLeft == 0 &&
        newTop == 0) {
      return;
    }

    this.width = newWidth;
    this.height = newHeight;

    var result =
        await channel.invokeMethod("createTexture", [width, height, 0, 0]);
    if (result == null || (result[0] == -1)) {
      throw Exception("Failed to create texture");
    }
    _lastFlutterId = flutterId;
    _lastHardwareId = hardwareId;
    flutterId = result[0] as int;

    hardwareId = result[1] as int;

    if (destroySwapChainOnResize) {
      await swapChain?.destroy();
      swapChain = await viewer.createSwapChain(result[2]);
    }

    _logger.info(
        "Created new texture: flutter id $flutterId, hardware id $hardwareId");

    if (destroySwapChainOnResize) {
      await view.setRenderable(true, swapChain!);
    } else if (hardwareId != _lastHardwareId) {
      await _renderTarget?.destroy();
      _renderTarget =
          await viewer.createRenderTarget(width, height, hardwareId);
      await view.setRenderTarget(_renderTarget!);
      await view.setRenderable(true, swapChain!);
      await _destroyTexture(_lastFlutterId, _lastHardwareId);
    }
  }

  Future<void> _destroyTexture(int flutterId, int? hardwareId) async {
    try {
      await channel.invokeMethod("destroyTexture", [flutterId, hardwareId]);
      _logger.info(
          "Destroyed old texture: flutter id $flutterId, hardware id $hardwareId");
    } catch (e) {
      _logger.severe("Failed to destroy texture: $e");
    }
  }

  Future destroy() async {
    await view.setRenderTarget(null);
    await _renderTarget?.destroy();
    await swapChain?.destroy();
    await channel.invokeMethod("destroyTexture", hardwareId);
  }

  Future markFrameAvailable() async {
    await channel.invokeMethod("markTextureFrameAvailable", this.flutterId);
  }
}
