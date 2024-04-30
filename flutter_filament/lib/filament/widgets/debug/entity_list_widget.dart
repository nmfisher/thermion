import 'package:dart_filament/dart_filament/entities/filament_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_filament/filament/flutter_filament_plugin.dart';

class EntityListWidget extends StatefulWidget {
  final FlutterFilamentPlugin? controller;

  const EntityListWidget({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _EntityListWidget();
}

class _EntityListWidget extends State<EntityListWidget> {
  @override
  void didUpdateWidget(EntityListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Widget _entity(FilamentEntity entity) {
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
                          .map((a) => MenuItemButton(
                                child: Text(a),
                                onPressed: () {
                                  widget.controller!.playAnimation(
                                      entity, animations.data!.indexOf(a));
                                },
                              ))
                          .toList())
                ])
          ]);
        });
  }

  Widget _light(FilamentEntity entity) {
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
      return Container();
    }
    return FutureBuilder(
        future: widget.controller!.initialized,
        builder: (_, AsyncSnapshot<bool> initialized) =>
            initialized.data != true
                ? Container()
                : StreamBuilder(
                    stream: widget.controller!.scene.onUpdated,
                    builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 10),
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.white.withOpacity(0.25),
                        ),
                        child: ListView(
                            reverse: true,
                            children: widget.controller!.scene
                                .listLights()
                                .map(_light)
                                .followedBy(widget.controller!.scene
                                    .listEntities()
                                    .map(_entity))
                                .cast<Widget>()
                                .toList()))));
  }
}
