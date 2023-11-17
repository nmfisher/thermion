import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament_example/main.dart';
import 'package:permission_handler/permission_handler.dart';

class AssetSubmenu extends StatefulWidget {
  final FilamentController controller;
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
          onPressed: () async {
            if (ExampleWidgetState.shapes == null) {
              ExampleWidgetState.shapes =
                  await widget.controller.loadGlb('assets/shapes/shapes.glb');
              ExampleWidgetState.animations = await widget.controller
                  .getAnimationNames(ExampleWidgetState.shapes!);
            } else {
              await widget.controller.removeAsset(ExampleWidgetState.shapes!);
              ExampleWidgetState.shapes = null;
              ExampleWidgetState.animations = null;
            }
          },
          child: const Text('Load GLB')),
      MenuItemButton(
          onPressed: ExampleWidgetState.shapes != null
              ? null
              : () async {
                  if (ExampleWidgetState.shapes != null) {
                    widget.controller.removeAsset(ExampleWidgetState.shapes!);
                  }
                  ExampleWidgetState.shapes = await widget.controller
                      .loadGltf('assets/shapes/shapes.gltf', 'assets/shapes');
                },
          child: const Text('Load GLTF')),
      MenuItemButton(
          onPressed: ExampleWidgetState.shapes == null
              ? null
              : () async {
                  await widget.controller
                      .transformToUnitCube(ExampleWidgetState.shapes!);
                },
          child: const Text('Transform to unit cube')),
      MenuItemButton(
          onPressed: ExampleWidgetState.shapes == null
              ? null
              : () async {
                  await widget.controller.setBoneTransform(
                      ExampleWidgetState.shapes!,
                      "Cylinder",
                      0,
                      Matrix4.rotationX(pi / 2));
                },
          child: const Text('Set bone tranform to identity for Cylinder')),
      MenuItemButton(
          onPressed: () async {
            var names = await widget.controller
                .getMorphTargetNames(ExampleWidgetState.shapes!, "Cylinder");
            await showDialog(
                context: context,
                builder: (ctx) {
                  return Container(
                      height: 100,
                      width: 100,
                      color: Colors.white,
                      child: Text(names.join(",")));
                });
          },
          child: const Text("Show morph target names for Cylinder")),
      MenuItemButton(
          onPressed: () async {
            widget.controller.setMorphTargetWeights(
                ExampleWidgetState.shapes!, "Cylinder", List.filled(4, 1.0));
          },
          child: const Text("set Cylinder morph weights to 1")),
      MenuItemButton(
          onPressed: () async {
            widget.controller.setMorphTargetWeights(
                ExampleWidgetState.shapes!, "Cylinder", List.filled(4, 0.0));
          },
          child: const Text("Set Cylinder morph weights to 0")),
      MenuItemButton(
        onPressed: () async {
          widget.controller
              .setPosition(ExampleWidgetState.shapes!, 1.0, 1.0, -1.0);
        },
        child: const Text('Set position to 1, 1, -1'),
      ),
      MenuItemButton(
          onPressed: () async {
            if (ExampleWidgetState.coneHidden) {
              widget.controller.reveal(ExampleWidgetState.shapes!, "Cone");
            } else {
              widget.controller.hide(ExampleWidgetState.shapes!, "Cone");
            }

            ExampleWidgetState.coneHidden = !ExampleWidgetState.coneHidden;
          },
          child:
              Text(ExampleWidgetState.coneHidden ? 'show cone' : 'hide cone')),
      MenuItemButton(
          onPressed: ExampleWidgetState.shapes == null
              ? null
              : () async {
                  widget.controller.setMaterialColor(
                      ExampleWidgetState.shapes!, "Cone", 0, Colors.purple);
                },
          child: const Text("Set cone material color to purple")),
      MenuItemButton(
          onPressed: () async {
            ExampleWidgetState.loop = !ExampleWidgetState.loop;
          },
          child: Text(
              "Toggle animation looping ${ExampleWidgetState.loop ? "OFF" : "ON"}"))
    ];
    if (ExampleWidgetState.animations != null) {
      children.addAll(ExampleWidgetState.animations!.map((a) => MenuItemButton(
          onPressed: () {
            widget.controller.playAnimation(ExampleWidgetState.shapes!,
                ExampleWidgetState.animations!.indexOf(a),
                replaceActive: true,
                crossfade: 0.5,
                loop: ExampleWidgetState.loop);
          },
          child: Text(
              "play animation ${ExampleWidgetState.animations!.indexOf(a)} (replace/fade)"))));
      children.addAll(ExampleWidgetState.animations!.map((a) => MenuItemButton(
          onPressed: () {
            widget.controller.playAnimation(ExampleWidgetState.shapes!,
                ExampleWidgetState.animations!.indexOf(a),
                replaceActive: false, loop: ExampleWidgetState.loop);
          },
          child: Text(
              "Play animation ${ExampleWidgetState.animations!.indexOf(a)} (noreplace)"))));
    }

    return SubmenuButton(menuChildren: children, child: const Text("Shapes"));
  }

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      menuChildren: [
        _shapesSubmenu(),
        MenuItemButton(
          onPressed: () async {
            ExampleWidgetState.directionalLight = await widget.controller
                .addLight(1, 6500, 150000, 0, 1, 0, 0, -1, 0, true);
          },
          child: const Text("Add directional light"),
        ),
        MenuItemButton(
          onPressed: () async {
            await widget.controller.clearLights();
          },
          child: const Text("Clear lights"),
        ),
        MenuItemButton(
            onPressed: () async {
              if (ExampleWidgetState.buster == null) {
                ExampleWidgetState.buster = await widget.controller.loadGltf(
                    "assets/BusterDrone/scene.gltf", "assets/BusterDrone",
                    force: true);
                await widget.controller
                    .playAnimation(ExampleWidgetState.buster!, 0, loop: true);
                ExampleWidgetState.animations = await widget.controller
                    .getAnimationNames(ExampleWidgetState.shapes!);
              } else {
                await widget.controller.removeAsset(ExampleWidgetState.buster!);
                ExampleWidgetState.buster = null;
              }
            },
            child: Text(ExampleWidgetState.buster == null
                ? 'Load buster'
                : 'Remove buster')),
        MenuItemButton(
            onPressed: () async {
              if (ExampleWidgetState.flightHelmet == null) {
                ExampleWidgetState.flightHelmet ??= await widget.controller
                    .loadGltf('assets/FlightHelmet/FlightHelmet.gltf',
                        'assets/FlightHelmet',
                        force: true);
              } else {
                await widget.controller
                    .removeAsset(ExampleWidgetState.flightHelmet!);
                ExampleWidgetState.flightHelmet = null;
              }
            },
            child: Text(ExampleWidgetState.flightHelmet == null
                ? 'Load flight helmet'
                : 'Remove flight helmet')),
        MenuItemButton(
            onPressed: () {
              widget.controller.setBackgroundColor(const Color(0xFF73C9FA));
            },
            child: const Text("Set background color")),
        MenuItemButton(
            onPressed: () {
              widget.controller.setBackgroundImage('assets/background.ktx');
            },
            child: const Text("Load background image")),
        MenuItemButton(
            onPressed: () {
              widget.controller.setBackgroundImage('assets/background.ktx',
                  fillHeight: true);
            },
            child: const Text("Load background image (fill height)")),
        MenuItemButton(
            onPressed: () {
              if (ExampleWidgetState.hasSkybox) {
                widget.controller.removeSkybox();
              } else {
                widget.controller
                    .loadSkybox('assets/default_env/default_env_skybox.ktx');
              }
              ExampleWidgetState.hasSkybox = !ExampleWidgetState.hasSkybox;
            },
            child: Text(ExampleWidgetState.hasSkybox
                ? 'Remove skybox'
                : 'Load skybox')),
        MenuItemButton(
            onPressed: () {
              widget.controller
                  .loadIbl('assets/default_env/default_env_ibl.ktx');
            },
            child: const Text('Load IBL')),
        MenuItemButton(
            onPressed: () async {
              await Permission.microphone.request();
            },
            child: const Text("Request permissions (tests inactive->resume)")),
        MenuItemButton(
            onPressed: () async {
              await widget.controller.clearAssets();
              ExampleWidgetState.flightHelmet = null;
              ExampleWidgetState.buster = null;
              ExampleWidgetState.shapes = null;
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

