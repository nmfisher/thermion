import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

enum ViewerManipulatorType { ORBIT, FIRST_PERSON }

class ViewerOptions {
  ///
  ///
  ///
  final Widget initial;

  ///
  /// When true, an FPS counter will be displayed at the top right of the widget
  ///
  final bool showFpsCounter;

  ///
  ///
  ///
  final String? assetPath;

  ///
  ///
  ///
  final String? skyboxPath;

  ///
  ///
  ///
  final String? iblPath;

  ///
  ///
  ///
  final LightType? directLightType;

  ///
  ///
  ///
  final bool transformToUnitCube;

  ///
  ///
  ///
  final bool postProcessing;

  ///
  ///
  ///
  final Color? background;

  ///
  ///
  ///
  final bool destroyAppOnUnload;

  const ViewerOptions(
      {this.initial =
          const DecoratedBox(decoration: BoxDecoration(color: Colors.red)),
      this.showFpsCounter = false,
      this.transformToUnitCube = true,
      this.postProcessing = true,
      this.destroyAppOnUnload = false,
      this.assetPath,
      this.skyboxPath,
      this.iblPath,
      this.directLightType,
      this.background});
}

class ViewerWidget extends StatefulWidget {
  final ViewerOptions options;

  const ViewerWidget({super.key, this.options = const ViewerOptions()});

  @override
  State<StatefulWidget> createState() {
    return _ViewerWidgetState();
  }
}

class _ViewerWidgetState extends State<ViewerWidget> {
  ThermionViewer? viewer;

  @override
  void initState() {
    super.initState();
    ThermionFlutterPlugin.createViewer().then((viewer) async {
      viewer = viewer;

      setState(() {});
    });
  }

  @override
  void dispose() {
    if (viewer != null) {
      _tearDown();
    }
  }

  Future _tearDown() async {
    await viewer!.dispose();
    if (widget.options.destroyAppOnUnload) {
      await FilamentApp.instance!.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (viewer == null) {
      return widget.options.initial!;
    }
    return ThermionWidget(viewer: viewer!);
  }
}
