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
// Status (see the fix branch for issue #178): bug 1 — balancing the
// unbalanced passRetained(+1) in MetalTextureWrapper + the render-target
// orphan — is landed and proven safe. It does NOT by itself stop this leak:
// the destroyed descriptor is still ARC-pinned in `_descriptors`, so its
// MetalTextureWrapper (and the imported MTLTexture's IOSurface) outlives the
// session. Fully freeing the surface (bug 2) requires releasing the wrapper
// only after Filament drops the import (view/RT destruction); doing it
// earlier over-releases the CVMetalTexture-backed MTLTexture and traps (see
// the reverted bug 2 commit). Until bug 2 lands safely, this test is
// expected to FAIL — it is the regression target for the complete fix.
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
      // viewer). It is also the pattern the fix targets: each remount
      // replaces the view's render target, which is when Filament releases
      // the previous session's imported MTLTexture and the plugin can
      // release the parked descriptor.
      final viewer = await ThermionFlutterPlugin.createViewer();

      // Warm up: the first session pays one-time costs (Filament engine,
      // shader compile, texture caches) that should NOT be charged against
      // steady-state. We measure drift from the second session onward.
      await _pumpOneSessionAndUnmount(tester, viewer, surfaceWidth, surfaceHeight);
      await _drain(tester);
      final baseline = isDarwin ? _DarwinMemory.physFootprintBytes() : 0;
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
      for (var i = 0; i < sessions; i++) {
        await _pumpOneSessionAndUnmount(
          tester,
          viewer,
          surfaceWidth,
          surfaceHeight,
        );
        await _drain(tester);
        final now = isDarwin ? _DarwinMemory.physFootprintBytes() : 0;
        debugPrint(
          '[leak-test] session ${i + 1}/$sessions phys_footprint='
          '${(now / 1024 / 1024).toStringAsFixed(2)} MB '
          '(delta=${((now - prev) / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
        prev = now;
      }
      final after = prev;

      // Tear down the reused viewer now that all sessions are measured.
      await viewer.dispose();

      if (!isDarwin) {
        // Sanity: the test compiles and runs on non-darwin, but asserts
        // nothing — the leak is darwin-only.
        return;
      }

      final drift = after - baseline;
      // Tolerance: half of one leaked surface's worth of total drift across
      // ALL sessions. A correct fix leaves behind only asynchronous cache
      // settling (well under one surface); a leak pins one surface per
      // session, so `sessions` surfaces vs. half-a-surface is a wide gap.
      const toleranceBytes = surfaceBytes ~/ 2;
      expect(
        drift,
        lessThan(toleranceBytes),
        reason:
            'phys_footprint grew by ${(drift / 1024 / 1024).toStringAsFixed(2)} '
            'MB across $sessions mount/unmount sessions (tolerance '
            '${(toleranceBytes / 1024 / 1024).toStringAsFixed(2)} MB); expected '
            'the darwin texture wrapper to release its +1 retain on destroy. '
            '(baseline=${(baseline / 1024 / 1024).toStringAsFixed(2)} MB, '
            'after=${(after / 1024 / 1024).toStringAsFixed(2)} MB)',
      );
    },
    // darwin-only leak: the unbalanced passRetained lives in
    // darwin/Classes/MetalTextureWrapper.swift.
    skip: !isDarwin,
  );
}

/// Mounts a ThermionWidget backed by [viewer], pumps a few frames so the
/// surface is actually allocated and rendered into, then unmounts it. The
/// viewer (and its view) are reused across sessions — this is the common
/// pattern (one long-lived viewer, navigate into/out of the 3D screen), and
/// it is the pattern the fix targets: each remount replaces the view's render
/// target, which is the point Filament releases the previous session's
/// imported MTLTexture and the plugin can release the parked descriptor.
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
  // Pump a few frames so the Dart GC and Metal's autorelease pool can run,
  // then wait in REAL time: the native passRetained(+1) is parked at dispose
  // and only drained at the next allocate, age-gated to >= 2 s of wall clock
  // (CFAbsoluteTimeGetCurrent, which pumps do not advance). Waiting past 2 s
  // here ensures the next session's allocate drains the previous park, and
  // its RT replacement releases the parked descriptor — so the previous
  // session's surface has actually freed before we sample.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await Future<void>.delayed(const Duration(milliseconds: 2500));
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
