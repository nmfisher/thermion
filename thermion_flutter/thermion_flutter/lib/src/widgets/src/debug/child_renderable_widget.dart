import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'package:flutter/material.dart';
import 'dart:math';

class ChildRenderableWidget extends StatelessWidget {
  final ThermionViewer controller;
  final ThermionEntity entity;

  const ChildRenderableWidget(
      {super.key, required this.controller, required this.entity});

  Widget _childRenderable(ThermionEntity childEntity) {
    var name = controller.getNameForEntity(childEntity) ?? "<none>";
    var names = controller.getMorphTargetNames(entity, childEntity);

    return FutureBuilder(
        future: names,
        builder: (_, morphTargetsSnapshot) {
          if (!morphTargetsSnapshot.hasData) {
            return Container();
          }
          var morphTargets = morphTargetsSnapshot.data!;

          final menuChildren = <Widget>[];
          if (morphTargets.isEmpty) {
            menuChildren.add(Text("None"));
          } else {
            for (int i = 0; i < 2; i++) {
              var newWeights = List.filled(morphTargets.length, i.toDouble());
              menuChildren.add(MenuItemButton(
                  child: Text("Set to $i"),
                  onPressed: () async {
                    try {
                      await controller!
                          .setMorphTargetWeights(childEntity, newWeights);
                    } catch (err, st) {
                      print("Error setting morph target weights");
                      print(err);
                      print(st);
                    }
                  }));
            }
            menuChildren.add(MenuItemButton(
                child: Text("Animate all morph target from 0 to 1"),
                onPressed: () async {
                  var morphData = MorphAnimationData(
                      List<List<double>>.generate(
                          120,
                          (i) => List<double>.filled(
                              morphTargets.length, i / 120)),
                      morphTargets);
                  await controller!.setMorphAnimationData(entity, morphData,
                      targetMeshNames: [name]);
                }));
            menuChildren.addAll(morphTargets.map((t) => Text(t)));
          }
          return SubmenuButton(child: Text(name), menuChildren: menuChildren);
        });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: controller!.getChildEntities(entity, true),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }

          var children = snapshot.data!;
          return SubmenuButton(
              child: Text("Renderable entities"),
              menuChildren: <Widget>[
                MenuItemButton(
                        child: Text("Set children transforms to identity"),
                        onPressed: () async {
                          var childEntities =
                              await controller.getChildEntities(entity, true);
                          for (final child in childEntities) {
                            await controller.setTransform(
                                child, Matrix4.identity());
                          }
                        }),
                    MenuItemButton(
                        child: Text("Set children transforms to 90/X"),
                        onPressed: () async {
                          var childEntities =
                              await controller.getChildEntities(entity, true);
                          for (final child in childEntities) {
                            await controller.setTransform(
                                child, Matrix4.rotationX(pi / 2));
                          }
                        }),
                          MenuItemButton(
                        child: Text("Set children transforms to 90/Y"),
                        onPressed: () async {
                          var childEntities =
                              await controller.getChildEntities(entity, true);
                          for (final child in childEntities) {
                            await controller.setTransform(
                                child, Matrix4.rotationY(pi / 2));
                          }
                        }),
                  ] +
                  children.map(_childRenderable).toList());
        });
  }
}
