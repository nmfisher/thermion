import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament_example/main.dart';

class RenderingSubmenu extends StatefulWidget {
  final FilamentController controller;

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
            widget.controller.render();
          },
          child: const Text("Render single frame"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.rendering = !ExampleWidgetState.rendering;
            widget.controller.setRendering(ExampleWidgetState.rendering);
          },
          child: Text(
              "Set continuous rendering to ${!ExampleWidgetState.rendering}"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.framerate =
                ExampleWidgetState.framerate == 60 ? 30 : 60;
            widget.controller.setFrameRate(ExampleWidgetState.framerate);
          },
          child: Text(
              "Toggle framerate (currently ${ExampleWidgetState.framerate}) "),
        ),
        MenuItemButton(
          onPressed: () {
            widget.controller.setToneMapping(ToneMapper.LINEAR);
          },
          child: const Text("Set tone mapping to linear"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.postProcessing =
                !ExampleWidgetState.postProcessing;
            widget.controller
                .setPostProcessing(ExampleWidgetState.postProcessing);
          },
          child: Text(
              "${ExampleWidgetState.postProcessing ? "Disable" : "Enable"} postprocessing"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.antiAliasingMsaa =
                !ExampleWidgetState.antiAliasingMsaa;
            widget.controller.setAntiAliasing(
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
            widget.controller.setAntiAliasing(
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
            widget.controller.setRecording(ExampleWidgetState.recording);
          },
          child: Text(
              "Turn recording ${ExampleWidgetState.recording ? "OFF" : "ON"}) "),
        ),
        MenuItemButton(
          onPressed: () async {
            await widget.controller
                .addLight(2, 6000, 100000, 0, 0, 0, 0, 1, 0, false);
          },
          child: Text("Add light"),
        ),
      ],
      child: const Text("Rendering"),
    );
  }
}
