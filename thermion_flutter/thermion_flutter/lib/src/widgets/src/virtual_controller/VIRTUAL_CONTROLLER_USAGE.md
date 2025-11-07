# VirtualControllerWidget Usage

The `VirtualControllerWidget` is a standalone widget that provides a mobile game controller overlay with D-pad and analog stick controls.

## Basic Usage

```dart
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_dart/thermion_dart.dart';

class MyGameWidget extends StatelessWidget {
  final ThermionViewer viewer;

  const MyGameWidget({Key? key, required this.viewer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create a virtual controller input handler
    final virtualControllerHandler = VirtualControllerInputHandler(
      inputHandler: DelegateInputHandler.flight(viewer),
    );

    return VirtualControllerWidget(
      inputHandler: virtualControllerHandler,
      enabled: true,
      child: ThermionListenerWidget(
        inputHandler: virtualControllerHandler.inputHandler,
        child: ThermionWidget(viewer: viewer),
      ),
    );
  }
}
```

## Features

- **D-pad (left side)**: Generates W/A/S/D key events for movement
- **Analog stick (right side)**: Generates mouse movement events for camera control
- **Platform detection**: Only shows on mobile devices (iOS/Android)
- **Configurable styling**: Custom colors, opacity, and sizing
- **Landscape optimized**: Perfect for landscape gaming orientation

## Customization

```dart
VirtualControllerWidget(
  inputHandler: virtualControllerHandler,
  controllerSize: 150.0,
  backgroundColor: Colors.black38,
  foregroundColor: Colors.white,
  stickColor: Colors.blue,
  opacity: 0.8,
  padding: EdgeInsets.all(24.0),
  child: YourGameContent(),
)
```

## Integration with Existing Input Delegates

The virtual controller works seamlessly with all existing input delegates:

- `DelegateInputHandler.flight()` - First-person/flight controls
- `DelegateInputHandler.fixedOrbit()` - Third-person orbit controls
- Custom `InputHandlerDelegate` implementations