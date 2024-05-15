import 'package:flutter/material.dart';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';

class PickerResultWidget extends StatelessWidget {
  final AbstractFilamentViewer controller;

  const PickerResultWidget({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: controller.pickResult.map((result) {
          return controller.getNameForEntity(result.entity);
        }),
        builder: (ctx, snapshot) => snapshot.data == null
            ? Container()
            : Text(snapshot.data!,
                style: const TextStyle(color: Colors.green, fontSize: 24)));
  }
}
