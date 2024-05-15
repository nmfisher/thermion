import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament_example/main.dart';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';

class RenderingSubmenu extends StatefulWidget {
  final FlutterFilamentPlugin controller;

  const RenderingSubmenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _RenderingSubmenuState();
}

class _RenderingSubmenuState extends State<RenderingSubmenu> {
  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      menuChildren: [
        MenuItemButton(
          onPressed: () {
            widget.controller.viewer.render();
          },
          child: const Text("Render single frame"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.rendering = !ExampleWidgetState.rendering;
            widget.controller.viewer.setRendering(ExampleWidgetState.rendering);
          },
          child: Text(
              "Set continuous rendering to ${!ExampleWidgetState.rendering}"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.framerate =
                ExampleWidgetState.framerate == 60 ? 30 : 60;
            widget.controller.viewer.setFrameRate(ExampleWidgetState.framerate);
          },
          child: Text(
              "Toggle framerate (currently ${ExampleWidgetState.framerate}) "),
        ),
        MenuItemButton(
          onPressed: () {
            widget.controller.viewer.setToneMapping(ToneMapper.LINEAR);
          },
          child: const Text("Set tone mapping to linear"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.postProcessing =
                !ExampleWidgetState.postProcessing;
            widget.controller.viewer
                .setPostProcessing(ExampleWidgetState.postProcessing);
          },
          child: Text(
              "${ExampleWidgetState.postProcessing ? "Disable" : "Enable"} postprocessing"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.antiAliasingMsaa =
                !ExampleWidgetState.antiAliasingMsaa;
            widget.controller.viewer.setAntiAliasing(
                ExampleWidgetState.antiAliasingMsaa,
                ExampleWidgetState.antiAliasingFxaa,
                ExampleWidgetState.antiAliasingTaa);
          },
          child: Text(
              "${ExampleWidgetState.antiAliasingMsaa ? "Disable" : "Enable"} MSAA antialiasing"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.antiAliasingFxaa =
                !ExampleWidgetState.antiAliasingFxaa;
            widget.controller.viewer.setAntiAliasing(
                ExampleWidgetState.antiAliasingMsaa,
                ExampleWidgetState.antiAliasingFxaa,
                ExampleWidgetState.antiAliasingTaa);
          },
          child: Text(
              "${ExampleWidgetState.antiAliasingFxaa ? "Disable" : "Enable"} FXAA antialiasing"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.recording = !ExampleWidgetState.recording;
            widget.controller.viewer.setRecording(ExampleWidgetState.recording);
          },
          child: Text(
              "Turn recording ${ExampleWidgetState.recording ? "OFF" : "ON"}) "),
        ),
        MenuItemButton(
          onPressed: () async {
            await widget.controller.viewer
                .addLight(2, 6000, 100000, 0, 0, 0, 0, 1, 0, false);
          },
          child: Text("Add light"),
        ),
      ],
      child: const Text("Rendering"),
    );
  }
}
