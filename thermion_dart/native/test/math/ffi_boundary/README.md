# Isolated native matrix getter benchmark

This standalone package compares the C-to-Dart matrix return paths without
Filament, engine lookup, matrix math, or the existing Dart `Matrix4` conversion
helper. It uses the production `double4x4` definition from `APIBoundaryTypes.h`.
Both C getters copy the same 128 bytes from the same preinitialized corpus:

- Return a `double4x4` by value and read its generated Dart struct fields.
- Write to a reused native allocation and read its cached `Float64List` view.
- Write to a reused Dart `Float64List` borrowed through `.address` during the
  generated leaf call, then read that list.

All bindings are generated with ffigen into `lib/bindings.g.dart`. The build hook
only compiles the two C getters at `-O3`; it does not generate bindings or build
the Thermion engine. The benchmark symbols are not part of Thermion's library.

## Run

From the repository root, `make bindings` includes this fixture. To regenerate
only its bindings, use `make matrix-benchmark-bindings`.

```sh
cd thermion_dart/native/test/math/ffi_boundary
dart pub get
flutter analyze bin hook lib
dart run bin/benchmark.dart jit > /tmp/matrix-ffi-jit.json
dart build cli -t bin/benchmark.dart -o /tmp/matrix-ffi-aot
/tmp/matrix-ffi-aot/bundle/bin/benchmark aot > /tmp/matrix-ffi-aot.json
```

The executable path above is for macOS/Linux. The mode argument is a label for
the output, not a compiler switch. Use `dart build cli` for AOT: Dart 3.12.1's
`dart compile exe` does not support this package's native build hook.

Each process warms every case for 100,000 calls and takes 15 samples of
1,000,000 calls each, shuffling case order between rounds with a fixed seed.
The corpus contains 256 matrices (32 KiB), with a different matrix selected
each call. Each case has its own loop and one FFI call per iteration, with no
per-iteration closure dispatch. Output allocations and views are made before
timing. Any allocation or wrapping performed by Dart's struct-return machinery
remains part of the measurement.

One set of cases consumes element 12; another sums all 16 elements using the
same addition order. Every timed checksum is verified, every element is checked
against the source corpus before timing, and guard elements around both output
buffers are checked after timing. Native allocations are freed in `finally`.

## Recorded results

Apple M2 Pro, macOS ARM64, Dart 3.12.1 stable, Apple clang 21.0.0, C `-O3`.
Numbers are nanoseconds per operation: median of the three process medians,
with the range of process medians in parentheses. JIT and AOT processes were
alternated across three trials. Raw samples and SDK metadata are in
[`results/m2_pro.json`](results/m2_pro.json).

| Result consumption | Path | JIT ns/op | AOT ns/op |
| --- | --- | ---: | ---: |
| One element | Struct return | 15.09 (15.06–15.43) | 13.17 (13.16–13.34) |
| One element | Native output pointer | 5.59 (5.56–5.68) | 4.52 (4.49–4.62) |
| One element | Borrowed Dart typed data | 5.25 (5.18–5.51) | 4.22 (4.22–4.28) |
| All 16 elements | Struct return | 19.11 (18.80–19.18) | 18.83 (18.76–19.12) |
| All 16 elements | Native output pointer | 11.90 (11.84–12.02) | 8.42 (8.37–8.57) |
| All 16 elements | Borrowed Dart typed data | 13.25 (13.19–13.27) | 8.24 (8.13–8.29) |

In this fixture, borrowed Dart output is about 2.3 times faster in AOT when
consuming all 16 elements, saving about 10.6 ns per call. Native allocation is
not required to obtain that benefit. The previous full getter benchmark also
included our temporary-list conversion and `Matrix4` allocation; these results
show an advantage without that conversion helper.

Inspection with `xcrun llvm-objdump --disassemble` confirmed that the JIT and AOT
libraries contain identical C getter instructions. Each getter performs four
paired 128-bit loads and four paired stores. On this ARM64 target, the struct
return writes to a caller-provided result address in `x8`; the output-pointer
function writes to its explicit argument in `x2`. Return-by-value therefore
already uses an implicit output pointer at the C ABI level on this target.
The observed difference includes Dart's handling and consumption of the result.

These are warm-cache microbenchmarks on one architecture, not a pure measurement
of the call instruction or proof of improved frame time. Loop/index/checksum
work is included, not subtracted. Struct field access and typed-data access use
different Dart representations, and allocations/GC have not been profiled.
Neither C getter is zero-copy: both transfer 128 bytes to output storage. Web,
mobile hardware, full Flutter workloads, queue behavior, and matrix-owner
lifetime/leak testing are outside this fixture.
