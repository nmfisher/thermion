// Regression test for the iOS/macOS IOSurface leak described in
// https://github.com/nmfisher/thermion/issues/178.
//
// The original bug: MetalTextureWrapper created a fresh CVMetalTextureCache per
// texture. Releasing that cache does not synchronously free the IOSurfaces it
// has cached, so every CVMetalTextureCacheCreateTextureFromImage stranded ~one
// IOSurface — roughly one screen-sized surface per mount/unmount. The fix
// shares one process-wide CVMetalTextureCache (see
// darwin/Classes/MetalTextureWrapper.swift).
//
// What this test checks, and why it checks it that way:
//
// The darwin texture teardown is correct — create/destroy of the platform
// descriptor, the Flutter adapter, and the Filament render target are all
// balanced. The GPU memory nonetheless takes a few seconds to reclaim because
// the reclamation is asynchronous: Flutter frees the adapter on its raster
// thread (onTextureUnregistered) and Filament destroys the imported textures on
// its render thread, and Metal returns freed texture memory to its own internal
// pool rather than to the OS immediately. The net effect is bounded allocator
// churn: phys_footprint rises while Metal/Filament pools warm over the first
// few allocations, then plateaus as the pools reuse freed memory. That churn is
// NOT a leak — it does not keep growing.
//
// A genuine per-session leak, by contrast, grows LINEARLY: ~one surface per
// session, every session, without decelerating. So this test does not assert
// that phys_footprint stays flat (bounded churn legitimately prevents that). It
// asserts that the STEADY-STATE per-session growth — the average delta over the
// trailing sessions, after the pools have warmed — stays well under one BGRA
// surface per session. The original leak (~one surface/session) fails that; the
// fix's churn plateau (~half a surface or less) passes it.
//
// Run on a real target:
//
//   flutter test integration_test/darwin_texture_leak_test.dart -d macos
//   flutter test integration_test/darwin_texture_leak_test.dart -d <ios-device>
//
// Skipped on non-darwin platforms: the leak is specific to the Metal
// texture wrapper in darwin/Classes/MetalTextureWrapper.swift.
import 'dart:io';

import 'package:flutter/material.dart' hide View;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final bool isDarwin = Platform.isMacOS || Platform.isIOS;

  testWidgets(
    'repeated ThermionWidget mount/unmount shows bounded, not linear, growth',
    (tester) async {
      // Surface size chosen so a single leaked BGRA IOSurface is large
      // relative to cache noise: 768x576x4 ≈ 1.69 MB.
      const surfaceWidth = 768;
      const surfaceHeight = 576;
      const surfaceBytes = surfaceWidth * surfaceHeight * 4;

      // One long-lived viewer reused across every session — the common
      // pattern (navigate into/out of a 3D screen without rebuilding the
      // viewer).
      final viewer = await ThermionFlutterPlugin.createViewer();

      // Warm up one-time costs (Filament engine, shader compile, and the
      // first allocator-pool ramp) so they are not charged against the
      // measured steady-state slope.
      for (var i = 0; i < 2; i++) {
        await _pumpOneSessionAndUnmount(
          tester, viewer, surfaceWidth, surfaceHeight);
        await _drain(tester);
      }
      final baseline = isDarwin ? _DarwinMemory.physFootprintBytes() : 0;
      debugPrint(
        '[leak-test] baseline phys_footprint='
        '${(baseline / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // Measured sessions. Sample phys_footprint after each so the per-session
      // slope (and whether it decelerates) is visible.
      const sessions = 12;
      final samples = <int>[];
      var prev = baseline;
      for (var i = 0; i < sessions; i++) {
        await _pumpOneSessionAndUnmount(
          tester, viewer, surfaceWidth, surfaceHeight);
        await _drain(tester);
        final now = isDarwin ? _DarwinMemory.physFootprintBytes() : 0;
        samples.add(now);
        debugPrint(
          '[leak-test] session ${i + 1}/$sessions phys_footprint='
          '${(now / 1024 / 1024).toStringAsFixed(2)} MB '
          '(delta=${((now - prev) / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
        prev = now;
      }

      await viewer.dispose();

      if (!isDarwin) {
        // Sanity: the test compiles and runs on non-darwin, but asserts
        // nothing — the leak is darwin-only.
        return;
      }

      // Per-session deltas and the average over each half.
      final deltas = <double>[];
      for (var i = 0; i < sessions; i++) {
        final p = i == 0 ? baseline : samples[i - 1];
        deltas.add((samples[i] - p).toDouble());
      }
      const half = sessions ~/ 2;
      double avg(List<double> xs) =>
          xs.fold<double>(0, (a, b) => a + b) / xs.length;
      final firstHalfAvg = avg(deltas.sublist(0, half));
      final secondHalfAvg = avg(deltas.sublist(half));
      debugPrint(
        '[leak-test] avg delta/session: first half='
        '${(firstHalfAvg / 1024 / 1024).toStringAsFixed(2)} MB, '
        'second half=${(secondHalfAvg / 1024 / 1024).toStringAsFixed(2)} MB '
        '(one surface = ${(surfaceBytes / 1024 / 1024).toStringAsFixed(2)} MB)',
      );

      // The assertion: steady-state (trailing-half) per-session growth must
      // stay under one BGRA surface. The original per-CVMetalTextureCache leak
      // grew ~one surface per session, so its return trips this. Bounded
      // Metal/Filament allocator churn plateaus well below one surface per
      // session, so a correct fix passes with margin.
      expect(
        secondHalfAvg,
        lessThan(surfaceBytes.toDouble()),
        reason:
            'Steady-state phys_footprint growth averaged '
            '${(secondHalfAvg / 1024 / 1024).toStringAsFixed(2)} MB/session '
            'over the trailing $half sessions — at or above one leaked BGRA '
            'surface (${(surfaceBytes / 1024 / 1024).toStringAsFixed(2)} MB) '
            'per session, which indicates a per-mount/unmount leak rather '
            'than bounded allocator churn. '
            '(first-half avg ${(firstHalfAvg / 1024 / 1024).toStringAsFixed(2)} '
            'MB/session, baseline ${(baseline / 1024 / 1024).toStringAsFixed(2)} MB)',
      );
    },
    // darwin-only: the CVMetalTextureCache leak lives in
    // darwin/Classes/MetalTextureWrapper.swift.
    skip: !isDarwin,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Mounts a ThermionWidget backed by [viewer], pumps a few frames so the
/// surface is actually allocated and rendered into, then unmounts it. The
/// viewer (and its view) are reused across sessions.
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
  await tester.pumpAndSettle(const Duration(milliseconds: 800));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  // Unmount the widget (destroyTextureForView owns the complete
  // render-target and descriptor teardown).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle(const Duration(milliseconds: 800));
}

/// Give the engine, the Dart GC, and Metal's deferred-release queue time to
/// settle before sampling phys_footprint.
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await Future<void>.delayed(const Duration(milliseconds: 1000));
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
  static final int Function() _machTaskSelf = _lib.lookupFunction<
      Uint32 Function(),
      int Function()>('mach_task_self');

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
