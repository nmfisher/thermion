#pragma once

// Compile-time switches for the native library. Each one is a value macro with
// a header default, so every guarded translation unit sees the same value and
// a typo in an `#if` fails loudly under -Wundef instead of silently disabling
// a feature. The build hook (hook/build.dart) passes -D<SWITCH>=1 only when a
// switch is enabled, so default compile command lines are unchanged.

// Runtime material compilation is opt-in and off by default: the header
// defaults the macro to 0 and hook/build.dart passes
// -DTHERMION_ENABLE_RUNTIME_MATERIALS=1 only when `runtime_materials: true`.
// Every guard is a value check (TMaterialCompiler.cpp and the CMake builds
// below), so a macro defined to 0 selects the stub instead of the real
// compiler; the previous presence checks (`#ifdef`) would have done the
// opposite.
#ifndef THERMION_ENABLE_RUNTIME_MATERIALS
#define THERMION_ENABLE_RUNTIME_MATERIALS 0
#endif
