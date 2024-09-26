import 'dart:math';

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class CameraOrientationWidget extends StatefulWidget {
  final ThermionViewer viewer;

  const CameraOrientationWidget({Key? key, required this.viewer}) : super(key: key);

  @override
  _CameraOrientationWidgetState createState() => _CameraOrientationWidgetState();
}

class _CameraOrientationWidgetState extends State<CameraOrientationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  v64.Vector3? _position;
  v64.Matrix3? _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
    )..repeat();

    _controller.addListener(_updateCameraInfo);
  }

  void _updateCameraInfo() async {
    final position = await widget.viewer.getCameraPosition();
    final rotation = await widget.viewer.getCameraRotation();
    setState(() {
      _position = position;
      _rotation = rotation;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Position: ${_formatVector(_position)}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Rotation: ${_formatMatrix(_rotation)}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatVector(v64.Vector3? vector) {
    if (vector == null) return 'N/A';
    return '(${vector.x.toStringAsFixed(2)}, ${vector.y.toStringAsFixed(2)}, ${vector.z.toStringAsFixed(2)})';
  }

  String _formatMatrix(v64.Matrix3? matrix) {
    if (matrix == null) return 'N/A';
    return 'Yaw: ${_getYaw(matrix).toStringAsFixed(2)}°, Pitch: ${_getPitch(matrix).toStringAsFixed(2)}°, Roll: ${_getRoll(matrix).toStringAsFixed(2)}°';
  }

  double _getYaw(v64.Matrix3 matrix) {
    return -atan2(matrix[2], matrix[0]) * 180 / pi;
  }

  double _getPitch(v64.Matrix3 matrix) {
    return -asin(matrix[5]) * 180 / pi;
  }

  double _getRoll(v64.Matrix3 matrix) {
    return atan2(matrix[3], matrix[4]) * 180 / pi;
  }
}