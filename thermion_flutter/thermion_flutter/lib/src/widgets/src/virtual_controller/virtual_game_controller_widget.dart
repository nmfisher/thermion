import 'package:flutter/material.dart';
import 'virtual_controller_input_handler.dart';
import 'd_pad_widget.dart';
import 'analog_stick_widget.dart';

class VirtualControllerWidget extends StatelessWidget {
  final VirtualControllerInputHandler inputHandler;
  final Widget child;
  final bool enabled;
  final double controllerSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color stickColor;
  final double opacity;
  final EdgeInsets padding;

  const VirtualControllerWidget({
    Key? key,
    required this.inputHandler,
    required this.child,
    this.enabled = true,
    this.controllerSize = 120.0,
    this.backgroundColor = Colors.black26,
    this.foregroundColor = Colors.white70,
    this.stickColor = Colors.white,
    this.opacity = 0.7,
    this.padding = const EdgeInsets.all(20.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Stack(
      children: [
        // The main content (ThermionWidget)
        child,

        // D-pad on the left side
        Positioned(
          left: padding.left,
          bottom: padding.bottom,
          child: DPadWidget(
            inputHandler: inputHandler,
            size: controllerSize,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            opacity: opacity,
          ),
        ),

        // Analog stick on the right side
        Positioned(
          right: padding.right,
          bottom: padding.bottom,
          child: AnalogStickWidget(
            inputHandler: inputHandler,
            size: controllerSize,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            stickColor: stickColor,
            opacity: opacity,
          ),
        ),
      ],
    );
  }
}
