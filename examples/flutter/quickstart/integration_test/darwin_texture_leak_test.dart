// Regression test for the iOS/macOS IOSurface leak described in
// https://github.com/nmfisher/thermion/issues/178.
//
// Every time a ThermionWidget is mounted and unmounted, the darwin plugin
// allocates a full-screen BGRA IOSurface (CVPixelBuffer + CVMetalTexture +
// the +1-retained MTLTexture handed to Filament as the hardware id). On
// teardown, `MetalTextureWrapper.destroyTexture()` only flushed the Metal
// texture cache and never released that +1 retain (nor the CVMetalTexture),
// so each session leaked one screen-sized surface (~22 MB on an iPad Pro
// 12.9). The Dart side also never removed destroyed descriptors from
// `_descriptors` because nothing ever appended to `_destroyed`.
//
// This test mounts and unmounts a ThermionWidget several times and asserts
// that `phys_footprint` (the kernel's accounting of the bytes the process
// truly owes) does not grow by a full surface per session. A small,
// bounded drift is tolerated — Filament's own per-engine caches, the Dart
// heap, and texture caches all settle asynchronously — but a leak of one
// surface per session is far above that floor.
//
// The primary assertion uses native live-instance counters for the platform
// texture and Flutter adapter. `phys_footprint` is retained as a secondary
// signal, but it can temporarily stay high after every wrapper is gone because
// Metal and Flutter cache released allocations.
//
// Run on a real target:
//
//   flutter test integration_test/darwin_texture_leak_test.dart -d macos
//
// The slower Flutter-only, pooled-surface, and Filament-only diagnostic probes
// are opt-in:
//
//   flutter test integration_test/darwin_texture_leak_test.dart -d macos \
//     --dart-define=THERMION_DARWIN_TEXTURE_PROBES=true
//   flutter test integration_test/darwin_texture_leak_test.dart -d <ios-device>
//
// Skipped on non-darwin platforms: the leak is specific to the Metal
// texture wrapper in darwin/Classes/MetalTextureWrapper.swift.
import 'dart:io';

import 'package:flutter/material.dart' hide View;
import 'package:flutter/widgets.dart' as flutter show Texture;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter/src/swift/swift_bindings.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final bool isDarwin = Platform.isMacOS || Platform.isIOS;
  const runIsolationProbes = bool.fromEnvironment(
    'THERMION_DARWIN_TEXTURE_PROBES',
  );

  testWidgets(
    'isolates Flutter texture registration lifetime',
    (tester) async {
      const width = 768;
      const height = 576;

      Future<void> cycle() async {
        final metalTexture =
            MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(
          width,
          height,
          false,
          false,
        );
        final adapter = FlutterMetalTextureWrapper.alloc().initWithTexture_(
          metalTexture,
        );
        final textureId =
            _DarwinFlutterTextureRegistry.instance.registerTexture_(adapter);
        expect(textureId, isNot(0));

        await tester.pumpWidget(
          Center(
            child: SizedBox(
              width: width.toDouble(),
              height: height.toDouble(),
              child: flutter.Texture(textureId: textureId),
            ),
          ),
        );
        for (var frame = 0; frame < 4; frame++) {
          expect(
            _DarwinTextureLifetime.fillPixelBuffer(
              metalTexture.ref.pointer.address,
              frame.isEven ? 255 : 0,
            ),
            isTrue,
          );
          _DarwinFlutterTextureRegistry.instance.textureFrameAvailable_(
            textureId,
          );
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }

        await tester.pumpWidget(const SizedBox.shrink());
        _DarwinFlutterTextureRegistry.instance.unregisterTexture_(textureId);
        metalTexture.flushCache();
        adapter.ref.release();
        metalTexture.ref.release();
        await _probeDrain(tester);
      }

      final drift = await _measureProbe(
        tester,
        label: 'flutter-only',
        cycle: cycle,
        isDarwin: isDarwin,
      );
      debugPrint(
        '[leak-test] flutter-only total drift='
        '${(drift / 1024 / 1024).toStringAsFixed(2)} MB',
      );
    },
    skip: !isDarwin || !runIsolationProbes,
  );

  testWidgets(
    'reusing a Flutter texture surface keeps IOSurface memory bounded',
    (tester) async {
      const width = 768;
      const height = 576;
      final metalTexture =
          MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(
        width,
        height,
        false,
        false,
      );

      Future<void> cycle() async {
        final adapter = FlutterMetalTextureWrapper.alloc().initWithTexture_(
          metalTexture,
        );
        final textureId =
            _DarwinFlutterTextureRegistry.instance.registerTexture_(adapter);
        expect(textureId, isNot(0));

        await tester.pumpWidget(
          Center(
            child: SizedBox(
              width: width.toDouble(),
              height: height.toDouble(),
              child: flutter.Texture(textureId: textureId),
            ),
          ),
        );
        for (var frame = 0; frame < 4; frame++) {
          expect(
            _DarwinTextureLifetime.fillPixelBuffer(
              metalTexture.ref.pointer.address,
              frame.isEven ? 255 : 0,
            ),
            isTrue,
          );
          _DarwinFlutterTextureRegistry.instance.textureFrameAvailable_(
            textureId,
          );
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        await tester.pumpWidget(const SizedBox.shrink());
        _DarwinFlutterTextureRegistry.instance.unregisterTexture_(textureId);
        adapter.ref.release();
        await _probeDrain(tester);
        await _waitForNoLiveDarwinTextures(
          tester,
          isDarwin,
          timeout: const Duration(seconds: 10),
          expectedLiveWrappers: 1,
        );
      }

      final drift = await _measureProbe(
        tester,
        label: 'flutter-pooled',
        cycle: cycle,
        isDarwin: isDarwin,
        expectedLiveWrappers: 1,
        warmupCycles: 1,
        measuredCycles: 4,
      );
      debugPrint(
        '[leak-test] flutter-pooled total drift='
        '${(drift / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      metalTexture.flushCache();
      metalTexture.ref.release();
      await _waitForNoLiveDarwinTextures(tester, isDarwin);
      _expectNoLiveDarwinTextures(isDarwin, 'flutter-pooled cleanup');
    },
    skip: !isDarwin || !runIsolationProbes,
  );

  testWidgets(
    'isolates Filament texture import lifetime',
    (tester) async {
      const width = 768;
      const height = 576;
      final viewer = await ThermionFlutterPlugin.createViewer();
      final app = FilamentApp.instance!;

      Future<void> cycle() async {
        final metalTexture =
            MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(
          width,
          height,
          false,
          false,
        );
        final imported = await app.createTexture(
          width,
          height,
          importedTextureHandle: metalTexture.retainMetalTextureForImport(),
          flags: {
            TextureUsage.TEXTURE_USAGE_BLIT_SRC,
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
          },
          textureFormat: TextureFormat.RGBA8,
          textureSamplerType: TextureSamplerType.SAMPLER_2D,
        );
        await imported.destroy();
        await app.flush();
        metalTexture.flushCache();
        metalTexture.ref.release();
        await _probeDrain(tester);
      }

      final drift = await _measureProbe(
        tester,
        label: 'filament-only',
        cycle: cycle,
        isDarwin: isDarwin,
      );
      debugPrint(
        '[leak-test] filament-only total drift='
        '${(drift / 1024 / 1024).toStringAsFixed(2)} MB',
      );
      await viewer.dispose();
    },
    skip: !isDarwin || !runIsolationProbes,
  );

  testWidgets(
    'repeated ThermionWidget mount/unmount does not leak IOSurfaces',
    (tester) async {
      // Surface size chosen so a single leaked BGRA IOSurface is large
      // relative to cache noise: 768x576x4 ≈ 1.69 MB. A few sessions of
      // that dwarf the asynchronous cache drift a correct fix leaves
      // behind, while still running in seconds.
      const surfaceWidth = 768;
      const surfaceHeight = 576;
      const surfaceBytes = surfaceWidth * surfaceHeight * 4;

      // One long-lived viewer reused across every session — the common
      // pattern (navigate into/out of a 3D screen without rebuilding the
      // viewer). It is also the pattern the fix targets: the render target is
      // destroyed on unmount while one registered macOS producer is retained
      // for an exact-size remount.
      final viewer = await ThermionFlutterPlugin.createViewer();
      final expectedCachedWrappers = Platform.isMacOS ? 1 : 0;
      final expectedCachedAdapters = Platform.isMacOS ? 1 : 0;

      // Warm up through the Metal/Filament cache ramp. A single session is
      // insufficient on macOS: the first few render-target reconstructions
      // grow driver caches even when the registered IOSurface is unchanged.
      const warmupSessions = 4;
      for (var i = 0; i < warmupSessions; i++) {
        await _pumpOneSessionAndUnmount(
          tester,
          viewer,
          surfaceWidth,
          surfaceHeight,
        );
      }
      await _drain(tester);
      _expectNoLiveDarwinTextures(
        isDarwin,
        'warm-up',
        expectedLiveWrappers: expectedCachedWrappers,
        expectedLiveAdapters: expectedCachedAdapters,
      );
      final baselineSamples = <int>[];
      for (var i = 0; i < 3; i++) {
        baselineSamples.add(
          isDarwin ? _DarwinMemory.physFootprintBytes() : 0,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final baseline = _median(baselineSamples);
      final createdWrappersAtBaseline =
          isDarwin ? _DarwinTextureLifetime.createdMetalTextureWrappers() : 0;
      final createdAdaptersAtBaseline =
          isDarwin ? _DarwinTextureLifetime.createdFlutterTextureAdapters() : 0;
      debugPrint(
        '[leak-test] baseline phys_footprint='
        '${(baseline / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // Each iteration mounts a fresh ThermionWidget, lets it render a few
      // frames, then unmounts it. With the leak, each iteration pins one
      // screen-sized IOSurface. We sample after every session so a steady
      // per-session leak is visible even if the absolute floor drifts.
      const sessions = 5;
      var prev = baseline;
      final measuredSamples = <int>[];
      for (var i = 0; i < sessions; i++) {
        await _pumpOneSessionAndUnmount(
          tester,
          viewer,
          surfaceWidth,
          surfaceHeight,
        );
        await _drain(tester);
        _expectNoLiveDarwinTextures(
          isDarwin,
          'session ${i + 1}',
          expectedLiveWrappers: expectedCachedWrappers,
          expectedLiveAdapters: expectedCachedAdapters,
        );
        final now = isDarwin ? _DarwinMemory.physFootprintBytes() : 0;
        debugPrint(
          '[leak-test] session ${i + 1}/$sessions phys_footprint='
          '${(now / 1024 / 1024).toStringAsFixed(2)} MB '
          '(delta=${((now - prev) / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
        measuredSamples.add(now);
        prev = now;
      }
      final after = _median(measuredSamples);

      // Tear down the reused viewer now that all sessions are measured.
      await viewer.dispose();

      if (!isDarwin) {
        // Sanity: the test compiles and runs on non-darwin, but asserts
        // nothing — the leak is darwin-only.
        return;
      }

      final drift = after - baseline;
      expect(
        _DarwinTextureLifetime.createdMetalTextureWrappers(),
        createdWrappersAtBaseline,
        reason: 'mount/unmount allocated a new MetalTextureWrapper instead of '
            'reusing the registered macOS texture producer',
      );
      expect(
        _DarwinTextureLifetime.createdFlutterTextureAdapters(),
        createdAdaptersAtBaseline,
        reason: 'mount/unmount registered a new FlutterMetalTextureWrapper '
            'instead of reusing the cached adapter',
      );
      // Tolerance: one surface's worth of drift in the median settled sample.
      // A median rejects isolated driver-cache jumps while a steady
      // one-surface-per-session leak still exceeds this threshold by roughly
      // three surfaces across five measured sessions.
      const toleranceBytes = surfaceBytes;
      expect(
        drift,
        lessThan(toleranceBytes),
        reason:
            'phys_footprint grew by ${(drift / 1024 / 1024).toStringAsFixed(2)} '
            'MB across $sessions mount/unmount sessions (tolerance '
            '${(toleranceBytes / 1024 / 1024).toStringAsFixed(2)} MB); expected '
            'the macOS surface pool to reuse the warm-up IOSurface. '
            '(baseline=${(baseline / 1024 / 1024).toStringAsFixed(2)} MB, '
            'median=${(after / 1024 / 1024).toStringAsFixed(2)} MB, '
            'final=${(prev / 1024 / 1024).toStringAsFixed(2)} MB)',
      );
    },
    // Flutter's external Metal texture path is Darwin-only.
    skip: !isDarwin,
  );
}

Future<int> _measureProbe(
  WidgetTester tester, {
  required String label,
  required Future<void> Function() cycle,
  required bool isDarwin,
  int expectedLiveWrappers = 0,
  int warmupCycles = 4,
  int measuredCycles = 16,
}) async {
  for (var i = 0; i < warmupCycles; i++) {
    await cycle();
  }
  await _waitForNoLiveDarwinTextures(
    tester,
    isDarwin,
    timeout: const Duration(seconds: 20),
    expectedLiveWrappers: expectedLiveWrappers,
  );
  _expectNoLiveDarwinTextures(
    isDarwin,
    '$label warm-up',
    expectedLiveWrappers: expectedLiveWrappers,
  );
  await Future<void>.delayed(const Duration(milliseconds: 2500));

  final baseline = _DarwinMemory.physFootprintBytes();
  var current = baseline;
  debugPrint(
    '[leak-test] $label baseline='
    '${(baseline / 1024 / 1024).toStringAsFixed(2)} MB',
  );
  for (var i = 0; i < measuredCycles; i++) {
    await cycle();
    _logLiveDarwinTextures(isDarwin, '$label cycle ${i + 1}');
    final next = _DarwinMemory.physFootprintBytes();
    debugPrint(
      '[leak-test] $label cycle ${i + 1}/$measuredCycles='
      '${(next / 1024 / 1024).toStringAsFixed(2)} MB '
      '(delta=${((next - current) / 1024 / 1024).toStringAsFixed(2)} MB)',
    );
    current = next;
  }
  await _waitForNoLiveDarwinTextures(
    tester,
    isDarwin,
    timeout: const Duration(seconds: 30),
    expectedLiveWrappers: expectedLiveWrappers,
  );
  _expectNoLiveDarwinTextures(
    isDarwin,
    '$label final teardown',
    expectedLiveWrappers: expectedLiveWrappers,
  );
  await Future<void>.delayed(const Duration(milliseconds: 2500));
  final settled = _DarwinMemory.physFootprintBytes();
  debugPrint(
    '[leak-test] $label settled='
    '${(settled / 1024 / 1024).toStringAsFixed(2)} MB '
    '(post-teardown delta='
    '${((settled - current) / 1024 / 1024).toStringAsFixed(2)} MB)',
  );
  return settled - baseline;
}

Future<void> _probeDrain(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

Future<void> _waitForNoLiveDarwinTextures(
  WidgetTester tester,
  bool isDarwin, {
  Duration timeout = const Duration(seconds: 10),
  int expectedLiveWrappers = 0,
  int expectedLiveAdapters = 0,
}) async {
  if (!isDarwin) return;
  final deadline = DateTime.now().add(timeout);
  while ((_DarwinTextureLifetime.liveMetalTextureWrappers() !=
              expectedLiveWrappers ||
          _DarwinTextureLifetime.liveFlutterTextureAdapters() !=
              expectedLiveAdapters) &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Mounts a ThermionWidget backed by [viewer], pumps a few frames so the
/// surface is actually allocated and rendered into, then unmounts it. The
/// viewer (and its view) are reused across sessions — this is the common
/// pattern (one long-lived viewer, navigate into/out of the 3D screen), and
/// it is the pattern the fix targets: each remount reuses one registered macOS
/// texture producer while recreating only the Filament target.
Future<void> _pumpOneSessionAndUnmount(
  WidgetTester tester,
  ThermionViewer viewer,
  int width,
  int height,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width.toDouble(),
          height: height.toDouble(),
          child: ThermionWidget(viewer: viewer),
        ),
      ),
    ),
  );
  // Let the descriptor allocate, bind, and render a handful of frames.
  await tester.pumpAndSettle(const Duration(seconds: 2));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  // Unmount the widget (destroyTextureForView owns the complete
  // render-target and descriptor teardown).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

/// Give the engine, the Dart GC, and Metal's deferred-release queue time to
/// settle before sampling phys_footprint.
Future<void> _drain(WidgetTester tester) async {
  // Pump a few frames so queued teardown and Metal's autorelease pool run.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await Future<void>.delayed(const Duration(milliseconds: 2500));
}

void _logLiveDarwinTextures(bool isDarwin, String stage) {
  if (!isDarwin) return;
  debugPrint(
    '[leak-test] $stage live wrappers='
    '${_DarwinTextureLifetime.liveMetalTextureWrappers()} adapters='
    '${_DarwinTextureLifetime.liveFlutterTextureAdapters()}',
  );
}

void _expectNoLiveDarwinTextures(
  bool isDarwin,
  String stage, {
  int expectedLiveWrappers = 0,
  int expectedLiveAdapters = 0,
}) {
  if (!isDarwin) return;
  final wrappers = _DarwinTextureLifetime.liveMetalTextureWrappers();
  final adapters = _DarwinTextureLifetime.liveFlutterTextureAdapters();
  _logLiveDarwinTextures(isDarwin, stage);
  expect(
    wrappers,
    expectedLiveWrappers,
    reason: '$stage had an unexpected number of MetalTextureWrappers after '
        'widget teardown',
  );
  expect(
    adapters,
    expectedLiveAdapters,
    reason: '$stage had an unexpected number of registered '
        'FlutterMetalTextureWrappers',
  );
}

class _DarwinTextureLifetime {
  static final DynamicLibrary _lib = DynamicLibrary.process();

  static final int Function() liveMetalTextureWrappers =
      _lib.lookupFunction<Int64 Function(), int Function()>(
          'thermion_flutter_live_metal_texture_wrapper_count');

  static final int Function() liveFlutterTextureAdapters =
      _lib.lookupFunction<Int64 Function(), int Function()>(
          'thermion_flutter_live_metal_texture_adapter_count');

  static final int Function() createdMetalTextureWrappers =
      _lib.lookupFunction<Int64 Function(), int Function()>(
          'thermion_flutter_created_metal_texture_wrapper_count');

  static final int Function() createdFlutterTextureAdapters =
      _lib.lookupFunction<Int64 Function(), int Function()>(
          'thermion_flutter_created_metal_texture_adapter_count');

  static final bool Function(int, int) fillPixelBuffer =
      _lib.lookupFunction<Bool Function(Int64, Uint8), bool Function(int, int)>(
    'thermion_flutter_fill_metal_texture_pixel_buffer',
  );
}

int _median(List<int> values) {
  final sorted = values.toList()..sort();
  return sorted[sorted.length ~/ 2];
}

class _DarwinFlutterTextureRegistry {
  static final ThermionTextureRegistry instance =
      ThermionTextureRegistry.castFrom(
    SwiftThermionFlutterPluginObjCAPI.textureRegistry(),
  );
}

/// Thin FFI wrapper around the mach `task_info` call.
///
/// We bind this directly rather than going through a plugin channel so the
/// measurement itself can't perturb the heap in a way that masks the leak.
class _DarwinMemory {
  static final DynamicLibrary _lib = DynamicLibrary.process();

  // kern_return_t task_info(task_name_t target, task_flavor_t flavor,
  //                         task_info_t task_info_out,
  //                         mach_msg_type_number_t *task_info_count);
  //
  // task_name_t / task_flavor_t / mach_msg_type_number_t are all natural_t
  // (uint32) on 64-bit darwin, and mach_port_t is uint32. We bind the
  // integer args as Uint32 so the values aren't misread.
  static final int Function(int, int, Pointer<Uint8>, Pointer<Uint32>)
      _taskInfo = _lib.lookupFunction<
          Int32 Function(
            Uint32,
            Uint32,
            Pointer<Uint8>,
            Pointer<Uint32>,
          ),
          int Function(
            int,
            int,
            Pointer<Uint8>,
            Pointer<Uint32>,
          )>('task_info');

  // mach_port_t mach_task_self(void);  (mach_port_t == uint32)
  static final int Function() _machTaskSelf =
      _lib.lookupFunction<Uint32 Function(), int Function()>('mach_task_self');

  // TASK_VM_INFO flavor. phys_footprint lives in this struct.
  static const _taskVmInfoFlavor = 22;
  // Buffer capacity in natural_t (uint32) units. task_info writes at most
  // the full task_vm_info_data_t (rev7, ~400 bytes); 256 uint32 = 1 KB is
  // comfortably past that. We pass this as the in count so the kernel
  // doesn't reject the call with KERN_INVALID_ARGUMENT.
  static const _bufferNaturalCount = 256;

  /// Returns the process's phys_footprint in bytes, or -1 on failure.
  ///
  /// phys_footprint is the memory the kernel considers "owned" by the
  /// process — it drops when IOSurfaces and MTLTextures are actually
  /// released, even if the underlying allocation came from a shared GPU
  /// pool. That makes it the right signal for this leak: a retained
  /// MTLTexture keeps its IOSurface alive and phys_footprint stays high.
  static int physFootprintBytes() {
    if (!Platform.isMacOS && !Platform.isIOS) return -1;

    final buffer = calloc<Uint8>(_bufferNaturalCount * 4);
    final outCount = calloc<Uint32>();
    try {
      // count is in/out: set to the buffer capacity (in natural_t units)
      // before the call; the kernel returns the count it actually filled.
      outCount.value = _bufferNaturalCount;
      final kr = _taskInfo(
        _machTaskSelf(),
        _taskVmInfoFlavor,
        buffer,
        outCount,
      );
      if (kr != 0) return -1;

      // task_vm_info layout (see mach/mach/task_info.h):
      //   u64 virtual_size          // offset 0
      //   i32 region_count          // offset 8
      //   i32 page_size             // offset 12
      //   u64 resident_size         // offset 16
      //   u64 resident_size_peak    // offset 24
      //   u64 device                // offset 32
      //   u64 device_peak           // offset 40
      //   u64 internal              // offset 48
      //   u64 internal_peak         // offset 56
      //   u64 external              // offset 64
      //   u64 external_peak         // offset 72
      //   u64 reusable              // offset 80
      //   u64 reusable_peak         // offset 88
      //   u64 purgeable_volatile_pmap       // offset 96
      //   u64 purgeable_volatile_resident   // offset 104
      //   u64 purgeable_volatile_virtual    // offset 112
      //   u64 compressed            // offset 120
      //   u64 compressed_peak       // offset 128
      //   u64 compressed_lifetime   // offset 136
      //   u64 phys_footprint        // offset 144
      final u64 = buffer.cast<Uint64>();
      return u64[18]; // 18 * 8 = 144 bytes
    } finally {
      calloc.free(buffer);
      calloc.free(outCount);
    }
  }
}
