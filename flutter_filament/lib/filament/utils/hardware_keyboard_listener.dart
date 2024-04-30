import 'package:flutter/services.dart';
import 'package:flutter_filament/filament/entities/entity_transform_controller.dart';

class HardwareKeyboardListener {
  final EntityTransformController _controller;
  var _listening = true;
  HardwareKeyboardListener(this._controller) {
    // Get the global handler.
    final KeyMessageHandler? existing =
        ServicesBinding.instance.keyEventManager.keyMessageHandler;
    // The handler is guaranteed non-null since
    // `FallbackKeyEventRegistrar.instance` is only called during
    // `Focus.onFocusChange`, at which time `ServicesBinding.instance` must
    // have been called somewhere.
    assert(existing != null);
    // Assign the global handler with a patched handler.
    ServicesBinding.instance.keyEventManager.keyMessageHandler = (keyMessage) {
      if (keyMessage.rawEvent == null) {
        return false;
      }
      if (!_listening) {
        return false;
      }
      var event = keyMessage.rawEvent!;
      switch (event.logicalKey) {
        case LogicalKeyboardKey.escape:
          _listening = false;
          break;
        case LogicalKeyboardKey.keyW:
          (event is RawKeyDownEvent)
              ? _controller.forwardPressed()
              : _controller.forwardReleased();
          break;
        case LogicalKeyboardKey.keyA:
          event is RawKeyDownEvent
              ? _controller.strafeLeftPressed()
              : _controller.strafeLeftReleased();
          break;
        case LogicalKeyboardKey.keyS:
          event is RawKeyDownEvent
              ? _controller.backPressed()
              : _controller.backReleased();
          break;
        case LogicalKeyboardKey.keyD:
          event is RawKeyDownEvent
              ? _controller.strafeRightPressed()
              : _controller.strafeRightReleased();
          break;
        default:
          break;
      }
      return true;
    };
  }

  void dispose() {
    ServicesBinding.instance.keyEventManager.keyMessageHandler = null;
    _controller.dispose();
  }
}
