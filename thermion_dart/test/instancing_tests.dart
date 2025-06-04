@Timeout(const Duration(seconds: 600))
import 'dart:math';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/interface/asset.dart';
import 'package:thermion_dart/src/filament/src/interface/filament_app.dart';
import 'package:thermion_dart/src/utils/src/geometry.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

// Helper class to store physics state for each instance
class PhysicsState {
  final ThermionAsset instance;
  Vector3 position = Vector3.zero();
  final double scale;
  Vector3 velocity = Vector3.zero();
  bool launched = false;
  bool addedToScene = false; // Track if added to prevent multiple adds

  PhysicsState(this.instance, this.scale);
}

void main() async {
  final testHelper = TestHelper("instancing");
  await testHelper.setup();

  test('create/destroy instance for geometry asset', () async {
    await testHelper.withViewer((viewer) async {
      final mi = await FilamentApp.instance!.createUbershaderMaterialInstance();
      var asset = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [mi], addToScene: true, keepData: true);

      await testHelper.capture(viewer.view, "geometry_no_instance");
      expect(await asset.getInstanceCount(), 0);

      var instance = await asset.createInstance();

      expect(await asset.getInstanceCount(), 1);

      await viewer.addToScene(instance);
      await instance.setTransform(Matrix4.translation(Vector3(1, 0, 0)));
      await testHelper.capture(viewer.view, "geometry_with_instance");

      await viewer.destroyAsset(instance);
      await testHelper.capture(viewer.view, "geometry_instance_destroyed");

      await viewer.destroyAssets();
      await testHelper.capture(viewer.view, "geometry_asset_destroyed");
    }, bg: kRed);
  });

  test('gltf assets always create one instance', () async {
    await testHelper.withViewer((viewer) async {
      var asset =
          await viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");
      expect(await asset.getInstanceCount(), 1);
    });
  });

  test('create gltf instance', () async {
    await testHelper.withViewer((viewer) async {
      await viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await viewer.loadSkybox(
          "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
      await viewer.setPostProcessing(true);
      await viewer.setAntiAliasing(false, true, false);

      // Loading a glTF asset always creates a single instance behind the scenes,
      // but the entities exposed by the asset are used to manipulate all
      // instances as a group, not the singular "default" instance.
      // If you are only creating a single instance (the default behaviour),
      // then you don't need to worry about the difference.
      //
      // When creating multiple instances, however,you usually want to work
      // with each instance individually, rather than the owning asset.
      var asset = await viewer.loadGltf(
          "file://${testHelper.testDir}/assets/cube.glb",
          addToScene: false,
          numInstances: 2);
      var defaultInstance = await asset.getInstance(0);
      await viewer.addToScene(defaultInstance);
      await testHelper.capture(viewer.view, "gltf_without_instance");

      var instance = await asset.createInstance();
      await instance.setTransform(Matrix4.translation(Vector3(1, 0, 0)));
      await testHelper.capture(viewer.view, "gltf_instance_created");
      await viewer.addToScene(instance);
      await testHelper.capture(viewer.view, "gltf_instance_add_to_scene");
      await viewer.removeFromScene(instance);
      await testHelper.capture(viewer.view, "gltf_instance_remove_from_scene");
    });
  });

  test('physics simulation with 100 instances', () async {
    await testHelper.withViewer((viewer) async {
      // --- Scene Setup ---
      await viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await viewer.loadSkybox(
          "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
      await viewer.setPostProcessing(true);
      await viewer.setAntiAliasing(false, true, false); // Enable FXAA
      final camera = await viewer.getActiveCamera();
      final orbitDist = 12.0; // Slightly further back to see spread pattern
      final lookAtTarget = Vector3(0, 0.5, 0); // Look at middle of trajectory

      // --- Load Asset & Create/Prepare Instances ---
      print("Loading asset...");
      var numInstances = 100;
      var asset = await viewer.loadGltf(
          "file://${testHelper.testDir}/assets/cube.glb",
          numInstances: numInstances,
          addToScene: false);

      print("Creating 100 instances...");
      List<PhysicsState> instanceStates = [];
      final rnd = Random();
      for (int i = 0; i < numInstances - 1; i++) {
        var mi = await FilamentApp.instance!
            .createUbershaderMaterialInstance(unlit: true);
        var instance = await asset.createInstance(materialInstances: [mi]);
        await viewer.removeFromScene(instance);
        await mi.setParameterFloat4("baseColorFactor", rnd.nextDouble(),
            rnd.nextDouble(), rnd.nextDouble(), 1.0);
        var scale = max(0.25, rnd.nextDouble());

        instanceStates.add(PhysicsState(instance, scale));
      }
      print("Instances created and colored.");

      // --- Simulation Parameters ---
      final gravity = Vector3(0, -9.81, 0);

      // Calculate initial velocity to reach 1 meter in 1 second
      // Using kinematics: y = v0*t + 0.5*a*t^2
      // At t=1s, y=1m, a=-9.81m/s^2
      // Solving for v0: v0 = 1 - 0.5*(-9.81)*1^2 = 1 + 4.905 = 5.905 m/s
      final initialUpwardSpeed = 5.905; // Calculated for 1m height in 1s

      final timeStep = 1 / 60.0; // Simulate at 60 FPS
      final frameDuration =
          Duration(microseconds: (timeStep * 1000000).round());
      final launchInterval = 0.5; // 100 ms between launches
      final totalSimulationTime = 20.0; // Simulation duration in seconds
      final orbitDuration = 10.0; // Time for one full camera orbit

      // --- Simulation Loop ---
      double currentTime = 0.0;
      double timeSinceLastLaunch =
          launchInterval; // Start launching immediately
      int launchedCount = 0;
      int frameCounter = 0;
      int captureCounter = 0;

      print("Starting simulation loop (${totalSimulationTime}s)...");
      final startTime = DateTime.now();

      while (currentTime < totalSimulationTime) {
        final loopStart = DateTime.now();

        // 1. Launch Instance Logic
        if (launchedCount < instanceStates.length &&
            timeSinceLastLaunch >= launchInterval) {
          final state = instanceStates[launchedCount];
          if (!state.launched) {
            print("Launching instance ${launchedCount + 1}/100");
            // Add a slight angle to launch direction
            // Using a spiral pattern with increasing angle
            final angle = (launchedCount * 0.2) %
                (2 * pi); // Increasing angle creating spiral
            final horizontalComponent =
                initialUpwardSpeed * 0.15; // 15% horizontal velocity
            state.velocity = Vector3(
                horizontalComponent * cos(angle),
                initialUpwardSpeed,
                horizontalComponent * sin(angle)); // Angled velocity
            state.position = Vector3(0, 0.1, 0); // Start slightly above origin
            state.launched = true;
            await viewer
                .addToScene(state.instance); // Add to scene ONLY when launched
            state.addedToScene = true;
            launchedCount++;
            timeSinceLastLaunch -= launchInterval;
          }
        }

        // 2. Update Physics and Transforms for launched instances
        List<Future> transformUpdates = [];
        for (var state in instanceStates) {
          if (state.launched) {
            // Basic Euler integration
            state.velocity.add(gravity * timeStep);
            state.position.add(state.velocity * timeStep);

            // Queue the asynchronous transform update
            transformUpdates.add(state.instance.setTransform(Matrix4.compose(
                state.position,
                Quaternion.identity(),
                Vector3.all(state.scale))));
          }
        }
        // Wait for all instance transforms in this step to complete
        if (transformUpdates.isNotEmpty) {
          await Future.wait(transformUpdates);
        }

        // 3. Update Camera Orbit
        final angle = (currentTime / orbitDuration) * 2 * pi;
        await camera.lookAt(
          Vector3(
            sin(angle) * orbitDist,
            orbitDist * 0.3, // Lower camera height to see 1-meter trajectories
            cos(angle) * orbitDist,
          ),
          focus: lookAtTarget, // Point towards the peak of trajectories
          up: Vector3(0, 1, 0), // Keep up vector standard
        );

        // 4. Capture Frame Periodically (e.g., every 6 physics steps => 10 captures/sec)
        if (frameCounter % 6 == 0) {
          await testHelper.capture(viewer.view,
              "capture_physics_orbit_${captureCounter.toString().padLeft(3, '0')}");
          captureCounter++;
        }

        // 5. Advance Time and Wait
        currentTime += timeStep;
        timeSinceLastLaunch += timeStep;
        frameCounter++;

        // Ensure the loop doesn't run faster than the desired frame rate
        final elapsed = loopStart.difference(loopStart);
        if (elapsed < frameDuration) {
          await Future.delayed(frameDuration - elapsed);
        }
      }

      final endTime = DateTime.now();
      print(
          "Simulation loop finished in ${endTime.difference(startTime).inSeconds} seconds.");
      print("Captured $captureCounter frames.");

      // Optional: Capture one final frame after simulation ends
      await testHelper.capture(viewer.view, "capture_physics_orbit_final");
    }, viewportDimensions: (width: 1024, height: 1024)); // End withViewer
  });
}
