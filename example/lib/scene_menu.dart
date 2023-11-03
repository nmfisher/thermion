import 'package:flutter/material.dart';

import 'package:flutter_filament/filament_controller.dart';

class SceneMenu extends StatefulWidget {
  final FilamentController? controller;

  const SceneMenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() {
    return _SceneMenuState();
  }
}

class _SceneMenuState extends State<SceneMenu> {
  bool _postProcessing = true;

  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Camera Menu');

  @override
  void didUpdateWidget(SceneMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.controller!.hasViewer != oldWidget.controller!.hasViewer) {
      setState(() {});
    }
  }

  bool _coneHidden = false;
  FilamentEntity? _shapes;
  FilamentEntity? _directionalLight;
  List<String>? _animations;
  bool _loop = false;

  bool _hasSkybox = false;

  List<MenuItemButton> _assetMenu() {
    return [
      MenuItemButton(
          onPressed: () async {
            if (_shapes == null) {
              _shapes =
                  await widget.controller!.loadGlb('assets/shapes/shapes.glb');
              _animations =
                  await widget.controller!.getAnimationNames(_shapes!);
            } else {
              await widget.controller!.removeAsset(_shapes!);
              _shapes = null;
              _animations = null;
            }
            setState(() {});
          },
          child:
              Text(_shapes == null ? 'load shapes GLB' : 'remove shapes GLB')),
      MenuItemButton(
          onPressed: () {
            widget.controller!.setBackgroundColor(const Color(0xFF73C9FA));
          },
          child: const Text("set background color")),
      MenuItemButton(
          onPressed: () {
            widget.controller!.setBackgroundImage('assets/background.ktx');
          },
          child: const Text("load background image")),
      MenuItemButton(
          onPressed: () {
            widget.controller!
                .setBackgroundImage('assets/background.ktx', fillHeight: true);
          },
          child: const Text("load background image (fill height)")),
      MenuItemButton(
          onPressed: () {
            if (_hasSkybox) {
              widget.controller!.removeSkybox();
            } else {
              widget.controller!
                  .loadSkybox('assets/default_env/default_env_skybox.ktx');
            }
            _hasSkybox = !_hasSkybox;
            setState(() {});
          },
          child: Text(_hasSkybox ? 'remove skybox' : 'load skybox')),
      MenuItemButton(
          onPressed: () {
            widget.controller!
                .loadIbl('assets/default_env/default_env_ibl.ktx');
          },
          child: const Text('load IBL'))
    ];
  }

  bool _frustumCulling = true;
  ManipulatorMode _cameraManipulatorMode = ManipulatorMode.ORBIT;

  double _zoomSpeed = 0.01;
  double _orbitSpeedX = 0.01;
  double _orbitSpeedY = 0.01;

  List<Widget> _cameraMenu() {
    return [
      MenuItemButton(
        onPressed: () {
          widget.controller!.moveCameraToAsset(_shapes!);
        },
        child: const Text("Move camera to shapes asset"),
      ),
      MenuItemButton(
        onPressed: () {
          setState(() {
            _frustumCulling = !_frustumCulling;
          });
          widget.controller!.setViewFrustumCulling(_frustumCulling);
        },
        child:
            Text("${_frustumCulling ? "Disable" : "Enable"} frustum culling"),
      ),
      SubmenuButton(
          menuChildren: ManipulatorMode.values.map((mm) {
            return MenuItemButton(
              onPressed: () {
                _cameraManipulatorMode = mm;
                widget.controller!.setCameraManipulatorOptions(
                    mode: _cameraManipulatorMode,
                    orbitSpeedX: _orbitSpeedX,
                    orbitSpeedY: _orbitSpeedY,
                    zoomSpeed: _zoomSpeed);
                setState(() {});
              },
              child: Text(
                mm.name,
                style: TextStyle(
                    fontWeight: _cameraManipulatorMode == mm
                        ? FontWeight.bold
                        : FontWeight.normal),
              ),
            );
          }).toList(),
          child: Text("Manipulator mode")),
      SubmenuButton(
          menuChildren: [0.01, 0.1, 1.0, 10.0, 100.0].map((speed) {
            return MenuItemButton(
              onPressed: () {
                _zoomSpeed = speed;
                widget.controller!.setCameraManipulatorOptions(
                    mode: _cameraManipulatorMode,
                    orbitSpeedX: _orbitSpeedX,
                    orbitSpeedY: _orbitSpeedY,
                    zoomSpeed: _zoomSpeed);
                setState(() {});
              },
              child: Text(
                speed.toString(),
                style: TextStyle(
                    fontWeight: (speed - _zoomSpeed).abs() < 0.0001
                        ? FontWeight.bold
                        : FontWeight.normal),
              ),
            );
          }).toList(),
          child: const Text("Zoom speed")),
      SubmenuButton(
          menuChildren: [0.001, 0.01, 0.1, 1.0].map((speed) {
            return MenuItemButton(
              onPressed: () {
                _orbitSpeedX = speed;
                _orbitSpeedY = speed;
                widget.controller!.setCameraManipulatorOptions(
                    mode: _cameraManipulatorMode,
                    orbitSpeedX: _orbitSpeedX,
                    orbitSpeedY: _orbitSpeedY,
                    zoomSpeed: _zoomSpeed);
                setState(() {});
              },
              child: Text(
                speed.toString(),
                style: TextStyle(
                    fontWeight: (speed - _orbitSpeedX).abs() < 0.0001
                        ? FontWeight.bold
                        : FontWeight.normal),
              ),
            );
          }).toList(),
          child: const Text("Orbit speed (X & Y)"))
    ];
  }

  bool _rendering = false;
  int _framerate = 60;

  List<MenuItemButton> _renderingMenu() {
    return [
      MenuItemButton(
        onPressed: () {
          widget.controller!.render();
        },
        child: const Text("Render single frame"),
      ),
      MenuItemButton(
        onPressed: () {
          _rendering = !_rendering;
          widget.controller!.setRendering(_rendering);
        },
        child: Text("Set continuous rendering to ${!_rendering}"),
      ),
      MenuItemButton(
        onPressed: () {
          _framerate = _framerate == 60 ? 30 : 60;
          widget.controller!.setFrameRate(_framerate);
        },
        child: Text("Toggle framerate (currently $_framerate) "),
      ),
      MenuItemButton(
        onPressed: () {
          widget.controller!.setToneMapping(ToneMapper.LINEAR);
        },
        child: const Text("Set tone mapping to linear"),
      ),
      MenuItemButton(
        onPressed: () {
          setState(() {
            _postProcessing = !_postProcessing;
          });
          widget.controller!.setPostProcessing(_postProcessing);
        },
        child: Text("${_postProcessing ? "Disable" : "Enable"} postprocessing"),
      ),
      MenuItemButton(
        onPressed: () async {
          _directionalLight = await widget.controller!
              .addLight(1, 6500, 150000, 0, 1, 0, 0, -1, 0, true);
        },
        child: const Text("add directional light"),
      ),
      MenuItemButton(
        onPressed: () async {
          await widget.controller!.clearLights();
        },
        child: const Text("clear all lights"),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable:
            widget.controller?.hasViewer ?? ValueNotifier<bool>(false),
        builder: (BuildContext ctx, bool hasViewer, Widget? child) {
          return MenuAnchor(
            childFocusNode: _buttonFocusNode,
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: _renderingMenu(),
                child: const Text("Rendering"),
              ),
              SubmenuButton(
                menuChildren: _assetMenu(),
                child: const Text("Assets"),
              ),
              SubmenuButton(
                menuChildren: _cameraMenu(),
                child: const Text("Camera"),
              ),
            ],
            builder: (BuildContext context, MenuController controller,
                Widget? child) {
              return Align(
                  alignment: Alignment.bottomLeft,
                  child: TextButton(
                    onPressed: !hasViewer
                        ? null
                        : () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                    child: const Text("Scene"),
                  ));
            },
          );
        });
  }
}
