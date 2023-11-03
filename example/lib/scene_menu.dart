import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';

class SceneMenu extends StatefulWidget {
  final FilamentController? controller;

  SceneMenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() {
    return _SceneMenuState();
  }
}

class _SceneMenuState extends State<SceneMenu> {
  FilamentEntity? _shapes;
  List<String>? _animations;
  bool _hasSkybox = false;
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Camera Menu');

  @override
  void didUpdateWidget(SceneMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.controller!.hasViewer != oldWidget.controller!.hasViewer) {
      setState(() {});
    }
  }

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
        child: const Text("Toggle framerate (currently ) "),
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
              const SubmenuButton(
                menuChildren: <Widget>[],
                child: Text("Camera"),
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
