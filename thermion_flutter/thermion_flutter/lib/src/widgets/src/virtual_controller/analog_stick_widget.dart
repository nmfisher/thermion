import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'virtual_controller_input_handler.dart';

class AnalogStickWidget extends StatefulWidget {
  final VirtualControllerInputHandler inputHandler;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color stickColor;
  final double opacity;
  final double maxDistance;

  const AnalogStickWidget({
    Key? key,
    required this.inputHandler,
    this.size = 120.0,
    this.backgroundColor = Colors.black26,
    this.foregroundColor = Colors.white70,
    this.stickColor = Colors.white,
    this.opacity = 0.7,
    this.maxDistance = 40.0,
  }) : super(key: key);

  @override
  State<AnalogStickWidget> createState() => _AnalogStickWidgetState();
}

class _AnalogStickWidgetState extends State<AnalogStickWidget> {
  Offset _stickPosition = Offset.zero;
  Offset _center = Offset.zero;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    // Set center to the actual center of the widget
    _center = Offset(widget.size / 2, widget.size / 2);
    _stickPosition = _center;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Stack(
          children: [
            // Background circle
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      widget.backgroundColor.withValues(alpha: widget.opacity),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.foregroundColor
                        .withValues(alpha: widget.opacity * 0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Stick
            AnimatedPositioned(
              duration:
                  _isActive ? Duration.zero : const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              left: _stickPosition.dx - widget.size * 0.15,
              top: _stickPosition.dy - widget.size * 0.15,
              child: Container(
                width: widget.size * 0.3,
                height: widget.size * 0.3,
                decoration: BoxDecoration(
                  color: _isActive
                      ? widget.stickColor
                          .withValues(alpha: widget.opacity * 0.9)
                      : widget.stickColor
                          .withValues(alpha: widget.opacity * 0.6),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isActive = true;
      _stickPosition = details.localPosition;
    });
    widget.inputHandler.handleAnalogStart(vm.Vector2(
      details.localPosition.dx,
      details.localPosition.dy,
    ));
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final offset = details.localPosition - _center;
    final distance = offset.distance;

    // Constrain the stick within the maximum distance
    Offset constrainedPosition;
    if (distance <= widget.maxDistance) {
      constrainedPosition = details.localPosition;
    } else {
      final angle = offset.direction;
      constrainedPosition =
          _center + Offset.fromDirection(angle, widget.maxDistance);
    }

    setState(() {
      _stickPosition = constrainedPosition;
    });

    widget.inputHandler.handleAnalogMove(vm.Vector2(
      constrainedPosition.dx,
      constrainedPosition.dy,
    ));
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isActive = false;
      _stickPosition = _center;
    });
    widget.inputHandler.handleAnalogEnd();
  }

  @override
  void dispose() {
    widget.inputHandler.handleAnalogEnd();
    super.dispose();
  }
}
