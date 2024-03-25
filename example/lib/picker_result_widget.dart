import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';

class PickerResultWidget extends StatelessWidget {
  final FilamentController controller;

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
