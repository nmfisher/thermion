import 'dart:math';

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_flutter_example/main.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

class AssetSubmenu extends StatefulWidget {
  final ThermionFlutterPlugin controller;
  const AssetSubmenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _AssetSubmenuState();
}

class _AssetSubmenuState extends State<AssetSubmenu> {
  @override
  void initState() {
    super.initState();
  }

  Widget _shapesSubmenu() {
    var children = [
      MenuItemButton(
          closeOnActivate: false,
          onPressed: () async {
            var entity = await widget.controller.viewer.getChildEntity(
                widget.controller.viewer.scene.listEntities().last, "Cylinder");
            await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Center(
                      child: Container(
                          color: Colors.white, child: Text(entity.toString())));
                });
          },
          child: const Text('Find Cylinder entity by name')),
      MenuItemButton(
        onPressed: () async {
          widget.controller.viewer.setPosition(
              widget.controller.viewer.scene.listEntities().last,
              1.0,
              1.0,
              -1.0);
        },
        child: const Text('Set position to 1, 1, -1'),
      ),
      MenuItemButton(
          onPressed: () async {
            final color = Colors.purple;
            widget.controller.viewer.setMaterialColor(
                widget.controller.viewer.scene.listEntities().last,
                "Cone",
                0,
                color.red / 255.0,
                color.green / 255.0,
                color.blue / 255.0,
                1.0);
          },
          child: const Text("Set cone material color to purple")),
    ];

    return SubmenuButton(menuChildren: children, child: const Text("Shapes"));
  }

  Widget _geometrySubmenu() {
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
            onPressed: () async {
              var verts = [
                -1.0,
                0.0,
                -1.0,
                -1.0,
                0.0,
                1.0,
                1.0,
                0.0,
                1.0,
                1.0,
                0.0,
                -1.0,
              ];
              var indices = [0, 1, 2, 2, 3, 0];
              var geom = await widget.controller.viewer.createGeometry(
                  verts, indices,
                  materialPath: "asset://assets/solidcolor.filamat");
            },
            child: const Text("Quad")),
        MenuItemButton(
            onPressed: () async {
              await widget.controller.viewer.createGeometry([
                0,
                0,
                0,
                1,
                0,
                0,
              ], [
                0,
                1
              ], primitiveType: PrimitiveType.LINES);
            },
            child: const Text("Line"))
      ],
      child: const Text("Custom Geometry"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      menuChildren: [
        _shapesSubmenu(),
        _geometrySubmenu(),
        MenuItemButton(
          onPressed: () async {
            await widget.controller.viewer.addLight(
                LightType.DIRECTIONAL, 6500, 100000, 0, 1, 0, 0, -1, 0);
          },
          child: const Text("Add directional light"),
        ),
        MenuItemButton(
          onPressed: () async {
            await widget.controller.viewer.addLight(
                LightType.POINT, 6500, 100000, 0, 1, 0, 0, -1, 0,
                falloffRadius: 1.0);
          },
          child: const Text("Add point light"),
        ),
        MenuItemButton(
          onPressed: () async {
            await widget.controller.viewer.addLight(
                LightType.SPOT, 6500, 1000000, 0, 0, 0, 0, 1, 0,
                spotLightConeInner: 0.1,
                spotLightConeOuter: 0.4,
                falloffRadius: 100.0);
          },
          child: const Text("Add spot light"),
        ),
        MenuItemButton(
          onPressed: () async {
            await widget.controller.viewer.clearLights();
          },
          child: const Text("Clear lights"),
        ),
        MenuItemButton(
            onPressed: () {
              final color = const Color(0xAA73C9FA);
              widget.controller.viewer.setBackgroundColor(color.red / 255.0,
                  color.green / 255.0, color.blue / 255.0, 1.0);
            },
            child: const Text("Set background color")),
        MenuItemButton(
            onPressed: () {
              widget.controller.viewer
                  .setBackgroundImage('assets/background.ktx');
            },
            child: const Text("Load background image")),
        MenuItemButton(
            onPressed: () {
              widget.controller.viewer.setBackgroundImage(
                  'assets/background.ktx',
                  fillHeight: true);
            },
            child: const Text("Load background image (fill height)")),
        MenuItemButton(
            onPressed: () {
              if (ExampleWidgetState.hasSkybox) {
                widget.controller.viewer.removeSkybox();
              } else {
                widget.controller.viewer
                    .loadSkybox('assets/default_env/default_env_skybox.ktx');
              }
              ExampleWidgetState.hasSkybox = !ExampleWidgetState.hasSkybox;
            },
            child: Text(ExampleWidgetState.hasSkybox
                ? 'Remove skybox'
                : 'Load skybox')),
        MenuItemButton(
            onPressed: () {
              widget.controller.viewer
                  .loadIbl('assets/default_env/default_env_ibl.ktx');
            },
            child: const Text('Load IBL')),
        MenuItemButton(
            onPressed: () {
              widget.controller.viewer.removeIbl();
            },
            child: const Text('Remove IBL')),
        MenuItemButton(
            onPressed: () async {
              await widget.controller.viewer.clearEntities();
            },
            child: const Text('Clear assets')),
      ],
      child: const Text("Assets"),
    );
  }
}

//           _item(() async {
//             var frameData = Float32List.fromList(
//                 List<double>.generate(120, (i) => i / 120).expand((x) {
//               var vals = List<double>.filled(7, x);
//               vals[3] = 1.0;
//               // vals[4] = 0;
//               vals[5] = 0;
//               vals[6] = 0;
//               return vals;
//             }).toList());

//             widget.controller!.setBoneAnimation(
//                 _shapes!,
//                 BoneAnimationData(
//                     "Bone.001", ["Cube.001"], frameData, 1000.0 / 60.0));
//             //     ,
//             //     "Bone.001",
//             //     "Cube.001",
//             //     BoneTransform([Vec3(x: 0, y: 0.0, z: 0.0)],
//             //         [Quaternion(x: 1, y: 1, z: 1, w: 1)]));
//           }, 'construct bone animation'),

//           _item(() async {
//             var morphs = await widget.controller!
//                 .getMorphTargetNames(_shapes!, "Cylinder");
//             final animation = AnimationBuilder(
//                     availableMorphs: morphs,
//                     framerate: 30,
//                     meshName: "Cylinder")
//                 .setDuration(4)
//                 .setMorphTargets(["Key 1", "Key 2"])
//                 .interpolateMorphWeights(0, 4, 0, 1)
//                 .build();
//             widget.controller!.setMorphAnimationData(_shapes!, animation);
//           }, "animate cylinder morph weights #1 and #2"),
//           _item(() async {
//             var morphs = await widget.controller!
//                 .getMorphTargetNames(_shapes!, "Cylinder");
//             final animation = AnimationBuilder(
//                     availableMorphs: morphs,
//                     framerate: 30,
//                     meshName: "Cylinder")
//                 .setDuration(4)
//                 .setMorphTargets(["Key 3", "Key 4"])
//                 .interpolateMorphWeights(0, 4, 0, 1)
//                 .build();
//             widget.controller!.setMorphAnimationData(_shapes!, animation);
//           }, "animate cylinder morph weights #3 and #4"),
//           _item(() async {
//             var morphs = await widget.controller!
//                 .getMorphTargetNames(_shapes!, "Cube");
//             final animation = AnimationBuilder(
//                     availableMorphs: morphs, framerate: 30, meshName: "Cube")
//                 .setDuration(4)
//                 .setMorphTargets(["Key 1", "Key 2"])
//                 .interpolateMorphWeights(0, 4, 0, 1)
//                 .build();
//             widget.controller!.setMorphAnimationData(_shapes!, animation);
//           }, "animate shapes morph weights #1 and #2"),
