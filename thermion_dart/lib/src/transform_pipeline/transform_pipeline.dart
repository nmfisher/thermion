/// Thermion Input Handler Component
///
/// A Dart wrapper library for the Thermion Input Handler native bindings.
/// This library provides high-level Dart classes for managing input handler
/// components in Thermion entities.
///
/// ## Usage
///
/// ```dart
/// import 'package:thermion_input_pipeline/thermion_input_pipeline.dart';
/// import 'package:thermion_dart/thermion_dart.dart';
///
/// // Initialize the input handler system
/// InputPipeline.instance.initialize(engine);
///
/// // Create movement processor for handling input
/// final processor = InputPipeline.instance.createMovementProcessor();
///
/// // Configure movement settings (global configuration)
/// InputPipeline.instance.setMovementSpace(entityId, MovementSpace.world);
/// InputPipeline.instance.setMovementSpeed(entityId, 5.0);
/// InputPipeline.instance.setMouseSensitivity(entityId, 0.002);
///
/// // Handle input events (global events broadcast to all entities)
/// InputPipeline.instance.onInputEvent(mouseEvent);
/// InputPipeline.instance.onInputEvent(keyEvent);
///
/// // Update pipeline manually (fallback when automatic updates don't work)
/// InputPipeline.instance.updatePipeline(deltaTime);
///
/// // Cleanup when done
/// InputPipeline.instance.dispose();
/// ```
library;

export 'src/transform_pipeline.dart';
