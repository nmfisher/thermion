import 'package:test/test.dart';
import 'package:thermion_dart/src/transform_pipeline/src/input_configuration.dart';
import 'package:thermion_dart/src/transform_pipeline/src/intent_action.dart';
import 'package:thermion_dart/src/transform_pipeline/transform_pipeline.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/bindings.dart';

void main() {
  group('InputConfiguration', () {
    test('should create empty configuration', () {
      final config = InputConfiguration();

      expect(config.keyBindings, isEmpty);
      expect(config.mouseSensitivity, equals(1.0));
      expect(config.invertMouseY, equals(false));
    });

    test('should create configuration with custom settings', () {
      final config = InputConfiguration(
        mouseSensitivity: 2.5,
        invertMouseY: true,
      );

      expect(config.mouseSensitivity, equals(2.5));
      expect(config.invertMouseY, equals(true));
    });

    test('should add key bindings', () {
      final config = InputConfiguration();
      config.addBinding(LogicalKey.w, IntentAction.moveForward);
      config.addBinding(LogicalKey.s, IntentAction.moveBackward);

      expect(config.keyBindings.length, equals(2));
      expect(config.keyBindings[0].key, equals(LogicalKey.w));
      expect(config.keyBindings[0].action, equals(IntentAction.moveForward));
      expect(config.keyBindings[1].key, equals(LogicalKey.s));
      expect(config.keyBindings[1].action, equals(IntentAction.moveBackward));
    });

    test('should add key binding with custom value', () {
      final config = InputConfiguration();
      config.addBinding(LogicalKey.shiftLeft, IntentAction.sprint, value: 2.0);

      expect(config.keyBindings.length, equals(1));
      expect(config.keyBindings[0].value, equals(2.0));
    });

    test('should remove bindings for specific key', () {
      final config = InputConfiguration();
      config.addBinding(LogicalKey.w, IntentAction.moveForward);
      config.addBinding(
          LogicalKey.w, IntentAction.sprint); // Multiple bindings on same key
      config.addBinding(LogicalKey.s, IntentAction.moveBackward);

      expect(config.keyBindings.length, equals(3));

      config.removeBindingsForKey(LogicalKey.w);

      expect(config.keyBindings.length, equals(1));
      expect(config.keyBindings[0].key, equals(LogicalKey.s));
    });

    test('should remove bindings for specific action', () {
      final config = InputConfiguration();
      config.addBinding(LogicalKey.w, IntentAction.moveForward);
      config.addBinding(LogicalKey.numpad8,
          IntentAction.moveForward); // Multiple keys for same action
      config.addBinding(LogicalKey.s, IntentAction.moveBackward);

      expect(config.keyBindings.length, equals(3));

      config.removeBindingsForAction(IntentAction.moveForward);

      expect(config.keyBindings.length, equals(1));
      expect(config.keyBindings[0].action, equals(IntentAction.moveBackward));
    });

    test('should clear all bindings', () {
      final config = InputConfiguration();
      config.addBinding(LogicalKey.w, IntentAction.moveForward);
      config.addBinding(LogicalKey.s, IntentAction.moveBackward);
      config.addBinding(LogicalKey.a, IntentAction.moveLeft);
      config.addBinding(LogicalKey.d, IntentAction.moveRight);

      expect(config.keyBindings.length, equals(4));

      config.clearBindings();

      expect(config.keyBindings, isEmpty);
    });

    test('should get bindings for specific key', () {
      final config = InputConfiguration();
      config.addBinding(LogicalKey.w, IntentAction.moveForward);
      config.addBinding(LogicalKey.w, IntentAction.sprint, value: 0.5);
      config.addBinding(LogicalKey.s, IntentAction.moveBackward);

      final wBindings = config.getBindingsForKey(LogicalKey.w);

      expect(wBindings.length, equals(2));
      expect(wBindings[0].action, equals(IntentAction.moveForward));
      expect(wBindings[1].action, equals(IntentAction.sprint));
    });

    test('should get bindings for specific action', () {
      final config = InputConfiguration();
      config.addBinding(LogicalKey.w, IntentAction.moveForward);
      config.addBinding(LogicalKey.numpad8, IntentAction.moveForward);
      config.addBinding(LogicalKey.s, IntentAction.moveBackward);

      final forwardBindings =
          config.getBindingsForAction(IntentAction.moveForward);

      expect(forwardBindings.length, equals(2));
      expect(forwardBindings[0].key, equals(LogicalKey.w));
      expect(forwardBindings[1].key, equals(LogicalKey.numpad8));
    });
  });

  group('Default Configurations', () {
    test('should create default WASD configuration', () {
      final config = createDefaultConfiguration();

      expect(config.keyBindings.length, equals(6));
      expect(config.mouseSensitivity, equals(1.0));
      expect(config.invertMouseY, equals(false));

      // Check WASD bindings
      final wBinding =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.w);
      expect(wBinding.action, equals(IntentAction.moveForward));

      final sBinding =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.s);
      expect(sBinding.action, equals(IntentAction.moveBackward));

      final aBinding =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.a);
      expect(aBinding.action, equals(IntentAction.moveLeft));

      final dBinding =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.d);
      expect(dBinding.action, equals(IntentAction.moveRight));

      final spaceBinding =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.space);
      expect(spaceBinding.action, equals(IntentAction.jump));

      final shiftBinding =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.shiftLeft);
      expect(shiftBinding.action, equals(IntentAction.sprint));
    });

    test('should create numpad configuration', () {
      final config = createNumpadConfiguration();

      expect(config.keyBindings.length, equals(6));

      // Check numpad bindings
      final numpad8 =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.numpad8);
      expect(numpad8.action, equals(IntentAction.moveForward));

      final numpad2 =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.numpad2);
      expect(numpad2.action, equals(IntentAction.moveBackward));

      final numpad4 =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.numpad4);
      expect(numpad4.action, equals(IntentAction.moveLeft));

      final numpad6 =
          config.keyBindings.firstWhere((b) => b.key == LogicalKey.numpad6);
      expect(numpad6.action, equals(IntentAction.moveRight));
    });
  });

  group('MovementIntent', () {
    test('should set and get custom intents', () {
      final intent = MovementIntent();

      intent.setCustomIntent(IntentAction.interact, 1.0);
      intent.setCustomIntent(IntentAction.crouch, 0.5);

      expect(intent.hasCustomIntent(IntentAction.interact), equals(true));
      expect(intent.hasCustomIntent(IntentAction.crouch), equals(true));
      expect(intent.hasCustomIntent(IntentAction.reload), equals(false));

      expect(intent.getCustomIntentValue(IntentAction.interact), equals(1.0));
      expect(intent.getCustomIntentValue(IntentAction.crouch), equals(0.5));
      expect(intent.getCustomIntentValue(IntentAction.reload), equals(0.0));
    });

    test('should remove custom intent when set to zero', () {
      final intent = MovementIntent();

      intent.setCustomIntent(IntentAction.interact, 1.0);
      expect(intent.hasCustomIntent(IntentAction.interact), equals(true));

      intent.setCustomIntent(IntentAction.interact, 0.0);
      expect(intent.hasCustomIntent(IntentAction.interact), equals(false));
    });

    test('should convert to and from native', () {
      final original = MovementIntent(
        movementDirection: Vector3(1, 0, -1),
        movementSpeed: 3.5,
        mouseDelta: Vector2(0.2, -0.1),
        jumpIntent: true,
        sprintIntent: true,
        hasMovementIntent: true,
        hasRotationIntent: true,
      );

      original.setCustomIntent(IntentAction.interact, 1.0);
      original.setCustomIntent(IntentAction.crouch, 0.75);

      const epsilon = 0.0001; // Tolerance for float precision

      // Convert to native
      final nativePtr = original.toNative();
      final native = nativePtr;

      // Check native struct fields (using closeTo for float precision)
      expect(native.movementDirectionX, closeTo(1.0, epsilon));
      expect(native.movementDirectionY, closeTo(0.0, epsilon));
      expect(native.movementDirectionZ, closeTo(-1.0, epsilon));
      expect(native.movementSpeed, closeTo(3.5, epsilon));
      expect(native.mouseDeltaX, closeTo(0.2, epsilon));
      expect(native.mouseDeltaY, closeTo(-0.1, epsilon));

      // Check intent states bitmask
      expect(native.intentStates & JUMP_INTENT_MASK, isNonZero);
      expect(native.intentStates & SPRINT_INTENT_MASK, isNonZero);
      expect(native.intentStates & MOVEMENT_INTENT_MASK, isNonZero);
      expect(native.intentStates & ROTATION_INTENT_MASK, isNonZero);
      expect(native.customIntentCount, equals(2));

      // Convert back from native
      final restored = MovementIntent.fromNative(native);

      // Use closeTo for floating-point values to account for float32 precision loss
      expect(restored.movementDirection.x, closeTo(1.0, epsilon));
      expect(restored.movementDirection.y, closeTo(0.0, epsilon));
      expect(restored.movementDirection.z, closeTo(-1.0, epsilon));
      expect(restored.movementSpeed, closeTo(3.5, epsilon));
      expect(restored.mouseDelta.x, closeTo(0.2, epsilon));
      expect(restored.mouseDelta.y, closeTo(-0.1, epsilon));
      expect(restored.jumpIntent, equals(true));
      expect(restored.sprintIntent, equals(true));
      expect(restored.hasMovementIntent, equals(true));
      expect(restored.hasRotationIntent, equals(true));
      expect(restored.customIntents.length, equals(2));
      expect(restored.hasCustomIntent(IntentAction.interact), equals(true));
      expect(restored.hasCustomIntent(IntentAction.crouch), equals(true));
    });
  });

  group('MovementIntent Processing Tests', () {
    test('should create movement intent with basic properties', () {
      final intent = MovementIntent(
        movementDirection: Vector3(1, 0, 0),
        movementSpeed: 1.0,
        mouseDelta: Vector2(0.1, 0.2),
        jumpIntent: true,
        sprintIntent: false,
        hasMovementIntent: true,
        hasRotationIntent: true,
      );

      expect(intent.movementDirection.x, equals(1.0));
      expect(intent.movementDirection.y, equals(0.0));
      expect(intent.movementDirection.z, equals(0.0));
      expect(intent.movementSpeed, equals(1.0));
      expect(intent.mouseDelta.x, equals(0.1));
      expect(intent.mouseDelta.y, equals(0.2));
      expect(intent.jumpIntent, equals(true));
      expect(intent.sprintIntent, equals(false));
      expect(intent.hasMovementIntent, equals(true));
      expect(intent.hasRotationIntent, equals(true));
    });

    test('should handle movement intent with zero values', () {
      final intent = MovementIntent();

      expect(intent.movementDirection, equals(Vector3.zero()));
      expect(intent.mouseDelta, equals(Vector2.zero()));
      expect(intent.customIntents, isEmpty);
      expect(intent.movementSpeed, equals(0.0));
      expect(intent.jumpIntent, equals(false));
      expect(intent.sprintIntent, equals(false));
      expect(intent.hasMovementIntent, equals(false));
      expect(intent.hasRotationIntent, equals(false));
    });

    test('should handle multiple custom intents correctly', () {
      final intent = MovementIntent();

      // Test setting multiple custom intents
      intent.setCustomIntent(IntentAction.interact, 1.0);
      intent.setCustomIntent(IntentAction.crouch, 0.75);
      intent.setCustomIntent(IntentAction.reload, 0.5);
      intent.setCustomIntent(IntentAction.altFire, 0.25);

      expect(intent.hasCustomIntent(IntentAction.interact), equals(true));
      expect(intent.hasCustomIntent(IntentAction.crouch), equals(true));
      expect(intent.hasCustomIntent(IntentAction.reload), equals(true));
      expect(intent.hasCustomIntent(IntentAction.altFire), equals(true));
      expect(intent.hasCustomIntent(IntentAction.useItem), equals(false));

      expect(intent.getCustomIntentValue(IntentAction.interact), equals(1.0));
      expect(intent.getCustomIntentValue(IntentAction.crouch), equals(0.75));
      expect(intent.getCustomIntentValue(IntentAction.reload), equals(0.5));
      expect(intent.getCustomIntentValue(IntentAction.altFire), equals(0.25));
      expect(intent.getCustomIntentValue(IntentAction.useItem), equals(0.0));

      // Test updating existing custom intent
      intent.setCustomIntent(IntentAction.interact, 0.8);
      expect(intent.getCustomIntentValue(IntentAction.interact), equals(0.8));
      expect(intent.hasCustomIntent(IntentAction.interact), equals(true));

      // Test removing multiple custom intents
      intent.setCustomIntent(IntentAction.crouch, 0.0);
      intent.setCustomIntent(IntentAction.altFire, 0.0);
      expect(intent.hasCustomIntent(IntentAction.crouch), equals(false));
      expect(intent.hasCustomIntent(IntentAction.altFire), equals(false));
      expect(
          intent.customIntents.length, equals(2)); // interact and reload remain
    });

    test('should handle custom intent limits correctly', () {
      final intent = MovementIntent();

      // Test setting more custom intents than the maximum allowed
      final allActions = [
        IntentAction.interact,
        IntentAction.crouch,
        IntentAction.reload,
        IntentAction.altFire,
        IntentAction.useItem,
        IntentAction.custom1,
        IntentAction.custom2,
        IntentAction.custom3,
        IntentAction.custom4,
        IntentAction.custom5,
        IntentAction.custom6,
        IntentAction.custom7,
        IntentAction.custom8,
        IntentAction.custom9,
        IntentAction.custom10,
        IntentAction.moveForward, // Test with movement actions too
        IntentAction.moveBackward,
      ];

      for (int i = 0; i < allActions.length; i++) {
        intent.setCustomIntent(allActions[i], (i + 1).toDouble());
      }

      // Convert to native and back to test the MAX_CUSTOM_INTENTS limit
      final native = intent.toNative();
      expect(native.customIntentCount,
          lessThanOrEqualTo(16)); // MAX_CUSTOM_INTENTS

      final restored = MovementIntent.fromNative(native);

      // The restored intent should only contain the first MAX_CUSTOM_INTENTS custom intents
      expect(restored.customIntents.length, lessThanOrEqualTo(16));
    });

    test('should handle complex movement scenarios', () {
      // Test scenario: moving forward while jumping and looking around
      final forwardIntent = MovementIntent(
        movementDirection: Vector3(0, 0, -1), // Forward
        movementSpeed: 1.0,
        mouseDelta: Vector2(0.1, -0.05), // Looking right and slightly up
        jumpIntent: true,
        sprintIntent: false,
        hasMovementIntent: true,
        hasRotationIntent: true,
      );

      forwardIntent.setCustomIntent(IntentAction.interact, 1.0);

      // Test scenario: strafing left while crouching
      final strafeIntent = MovementIntent(
        movementDirection: Vector3(-1, 0, 0), // Left
        movementSpeed: 0.5, // Slower when crouching
        jumpIntent: false,
        sprintIntent: false,
        hasMovementIntent: true,
        hasRotationIntent: false,
      );

      strafeIntent.setCustomIntent(IntentAction.crouch, 1.0);

      // Test scenario: sprinting forward
      final sprintIntent = MovementIntent(
        movementDirection: Vector3(0, 0, -1), // Forward
        movementSpeed: 2.0, // Faster when sprinting
        jumpIntent: false,
        sprintIntent: true,
        hasMovementIntent: true,
        hasRotationIntent: false,
      );

      // Verify each scenario
      expect(forwardIntent.movementDirection.z, equals(-1.0));
      expect(forwardIntent.jumpIntent, equals(true));
      expect(
          forwardIntent.hasCustomIntent(IntentAction.interact), equals(true));

      expect(strafeIntent.movementDirection.x, equals(-1.0));
      expect(strafeIntent.movementSpeed, equals(0.5));
      expect(strafeIntent.hasCustomIntent(IntentAction.crouch), equals(true));

      expect(sprintIntent.sprintIntent, equals(true));
      expect(sprintIntent.movementSpeed, equals(2.0));
    });

    test('should handle floating point precision in native conversion', () {
      final original = MovementIntent(
        movementDirection: Vector3(0.123456789, 0.987654321, -0.555555555),
        movementSpeed: 1.414213562, // sqrt(2)
        mouseDelta: Vector2(3.141592653, -2.718281828), // pi and -e
        jumpIntent: true,
        sprintIntent: false,
        hasMovementIntent: true,
        hasRotationIntent: true,
      );

      const epsilon = 0.00001; // Tight tolerance for float precision

      // Convert to native and back
      final native = original.toNative();
      final restored = MovementIntent.fromNative(native);

      // Test that precision is maintained within reasonable bounds
      expect(restored.movementDirection.x, closeTo(0.123456789, epsilon));
      expect(restored.movementDirection.y, closeTo(0.987654321, epsilon));
      expect(restored.movementDirection.z, closeTo(-0.555555555, epsilon));
      expect(restored.movementSpeed, closeTo(1.414213562, epsilon));
      expect(restored.mouseDelta.x, closeTo(3.141592653, epsilon));
      expect(restored.mouseDelta.y, closeTo(-2.718281828, epsilon));
      expect(restored.jumpIntent, equals(original.jumpIntent));
      expect(restored.sprintIntent, equals(original.sprintIntent));
    });

    test('should handle bitmask operations correctly', () {
      // Test all possible intent state combinations
      final testCases = [
        {
          'name': 'Only jump',
          'jumpIntent': true,
          'sprintIntent': false,
          'hasMovementIntent': false,
          'hasRotationIntent': false,
          'expectedMask': JUMP_INTENT_MASK,
        },
        {
          'name': 'Only sprint',
          'jumpIntent': false,
          'sprintIntent': true,
          'hasMovementIntent': false,
          'hasRotationIntent': false,
          'expectedMask': SPRINT_INTENT_MASK,
        },
        {
          'name': 'Jump and sprint',
          'jumpIntent': true,
          'sprintIntent': true,
          'hasMovementIntent': false,
          'hasRotationIntent': false,
          'expectedMask': JUMP_INTENT_MASK | SPRINT_INTENT_MASK,
        },
        {
          'name': 'Movement and rotation',
          'jumpIntent': false,
          'sprintIntent': false,
          'hasMovementIntent': true,
          'hasRotationIntent': true,
          'expectedMask': MOVEMENT_INTENT_MASK | ROTATION_INTENT_MASK,
        },
        {
          'name': 'All intents active',
          'jumpIntent': true,
          'sprintIntent': true,
          'hasMovementIntent': true,
          'hasRotationIntent': true,
          'expectedMask': JUMP_INTENT_MASK |
              SPRINT_INTENT_MASK |
              MOVEMENT_INTENT_MASK |
              ROTATION_INTENT_MASK,
        },
        {
          'name': 'No intents active',
          'jumpIntent': false,
          'sprintIntent': false,
          'hasMovementIntent': false,
          'hasRotationIntent': false,
          'expectedMask': 0,
        },
      ];

      for (final testCase in testCases) {
        final intent = MovementIntent(
          jumpIntent: testCase['jumpIntent'] as bool,
          sprintIntent: testCase['sprintIntent'] as bool,
          hasMovementIntent: testCase['hasMovementIntent'] as bool,
          hasRotationIntent: testCase['hasRotationIntent'] as bool,
        );

        final native = intent.toNative();
        expect(native.intentStates, equals(testCase['expectedMask'] as int),
            reason: 'Failed for case: ${testCase['name']}');

        // Test round-trip
        final restored = MovementIntent.fromNative(native);
        expect(restored.jumpIntent, equals(testCase['jumpIntent']),
            reason: 'Jump intent mismatch for case: ${testCase['name']}');
        expect(restored.sprintIntent, equals(testCase['sprintIntent']),
            reason: 'Sprint intent mismatch for case: ${testCase['name']}');
        expect(
            restored.hasMovementIntent, equals(testCase['hasMovementIntent']),
            reason: 'Movement intent mismatch for case: ${testCase['name']}');
        expect(
            restored.hasRotationIntent, equals(testCase['hasRotationIntent']),
            reason: 'Rotation intent mismatch for case: ${testCase['name']}');
      }
    });

    test('should handle toString representation', () {
      final intent = MovementIntent(
        movementDirection: Vector3(1, 2, 3),
        movementSpeed: 1.5,
        mouseDelta: Vector2(0.5, -0.3),
        jumpIntent: true,
        sprintIntent: false,
        hasMovementIntent: true,
        hasRotationIntent: true,
      );

      intent.setCustomIntent(IntentAction.interact, 1.0);
      intent.setCustomIntent(IntentAction.crouch, 0.75);

      final stringRepresentation = intent.toString();

      expect(stringRepresentation, contains('MovementIntent'));
      expect(stringRepresentation, contains('dir: Vector3(1.0, 2.0, 3.0)'));
      expect(stringRepresentation, contains('speed: 1.5'));
      expect(stringRepresentation, contains('mouse: Vector2(0.5, -0.3)'));
      expect(stringRepresentation, contains('jump: true'));
      expect(stringRepresentation, contains('sprint: false'));
      expect(stringRepresentation, contains('customIntents: 2'));
    });
  });
}
