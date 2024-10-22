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

  bool destroyed = false;

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
    _logger.info(
        "Resizing texture to $newWidth x $newHeight (offset $newLeft, $newTop)");
    if (newWidth == this.width &&
        newHeight == this.height &&
        newLeft == 0 &&
        newTop == 0) {
      _logger.info("Existing texture matches requested dimensions");
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

    _logger.info("Created texture ${flutterId} / ${hardwareId}");

    if (destroySwapChainOnResize) {
      if (swapChain != null) {
        await viewer.destroySwapChain(swapChain!);
      }
      swapChain = await viewer.createSwapChain(result[2]);
      await view.setRenderable(true, swapChain!);
    } else if (hardwareId != _lastHardwareId) {
      if (_renderTarget != null) {
        await viewer.destroyRenderTarget(_renderTarget!);
      }
      _renderTarget =
          await viewer.createRenderTarget(width, height, hardwareId);
      await view.setRenderTarget(_renderTarget!);
      await view.setRenderable(true, swapChain!);
      if (_lastFlutterId != -1 && _lastHardwareId != -1) {
        await _destroyTexture(_lastFlutterId, _lastHardwareId);
        _lastFlutterId = -1;
        _lastHardwareId = -1;
      }
    }
  }

  Future<void> _destroyTexture(
      int flutterTextureId, int hardwareTextureId) async {
    try {
      await channel.invokeMethod(
          "destroyTexture", [flutterTextureId, hardwareTextureId]);
      _logger.info("Destroyed texture $flutterTextureId / $hardwareTextureId");
    } catch (e) {
      _logger.severe("Failed to destroy texture: $e");
    }
  }

  bool destroying = false;
  Future destroy() async {
    if (destroyed || destroying) {
      return;
    }
    destroying = true;
    await view.setRenderTarget(null);
    if (_renderTarget != null) {
      await viewer.destroyRenderTarget(_renderTarget!);
      _renderTarget = null;
    }

    if (destroySwapChainOnResize && swapChain != null) {
      await viewer.destroySwapChain(swapChain!);
      swapChain = null;
    }
    await _destroyTexture(flutterId, hardwareId);
    flutterId = -1;
    hardwareId = -1;
    destroying = false;
    destroyed = true;
  }

  Future markFrameAvailable() async {
    await channel.invokeMethod("markTextureFrameAvailable", this.flutterId);
  }
}
