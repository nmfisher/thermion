import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart/abstract_filament_viewer.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

class SkeletonMenuItemWidget extends StatelessWidget {
  final AbstractFilamentViewer controller;
  final FilamentEntity entity;

  const SkeletonMenuItemWidget(
      {super.key, required this.controller, required this.entity});

  void _addBoneAnimation(String bone) async {
    await controller.addAnimationComponent(entity);
    var numFrames = 120;
    var animationData = List<List<BoneAnimationFrame>>.generate(
        numFrames,
        (frameNum) => [
              (
                rotation: Quaternion.axisAngle(
                    Vector3(1, 0, 0), (frameNum / 90) * 2 * pi),
                translation: Vector3.zero()
              )
            ]);
    var animation =
        BoneAnimationData([bone], animationData, space: Space.ParentWorldRotation);
    await controller.addAnimationComponent(entity);
    await controller.addBoneAnimation(entity, animation);
  }

  @override
  Widget build(BuildContext context) {
    var boneNames = controller.getBoneNames(entity);

    return FutureBuilder(
        future: boneNames,
        builder: (_, boneNamesSnapshot) {
          if (!boneNamesSnapshot.hasData) {
            return Container();
          }
          var boneNames = boneNamesSnapshot.data!;
          if (boneNames.isEmpty) {
            return Text("No bones");
          }

          return SubmenuButton(
              menuChildren: <Widget>[
                    MenuItemButton(
                        onPressed: () async {
                          await controller.resetBones(entity);
                        },
                        child: Text("Reset")),
                    MenuItemButton(
                        onPressed: () async {
                          await controller.resetBones(entity);

                          var bone = await controller.getBone(entity, 1);
                          var frames = <List<BoneAnimationFrame>>[];
                          for (int i = 0; i < 60; i++) {
                            var frame = <BoneAnimationFrame>[];
                            frame.add((
                              rotation: 
                              Quaternion.axisAngle(
                                      Vector3(1, 0, 0), i/60 * pi/4) * 
                                      (Quaternion.axisAngle(
                                          Vector3(0, 0, 1), i/60*-pi/4) 
                                       * 
                                      Quaternion.axisAngle(
                                          Vector3(0, 1, 0), i/60 * pi/4) ),
                              translation: Vector3.zero()
                            ));
                            frames.add(frame);
                          }

                          var animation = BoneAnimationData(["Bone.002"], frames,
                              space: Space.ParentWorldRotation);
                          await controller.addAnimationComponent(entity);
                          await controller.addBoneAnimation(entity, animation);
                        },
                        child: Text("Test animation (parent space)")),
                    MenuItemButton(
                        onPressed: () async {
                          await controller.resetBones(entity);

                          var bone = await controller.getBone(entity, 1);

                          var frames = <List<BoneAnimationFrame>>[];
                          for (int i = 0; i < 60; i++) {
                            var frame = <BoneAnimationFrame>[];
                            frame.add((
                              rotation: Quaternion.axisAngle(
                                  Vector3(0, 0, 1), (i / 60) * pi / 2),
                              translation: Vector3.zero()
                            ));
                            frames.add(frame);
                          }
                          var animation = BoneAnimationData(
                              ["Bone.001"], frames,
                              space: Space.Bone);
                          await controller.addAnimationComponent(entity);
                          await controller.addBoneAnimation(entity, animation);
                        },
                        child: Text("Test animation (bone space)")),
                    MenuItemButton(
                        onPressed: () async {
                          var frames = <List<BoneAnimationFrame>>[];
                          for (int i = 0; i < 60; i++) {
                            var frame = <BoneAnimationFrame>[];
                            frame.add((
                              rotation: Quaternion.axisAngle(
                                  Vector3(0, 0, 1), (i / 60) * pi / 2),
                              translation: Vector3.zero()
                            ));
                            frames.add(frame);
                          }
                          var animation = BoneAnimationData(
                              ["Bone.001"], frames,
                              space: Space.ParentWorldRotation);
                          await controller.addAnimationComponent(entity);
                          await controller.addBoneAnimation(entity, animation);
                        },
                        child: Text("Test animation 2")),
                    MenuItemButton(
                        onPressed: () async {
                          var frames = <List<BoneAnimationFrame>>[];
                          for (int i = 0; i < 60; i++) {
                            var frame = <BoneAnimationFrame>[];
                            frame.add((
                              rotation: Quaternion.axisAngle(
                                  Vector3(0, 0, 1), (i / 60) * pi / 2),
                              translation: Vector3.zero()
                            ));
                            frames.add(frame);
                          }
                          var animation = BoneAnimationData(
                              ["Bone.002"], frames,
                              space: Space.ParentWorldRotation);
                          await controller.addAnimationComponent(entity);
                          await controller.addBoneAnimation(entity, animation);
                        },
                        child: Text("Test animation 3"))
                  ] +
                  boneNames
                      .map((name) {
                        var boneIndex = boneNames.indexOf(name);
                        return SubmenuButton(child: Text(name), menuChildren: [
                          MenuItemButton(
                              child: Text("Print bone transforms "),
                              onPressed: () async {
                                var boneEntity =
                                    await controller.getBone(entity, boneIndex);
                                var localTransform = await controller
                                    .getLocalTransform(boneEntity);
                                var worldTransform = await controller
                                    .getWorldTransform(boneEntity);
                                var inverseWorldTransform = Matrix4.identity()
                                  ..copyInverse(worldTransform);
                                print("Local $localTransform");
                                print("World $worldTransform");
                                print("World inverse $inverseWorldTransform");
                              }),
                          MenuItemButton(
                              child: Text("Set bone transform to identity"),
                              onPressed: () async {
                                var boneEntity =
                                    await controller.getBone(entity, boneIndex);
                                var localTransform = Matrix4.identity();
                                await controller.setTransform(
                                    boneEntity, localTransform);
                                await controller.updateBoneMatrices(entity);
                              }),
                          MenuItemButton(
                              child: Text(
                                  "Set bone transform to 90/X (parent space)"),
                              onPressed: () async {
                                var boneEntity =
                                    await controller.getBone(entity, boneIndex);
                                var localTransform = Matrix4.rotationX(pi / 2);
                                await controller.setTransform(
                                    boneEntity, localTransform);
                                await controller.updateBoneMatrices(entity);
                              }),
                          MenuItemButton(
                              child: Text(
                                  "Set bone transform to 90/X (pose space)"),
                              onPressed: () async {
                                var boneEntity =
                                    await controller.getBone(entity, boneIndex);
                                var localTransform = await controller
                                    .getLocalTransform(boneEntity);
                                localTransform =
                                    localTransform * Matrix4.rotationX(pi / 2);
                                await controller.setTransform(
                                    boneEntity, localTransform);
                                await controller.updateBoneMatrices(entity);
                              }),
                          MenuItemButton(
                              child: Text("Set bone transform to 90/X"),
                              onPressed: () async {
                                var boneEntity =
                                    await controller.getBone(entity, boneIndex);
                                var localTransform = Matrix4.rotationX(pi / 2);
                                await controller.setTransform(
                                    boneEntity, localTransform);
                                await controller.updateBoneMatrices(entity);
                              }),
                          MenuItemButton(
                              child: Text("Set bone transform to 0,-1,0"),
                              onPressed: () async {
                                var boneEntity =
                                    await controller.getBone(entity, boneIndex);
                                var localTransform =
                                    Matrix4.translation(Vector3(0, -1, 0));
                                await controller.setTransform(
                                    boneEntity, localTransform);
                                await controller.updateBoneMatrices(entity);
                              }),
                          MenuItemButton(
                              child: Text(
                                  "Set bone matrices/transform to identity"),
                              onPressed: () async {
                                var boneEntity = await controller.getBone(
                                    entity, boneNames.indexOf(name));
                                await controller.setTransform(
                                    boneEntity, Matrix4.identity());
                                var childEntities = await controller
                                    .getChildEntities(entity, true);
                                for (final child in childEntities) {
                                  await controller.setBoneTransform(
                                      child,
                                      boneNames.indexOf(name),
                                      Matrix4.identity());
                                }
                              }),
                          SubmenuButton(
                              child: Text("Set bone matrices to"),
                              menuChildren: [
                                MenuItemButton(
                                    child: Text("Identity"),
                                    onPressed: () async {
                                      await controller
                                          .removeAnimationComponent(entity);
                                      for (var child in await controller
                                          .getChildEntities(entity, true)) {
                                        print(
                                            "Setting transform for ${await controller.getNameForEntity(child)}");
                                        await controller.setBoneTransform(
                                            child,
                                            boneNames.indexOf(name),
                                            Matrix4.identity());
                                      }
                                    }),
                                SubmenuButton(
                                    child: Text("Global"),
                                    menuChildren: ["90/X", "90/Y"]
                                        .map((rot) => MenuItemButton(
                                            onPressed: () async {
                                              var transform = rot == "90/X"
                                                  ? Matrix4.rotationX(pi / 2)
                                                  : Matrix4.rotationY(pi / 2);
                                              await controller
                                                  .removeAnimationComponent(
                                                      entity);

                                              var index =
                                                  boneNames.indexOf(name);
                                              var childEntities =
                                                  await controller
                                                      .getChildEntities(
                                                          entity, true);

                                              for (var child in childEntities) {
                                                print(
                                                    "Setting transform for ${await controller.getNameForEntity(child)} / bone $name (index $index)");
                                                await controller
                                                    .setBoneTransform(child,
                                                        index, transform);
                                              }
                                            },
                                            child: Text(rot)))
                                        .toList()),
                                SubmenuButton(
                                    child: Text("Bone"),
                                    menuChildren: ["90/X", "90/Y", "90/Z"]
                                        .map((rot) => MenuItemButton(
                                            onPressed: () async {
                                              await controller
                                                  .removeAnimationComponent(
                                                      entity);
                                              var index =
                                                  boneNames.indexOf(name);
                                              var boneEntity = await controller
                                                  .getBone(entity, index);
                                              var rotation = rot == "90/X"
                                                  ? Matrix4.rotationX(pi / 2)
                                                  : rot == "90/Y"
                                                      ? Matrix4.rotationY(
                                                          pi / 2)
                                                      : Matrix4.rotationZ(
                                                          pi / 2);

                                              var inverseBindMatrix =
                                                  await controller
                                                      .getInverseBindMatrix(
                                                          entity, index);
                                              var bindMatrix =
                                                  Matrix4.identity();
                                              bindMatrix.copyInverse(
                                                  inverseBindMatrix);
                                              var childEntities =
                                                  await controller
                                                      .getChildEntities(
                                                          entity, true);

                                              for (var child in childEntities) {
                                                var childGlobalTransform =
                                                    await controller
                                                        .getWorldTransform(
                                                            child);
                                                var inverseGlobalTransform =
                                                    Matrix4.identity();
                                                inverseGlobalTransform
                                                    .copyInverse(
                                                        childGlobalTransform);
                                                var globalBoneTransform =
                                                    childGlobalTransform *
                                                        bindMatrix;

                                                var transform =
                                                    (inverseGlobalTransform *
                                                            (globalBoneTransform *
                                                                rotation)) *
                                                        inverseBindMatrix;
                                                await controller
                                                    .setBoneTransform(child,
                                                        index, transform);
                                              }
                                            },
                                            child: Text(rot)))
                                        .toList()),
                              ]),
                          MenuItemButton(
                              onPressed: () => _addBoneAnimation(name),
                              child: Text(
                                  "Test animation (90 degreees around pose Y)")),
                        ]);
                      })
                      .cast<Widget>()
                      .toList(),
              child: Text("Skeleton"));
        });
  }
}

                    // MenuItemButton(
                    //     onPressed: () async {
                    //       var frames = <List<BoneAnimationFrame>>[];
                    //       for (int i = 0; i < 60; i++) {
                    //         var frame = <BoneAnimationFrame>[];
                    //         frame.add((
                    //           rotation: Quaternion.axisAngle(
                    //               Vector3(0, 0, 1), (i / 60) * pi / 2),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frame.add((
                    //           rotation: Quaternion.identity(),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frame.add((
                    //           rotation: Quaternion.identity(),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frames.add(frame);
                    //       }
                    //       for (int i = 0; i < 60; i++) {
                    //         var frame = <BoneAnimationFrame>[];
                    //         frame.add((
                    //           rotation: Quaternion.axisAngle(
                    //               Vector3(0, 0, 1), pi / 2),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frame.add((
                    //           rotation: Quaternion.axisAngle(
                    //               Vector3(1, 0, 0), i / 60 * (-pi / 2)),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frame.add((
                    //           rotation: Quaternion.identity(),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frames.add(frame);
                    //       }
                    //       for (int i = 0; i < 60; i++) {
                    //         var frame = <BoneAnimationFrame>[];
                    //         frame.add((
                    //           rotation: Quaternion.axisAngle(
                    //               Vector3(0, 0, 1), pi / 2),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frame.add((
                    //           rotation: Quaternion.axisAngle(
                    //               Vector3(1, 0, 0), (-pi / 2)),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frame.add((
                    //           rotation: Quaternion.axisAngle(
                    //               Vector3(1, 0, 0), i / 60 * (pi / 2)),
                    //           translation: Vector3.zero()
                    //         ));
                    //         frames.add(frame);
                    //       }

                    //       var animation = BoneAnimationData(
                    //           ["Bone", "Bone.001", "Bone.002"], frames);
                    //       await controller.addAnimationComponent(entity);
                    //       await controller.addBoneAnimation(entity, animation);
                    //     },
                    //     child: Text("Test animation (pose space)")),