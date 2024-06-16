import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

import 'package:thermion_flutter/filament/widgets/debug/child_renderable_widget.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/filament/widgets/debug/skeleton_menu_item_widget.dart';

class EntityListWidget extends StatefulWidget {
  final ThermionViewer? controller;

  const EntityListWidget({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _EntityListWidget();
}

class _EntityListWidget extends State<EntityListWidget> {
  @override
  void didUpdateWidget(EntityListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Widget _entity(ThermionEntity entity) {
    return FutureBuilder(
        future: widget.controller!.getAnimationNames(entity),
        builder: (_, animations) {
          if (animations.data == null) {
            return Container();
          }
          final menuController = MenuController();
          return Row(children: [
            Expanded(
                child: GestureDetector(
                    onTap: () {
                      widget.controller!.scene.select(entity);
                    },
                    child: Text(entity.toString(),
                        style: TextStyle(
                            fontWeight:
                                entity == widget.controller!.scene.selected
                                    ? FontWeight.bold
                                    : FontWeight.normal)))),
            MenuAnchor(
                controller: menuController,
                child: Container(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        menuController.open();
                      },
                    )),
                menuChildren: [
                  MenuItemButton(
                      child: const Text("Remove"),
                      onPressed: () async {
                        await widget.controller!.removeEntity(entity);
                      }),
                  MenuItemButton(
                      child: const Text("Transform to unit cube"),
                      onPressed: () async {
                        await widget.controller!.transformToUnitCube(entity);
                      }),
                  SubmenuButton(
                      child: const Text("Animations"),
                      menuChildren: animations.data!
                          .map((a) => SubmenuButton(
                                  child: Text(a),
                                  menuChildren: [
                                    MenuItemButton(
                                      child: Text("Play"),
                                      onPressed: () async {
                                        await widget.controller!
                                            .addAnimationComponent(entity);
                                        widget.controller!.playAnimation(entity,
                                            animations.data!.indexOf(a));
                                      },
                                    ),
                                    MenuItemButton(
                                      child: Text("Loop"),
                                      onPressed: () async {
                                        await widget.controller!
                                            .addAnimationComponent(entity);
                                        widget.controller!.playAnimation(
                                            entity, animations.data!.indexOf(a),
                                            loop: true);
                                      },
                                    ),
                                    MenuItemButton(
                                      child: Text("Stop"),
                                      onPressed: () async {
                                        await widget.controller!
                                            .addAnimationComponent(entity);
                                        widget.controller!.stopAnimation(
                                            entity, animations.data!.indexOf(a));
                                      },
                                    )
                                  ]))
                          .toList()),
                  ChildRenderableWidget(
                      controller: widget.controller!, entity: entity),
                  SkeletonMenuItemWidget(
                      controller: widget.controller!, entity: entity)
                ])
          ]);
        });
  }

  Widget _light(ThermionEntity entity) {
    final controller = MenuController();
    return Row(children: [
      GestureDetector(
          onTap: () {
            widget.controller!.scene.select(entity);
          },
          child: Container(
              color: Colors.transparent,
              child: Text("Light $entity",
                  style: TextStyle(
                      fontWeight: entity == widget.controller!.scene.selected
                          ? FontWeight.bold
                          : FontWeight.normal)))),
      MenuAnchor(
          controller: controller,
          child: Container(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black,
                ),
                onPressed: () {
                  controller.open();
                },
              )),
          menuChildren: [
            MenuItemButton(
                child: const Text("Remove"),
                onPressed: () async {
                  await widget.controller!.removeLight(entity);
                })
          ])
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller == null) {
      return Container(color: Colors.red);
    }
    return FutureBuilder(
        future: widget.controller!.initialized,
        builder: (_, snapshot) => snapshot.data != true
            ? Container()
            : StreamBuilder(
                stream: widget.controller!.scene.onUpdated,
                builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withOpacity(0.25),
                    ),
                    child: SingleChildScrollView(
                        child: Column(
                            // reverse: true,
                            children: widget.controller!.scene
                                .listLights()
                                .map(_light)
                                .followedBy(widget.controller!.scene
                                    .listEntities()
                                    .map(_entity))
                                .cast<Widget>()
                                .toList())))));
  }
}
