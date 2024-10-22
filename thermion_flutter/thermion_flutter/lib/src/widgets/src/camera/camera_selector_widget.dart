import 'package:flutter/material.dart';
import 'package:thermion_dart/thermion_dart.dart';

class CameraSelectorWidget extends StatefulWidget {
  final ThermionViewer viewer;

  const CameraSelectorWidget({Key? key, required this.viewer}) : super(key: key);

  @override
  _CameraSelectorWidgetState createState() => _CameraSelectorWidgetState();
}

class _CameraSelectorWidgetState extends State<CameraSelectorWidget> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    int cameraCount = widget.viewer.getCameraCount();

    return Container(
      height:32,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCameraButton("Main", 0),
          if (cameraCount > 1) const VerticalDivider(width: 16, thickness: 1),
          ...List.generate(cameraCount - 1, (index) {
            return _buildCameraButton("${index + 1}", index + 1);
          }),
        ],
      ),
    );
  }

  Widget _buildCameraButton(String label, int index) {
    bool isActive = _activeIndex == index;
    return Flexible(child:TextButton(
      onPressed: () async {
        if (index == 0) {
          await widget.viewer.setMainCamera();
        } else {
          Camera camera = widget.viewer.getCameraAt(index);
          await widget.viewer.setActiveCamera(camera);
        }
        setState(() {
          _activeIndex = index;
        });
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: isActive ? Colors.blue.withOpacity(0.1) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? Colors.blue : Colors.black87,
        ),
      ),
    ));
  }
}