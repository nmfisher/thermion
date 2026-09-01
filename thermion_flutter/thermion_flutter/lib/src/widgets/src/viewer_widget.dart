import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

enum ManipulatorType { NONE, ORBIT, FREE_FLIGHT }

class ViewerWidget extends StatefulWidget {
  // The widget to display before the viewport has loaded.
  final Widget initial;

  // The initial position for the camera (looking towards (0,0,0)).
  late final Vector3 initialCameraPosition;

  // The path to the (glTF) asset to be loaded into the scene.
  final String? assetPath;

  // The path to the (KTX) skybox to be loaded into the scene.
  final String? skyboxPath;

  // The path to the (KTX) image-based light to be loaded into the scene.
  final String? iblPath;

  // A direct light to add to the scene.
  final DirectLight? directLight;

  // If true, the glTF asset will be rescaled so its bounding box fits within a 1x1x1 cube. Defaults to true.
  final bool transformToUnitCube;

  // If true, enables postprocessing (ACES tone mapping and basic anti-aliasing). Defaults to true.
  final bool postProcessing;

  // The fill color to use for the background. If a skybox is provided, the fill color won't be visible.
  final Color? background;

  // Disposing this widget will unload all scene resources (i.e. the asset, skybox, etc). but will leave the underlying engine intact.
  // If [destroyEngineOnUnload] is true, disposing the widget will also destroy the engine and rendering thread.
  // Defaults to false.
  final bool destroyEngineOnUnload;

  // The type of camera manipulator to use to respond to viewport gestures. Defaults to ORBIT (pinch to zoom in/out, swipe to rotate around the asset at a fixed distance).
  final ManipulatorType manipulatorType;

  // A callback that can be used to access the viewer.
  final Future Function(ThermionViewer)? onViewerAvailable;

  // A callback that is invoked when the asset has been loaded.
  // Only called if [assetPath] is provided.
  final Future Function(ThermionViewer viewer, ThermionAsset asset)?
  onAssetLoaded;

  // When true, enable the highlight overlay system for rendering entity outlines.
  final bool enableHighlights;

  ViewerWidget({
    super.key,
    this.initial = const DecoratedBox(
      decoration: BoxDecoration(color: Colors.red),
    ),
    Vector3? initialCameraPosition,
    this.transformToUnitCube = true,
    this.postProcessing = true,
    this.destroyEngineOnUnload = false,
    this.assetPath,
    this.skyboxPath,
    this.iblPath,
    this.directLight,
    this.background,
    this.onViewerAvailable,
    this.onAssetLoaded,
    this.manipulatorType = ManipulatorType.ORBIT,
    this.enableHighlights = false,
  }) {
    this.initialCameraPosition = initialCameraPosition ?? Vector3(0, 0, 5);
  }

  @override
  State<StatefulWidget> createState() {
    return _ViewerWidgetState();
  }
}

class _ViewerWidgetState extends State<ViewerWidget> {
  ThermionViewer? viewer;
  Future<void>? _initialization;
  Future<void>? _tearDownFuture;
  Future<void>? _inputHandlerUpdate;
  bool _disposing = false;
  late final bool _requiresContextBootstrap;

  late final _logger = Logger(runtimeType.toString());

  @override
  void initState() {
    super.initState();
    _requiresContextBootstrap =
        ThermionFlutterPlugin.instance.requiresContextBootstrap;
    if (!_requiresContextBootstrap) {
      _initialization = _createViewer();
      unawaited(
        _initialization!.catchError((Object error, StackTrace stack) {
          _reportAsyncError('initialization', error, stack);
        }),
      );
    }
  }

  Future<void> _initializeViewer() => _initialization ??= _createViewer();

  Future<void> _createViewer() async {
    // Override options if this widget needs highlights
    if (widget.enableHighlights) {
      final currentOptions = ThermionFlutterPlugin.instance.options;
      ThermionFlutterPlugin.instance.setOptions(
        ThermionFlutterOptions(
          uberarchivePath: currentOptions.uberarchivePath,
          webOptions: currentOptions.webOptions,
          nativeOptions: NativeOptions(
            backend: currentOptions.nativeOptions.backend,
            androidTextureSource:
                currentOptions.nativeOptions.androidTextureSource,
            renderTargetColorTextureFormat:
                currentOptions.nativeOptions.renderTargetColorTextureFormat,
            renderTargetDepthTextureFormat:
                currentOptions.nativeOptions.renderTargetDepthTextureFormat,
            createOverlay: true,
          ),
        ),
      );
    }

    if (_disposing) return;
    final viewer = await ThermionFlutterPlugin.createViewer();
    this.viewer = viewer;
    if (_disposing) {
      return;
    }
    await _configure();
    if (mounted && !_disposing) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(ViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manipulatorType != widget.manipulatorType) {
      _inputHandlerUpdate = _setViewportWidget();
      unawaited(
        _inputHandlerUpdate!
            .then((_) {
              if (mounted && !_disposing) {
                setState(() {});
              }
            })
            .catchError((Object error, StackTrace stack) {
              _reportAsyncError('updating the input handler', error, stack);
            }),
      );
    }

    if (viewer == null || _disposing) {
      return;
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
      final background = widget.background;
      if (background == null) {
        viewer!.removeSkybox();
      } else {
        () async {
          await viewer!.removeSkybox();
          final scene = await viewer!.view.getScene();
          await scene.setSkybox(
            await FilamentApp.instance!.createColoredSkybox(
              r: background.r,
              g: background.g,
              b: background.b,
              a: background.a,
            ),
          );
        }();
      }
    } else if (oldWidget.initialCameraPosition !=
        widget.initialCameraPosition) {
      throw UnsupportedError(
        "initialCameraPosition cannot be changed at runtime. Create a new widget to change this property.",
      );
    } else if (oldWidget.assetPath != widget.assetPath) {
      throw UnsupportedError(
        "assetPath cannot be changed at runtime. Create a new widget to change this property.",
      );
    } else if (oldWidget.directLight != widget.directLight) {
      throw UnsupportedError(
        "directLight cannot be changed at runtime. Create a new widget to change this property.",
      );
    } else if (oldWidget.transformToUnitCube != widget.transformToUnitCube) {
      throw UnsupportedError(
        "transformToUnitCube cannot be changed at runtime. Create a new widget to change this property.",
      );
    } else if (oldWidget.destroyEngineOnUnload !=
        widget.destroyEngineOnUnload) {
      throw UnsupportedError(
        "destroyEngineOnUnload cannot be changed at runtime. Create a new widget to change this property.",
      );
    }
  }

  final _focusNode = FocusNode();
  InputHandler? _inputHandler;

  Future<void> _setViewportWidget() async {
    final previousInputHandler = _inputHandler;
    _inputHandler = null;
    await previousInputHandler?.dispose();

    if (_disposing || viewer == null || thermionWidget == null) {
      viewport = thermionWidget;
      return;
    }

    switch (widget.manipulatorType) {
      case ManipulatorType.NONE:
        _inputHandler = null;
        break;
      case ManipulatorType.ORBIT:
        _inputHandler = DelegateInputHandler.fixedOrbit(
          viewer!,
          minimumDistance: widget.initialCameraPosition.length,
          moveOnHover: false,
        );
        break;
      case ManipulatorType.FREE_FLIGHT:
        _inputHandler = DelegateInputHandler.flight(viewer!);
        break;
    }

    if (_inputHandler == null) {
      viewport = thermionWidget;
    } else {
      viewport = ThermionListenerWidget(
        focusNode: _focusNode,
        inputHandler: _inputHandler!,
        child: thermionWidget,
      );
      if (mounted && !_disposing) {
        _focusNode.requestFocus();
      }
    }
  }

  ThermionAsset? asset;
  ThermionWidget? thermionWidget;
  Widget? viewport;

  Future _configure() async {
    if (_disposing) return;

    if (widget.assetPath != null) {
      asset = await viewer!.loadGltf(widget.assetPath!);
      if (_disposing) return;
      await asset!.setCastShadows(true);
      if (_disposing) return;
      await viewer!.view.setShadowsEnabled(true);
    }

    if (_disposing) return;
    if (widget.skyboxPath != null) {
      await viewer!.loadSkybox(widget.skyboxPath!);
    }

    if (_disposing) return;
    if (widget.iblPath != null) {
      await viewer!.loadIbl(widget.iblPath!);
    }

    if (_disposing) return;
    if (widget.postProcessing) {
      await viewer!.setPostProcessing(true);
      await viewer!.setAntiAliasing(false, true, false);
    }

    if (_disposing) return;
    final camera = await viewer!.getActiveCamera();

    await camera.lookAt(widget.initialCameraPosition);

    if (_disposing) return;
    if (widget.background != null) {
      if (widget.skyboxPath != null) {
        _logger.severe("Specify skyboxPath or background, not both");
      } else {
        final scene = await viewer!.view.getScene();
        await scene.setSkybox(
          await FilamentApp.instance!.createColoredSkybox(
            r: widget.background!.r,
            g: widget.background!.g,
            b: widget.background!.b,
            a: widget.background!.a,
          ),
        );
      }
    }

    if (_disposing) return;
    if (widget.directLight != null) {
      await viewer!.addDirectLight(widget.directLight!);
    }

    if (_disposing) return;
    thermionWidget = ThermionWidget(
      key: const Key("viewer_thermion_widget"),
      viewer: viewer!,
    );

    await _setViewportWidget();
    if (_disposing) return;

    final onViewerAvailable = widget.onViewerAvailable;
    if (onViewerAvailable != null) {
      _invokeCallback(
        () => onViewerAvailable(viewer!),
        'onViewerAvailable callback',
      );
    }
    if (asset != null) {
      final onAssetLoaded = widget.onAssetLoaded;
      if (onAssetLoaded != null) {
        _invokeCallback(
          () => onAssetLoaded(viewer!, asset!),
          'onAssetLoaded callback',
        );
      }
    }
  }

  void _invokeCallback(Future Function() callback, String context) {
    unawaited(
      Future.sync(callback).catchError((Object error, StackTrace stack) {
        _reportAsyncError(context, error, stack);
      }),
    );
  }

  void _reportAsyncError(String context, Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'thermion_flutter',
        context: ErrorDescription('while $context in ViewerWidget'),
      ),
    );
  }

  Future<void> _performTearDown() async {
    Object? firstError;
    StackTrace? firstStack;

    Future<void> runCleanup(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    await runCleanup(() async {
      await _initialization;
    });
    await runCleanup(() async {
      await _inputHandlerUpdate;
    });

    final inputHandler = _inputHandler;
    _inputHandler = null;
    await runCleanup(() async {
      await inputHandler?.dispose();
    });

    final currentViewer = viewer;
    viewer = null;
    if (currentViewer != null) {
      await runCleanup(() async {
        try {
          // The texture owns render targets and swapchains that refer to the
          // view. Release those before the viewer destroys its view.
          await ThermionFlutterPlugin.instance.destroyTextureForView(
            currentViewer.view,
          );
        } finally {
          await currentViewer.dispose();
        }
      });
      // Platform hook (web: destroy this viewer's engine + canvas).
      await runCleanup(() async {
        await ThermionFlutterPlugin.instance.onViewerDisposed(
          currentViewer.view,
        );
      });
    }

    if (widget.destroyEngineOnUnload && FilamentApp.instance != null) {
      await runCleanup(() => FilamentApp.instance!.destroy());
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _focusNode.dispose();
    _tearDownFuture ??= _performTearDown();
    unawaited(
      _tearDownFuture!.catchError((Object error, StackTrace stack) {
        _reportAsyncError('teardown', error, stack);
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = viewport == null
        ? widget.initial
        : SizedBox.expand(child: viewport);
    if (!_requiresContextBootstrap) {
      return child;
    }
    return ThermionTextureBootstrap(
      initialize: _initializeViewer,
      child: child,
    );
  }
}
