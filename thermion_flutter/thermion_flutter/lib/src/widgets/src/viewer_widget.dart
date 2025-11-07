import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

enum ManipulatorType { NONE, ORBIT, FREE_FLIGHT }

class ViewerWidget extends StatefulWidget {
  ///
  /// The widget to display before the viewport has loaded.
  ///
  final Widget initial;

  ///
  /// The initial position for the camera (looking towards (0,0,0)).
  ///
  late final Vector3 initialCameraPosition;

  ///
  /// When true, an FPS counter will be overlaid above the viewer widget.
  ///
  final bool showFpsCounter;

  ///
  /// The path to the (glTF) asset to be loaded into the scene.
  ///
  final String? assetPath;

  ///
  /// The path to the (KTX) skybox to be loaded into the scene.
  ///
  final String? skyboxPath;

  ///
  /// The path to the (KTX) image-based light to be loaded into the scene.
  ///
  final String? iblPath;

  ///
  /// A direct light to add to the scene.
  ///
  final DirectLight? directLight;

  ///
  /// If true, the glTF asset will be rescaled so its bounding box fits within a 1x1x1 cube. Defaults to true.
  ///
  final bool transformToUnitCube;

  ///
  /// If true, enables postprocessing (ACES tone mapping and basic anti-aliaising). Defaults to true.
  ///
  final bool postProcessing;

  ///
  /// The fill color to use for the background. If a skybox is provided, the fill color won't be visible.
  ///
  final Color? background;

  ///
  /// Disposing this widget will unload all scene resources (i.e. the asset, skybox, etc). but will leave the underlying engine intact.
  /// If [destroyEngineOnUnload] is true, disposing the widget will also destroy the engine and rendering thread.
  /// Defaults to false.
  ///
  final bool destroyEngineOnUnload;

  ///
  /// The type of camera manipulator to use to respond to viewport gestures. Defaults to ORBIT (pinch to zoom in/out, swipe to rotate around the asset at a fixed distance).
  ///
  final ManipulatorType manipulatorType;

  ///
  /// A callback that can be used to access the viewer.
  ///
  final Future Function(ThermionViewer)? onViewerAvailable;

  ///
  ///
  ///
  ViewerWidget(
      {super.key,
      this.initial =
          const DecoratedBox(decoration: BoxDecoration(color: Colors.red)),
      Vector3? initialCameraPosition,
      this.showFpsCounter = false,
      this.transformToUnitCube = true,
      this.postProcessing = true,
      this.destroyEngineOnUnload = false,
      this.assetPath,
      this.skyboxPath,
      this.iblPath,
      this.directLight,
      this.background,
      this.onViewerAvailable,
      this.manipulatorType = ManipulatorType.ORBIT}) {
    this.initialCameraPosition = initialCameraPosition ?? Vector3(0, 0, 5);
  }

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
      this.viewer = viewer;
      await _configure();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(ViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manipulatorType != widget.manipulatorType) {
      _setViewportWidget();
      setState(() {});
    }

    if (oldWidget.postProcessing != widget.postProcessing) {
      viewer!.setPostProcessing(widget.postProcessing);
    } else if (oldWidget.skyboxPath != widget.skyboxPath) {
      if (widget.skyboxPath == null) {
        viewer!.removeSkybox();
      } else {
        viewer!.loadSkybox(widget.skyboxPath!);
      }
    } else if (oldWidget.iblPath != widget.iblPath) {
      if (widget.iblPath == null) {
        viewer!.removeIbl(destroy: true);
      } else {
        viewer!.loadIbl(widget.iblPath!);
      }
    } else if (oldWidget.background != widget.background) {
      viewer!.setBackgroundColor(
          widget.background?.r ?? 0,
          widget.background?.g ?? 0,
          widget.background?.b ?? 0,
          widget.background?.a ?? 0);
    } else if (oldWidget.initialCameraPosition !=
            widget.initialCameraPosition ||
        oldWidget.showFpsCounter != widget.showFpsCounter ||
        oldWidget.assetPath != widget.assetPath ||
        oldWidget.directLight != widget.directLight ||
        oldWidget.transformToUnitCube != widget.transformToUnitCube ||
        oldWidget.destroyEngineOnUnload != widget.destroyEngineOnUnload) {
      throw UnsupportedError(
          "Only manipulatorType can be changed at runtime. To change any other properties, create a new widget.");
    }
  }

  void _setViewportWidget() {
    switch (widget.manipulatorType) {
      case ManipulatorType.NONE:
        viewport = thermionWidget;
      case ManipulatorType.ORBIT:
        viewport = ThermionListenerWidget(
            key: const ObjectKey(ManipulatorType.ORBIT),
            inputHandler: DelegateInputHandler.fixedOrbit(viewer!,
                minimumDistance: widget.initialCameraPosition.length,
                moveOnHover: false),
            child: thermionWidget);
      case ManipulatorType.FREE_FLIGHT:
        viewport = ThermionListenerWidget(
            key: const ObjectKey(ManipulatorType.FREE_FLIGHT),
            inputHandler: DelegateInputHandler.flight(viewer!),
            child: thermionWidget);
    }
  }

  ThermionAsset? asset;
  late final ThermionWidget? thermionWidget;
  Widget? viewport;

  Future _configure() async {
    if (widget.assetPath != null) {
      asset = await viewer!.loadGltf(widget.assetPath!);

      await asset!.setCastShadows(true);

      await viewer!.view.setShadowsEnabled(true);
    }

    if (widget.skyboxPath != null) {
      await viewer!.loadSkybox(widget.skyboxPath!);
    }

    if (widget.iblPath != null) {
      await viewer!.loadIbl(widget.iblPath!);
    }

    if (widget.postProcessing) {
      await viewer!.setPostProcessing(true);
      await viewer!.setAntiAliasing(false, true, false);
    }

    final camera = await viewer!.getActiveCamera();

    await camera.lookAt(widget.initialCameraPosition);

    if (widget.background != null) {
      if (widget.skyboxPath != null) {
        print("Specify skyboxPath or background, not both");
      } else {
        await viewer!.setBackgroundColor(widget.background!.r,
            widget.background!.g, widget.background!.b, widget.background!.a);
      }
    }

    if (widget.directLight != null) {
      await viewer!.addDirectLight(widget.directLight!);
    }

    thermionWidget = ThermionWidget(
      key: ObjectKey(DateTime.now()),
      viewer: viewer!,
      showFpsCounter: widget.showFpsCounter,
    );

    _setViewportWidget();

    await viewer!.setRendering(true);
    widget.onViewerAvailable?.call(viewer!);
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    if (viewer != null) {
      _tearDown();
    }
  }

  Future _tearDown() async {
    await viewer!.dispose();
    if (widget.destroyEngineOnUnload) {
      await FilamentApp.instance!.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return viewport != null ? SizedBox.expand(child: viewport) : widget.initial;
  }
}
