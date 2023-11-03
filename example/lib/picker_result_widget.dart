import 'package:flutter/material.dart';
import 'package:flutter_filament/filament_controller.dart';

class PickerResultWidget extends StatelessWidget {
  final FilamentController controller;

  const PickerResultWidget({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: controller.pickResult.map((FilamentEntity? entityId) {
          if (entityId == null) {
            return null;
          }
          return controller.getNameForEntity(entityId);
        }),
        builder: (ctx, snapshot) => snapshot.data == null
            ? Container()
            : Text(snapshot.data!,
                style: const TextStyle(color: Colors.green, fontSize: 24)));
  }
}
