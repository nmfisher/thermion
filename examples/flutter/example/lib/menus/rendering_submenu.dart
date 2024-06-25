import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_example/main.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

class RenderingSubmenu extends StatefulWidget {
  final ThermionViewer viewer;

  const RenderingSubmenu({super.key, required this.viewer});

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
            widget.viewer.render();
          },
          child: const Text("Render single frame"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.rendering = !ExampleWidgetState.rendering;
            widget.viewer.setRendering(ExampleWidgetState.rendering);
          },
          child: Text(
              "Set continuous rendering to ${!ExampleWidgetState.rendering}"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.framerate =
                ExampleWidgetState.framerate == 60 ? 30 : 60;
            widget.viewer.setFrameRate(ExampleWidgetState.framerate);
          },
          child: Text(
              "Toggle framerate (currently ${ExampleWidgetState.framerate}) "),
        ),
        MenuItemButton(
          onPressed: () {
            widget.viewer.setToneMapping(ToneMapper.LINEAR);
          },
          child: const Text("Set tone mapping to linear"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.postProcessing =
                !ExampleWidgetState.postProcessing;
            widget.viewer
                .setPostProcessing(ExampleWidgetState.postProcessing);
          },
          child: Text(
              "${ExampleWidgetState.postProcessing ? "Disable" : "Enable"} postprocessing"),
        ),
        MenuItemButton(
          onPressed: () {
            ExampleWidgetState.antiAliasingMsaa =
                !ExampleWidgetState.antiAliasingMsaa;
            widget.viewer.setAntiAliasing(
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
            widget.viewer.setAntiAliasing(
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
            widget.viewer.setRecording(ExampleWidgetState.recording);
          },
          child: Text(
              "Turn recording ${ExampleWidgetState.recording ? "OFF" : "ON"}) "),
        ),
      ],
      child: const Text("Rendering"),
    );
  }
}
