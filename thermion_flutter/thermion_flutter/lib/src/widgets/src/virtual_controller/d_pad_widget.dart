import 'package:flutter/material.dart';
import 'virtual_controller_input_handler.dart';

class DPadWidget extends StatefulWidget {
  final VirtualControllerInputHandler inputHandler;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final double opacity;

  const DPadWidget({
    Key? key,
    required this.inputHandler,
    this.size = 120.0,
    this.backgroundColor = Colors.black26,
    this.foregroundColor = Colors.white70,
    this.opacity = 0.5,
  }) : super(key: key);

  @override
  State<DPadWidget> createState() => _DPadWidgetState();
}

class _DPadWidgetState extends State<DPadWidget> {
  final Map<DPadDirection, bool> _pressedDirections = {
    DPadDirection.up: false,
    DPadDirection.down: false,
    DPadDirection.left: false,
    DPadDirection.right: false,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          // Background circle
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor.withValues(alpha: widget.opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Cross-shaped D-pad
          Positioned.fill(
            child: Column(
              children: [
                Expanded(child: _buildDirectionButton(DPadDirection.up)),
                Row(
                  children: [
                    Expanded(child: _buildDirectionButton(DPadDirection.left)),
                    SizedBox(
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                    ),
                    Expanded(child: _buildDirectionButton(DPadDirection.right)),
                  ],
                ),
                Expanded(child: _buildDirectionButton(DPadDirection.down)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(DPadDirection direction) {
    bool isPressed = _pressedDirections[direction] ?? false;

    return GestureDetector(
      onTapDown: (_) => _onDirectionPress(direction, true),
      onTapUp: (_) => _onDirectionPress(direction, false),
      onTapCancel: () => _onDirectionPress(direction, false),
      child: Center(
        child: Icon(
          _getDirectionIcon(direction),
          color: isPressed
              ? widget.foregroundColor.withValues(alpha: widget.opacity * 0.9)
              : widget.foregroundColor.withValues(alpha: widget.opacity * 0.6),
          size: widget.size * 0.25,
        ),
      ),
    );
  }

  IconData _getDirectionIcon(DPadDirection direction) {
    switch (direction) {
      case DPadDirection.up:
        return Icons.keyboard_arrow_up;
      case DPadDirection.down:
        return Icons.keyboard_arrow_down;
      case DPadDirection.left:
        return Icons.keyboard_arrow_left;
      case DPadDirection.right:
        return Icons.keyboard_arrow_right;
      case DPadDirection.none:
        return Icons.circle_outlined;
    }
  }

  void _onDirectionPress(DPadDirection direction, bool pressed) {
    setState(() {
      _pressedDirections[direction] = pressed;
    });
    widget.inputHandler.handleDPadPress(direction, pressed);
  }

  @override
  void dispose() {
    // Release all pressed directions
    for (final direction in _pressedDirections.keys) {
      if (_pressedDirections[direction] == true) {
        widget.inputHandler.handleDPadPress(direction, false);
      }
    }
    super.dispose();
  }
}
