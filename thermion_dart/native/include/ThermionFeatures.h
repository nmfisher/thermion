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

// Built-in helper materials (<KEY>_ENABLED, one per BuiltInMaterial key in
// lib/src/filament/src/interface/built_in_material.dart). hook/build.dart
// passes an explicit =0 or =1 for EVERY key on native builds; these defaults
// cover build paths that pass nothing (web/macos CMake builds), where the
// materials are not resgen-linked into libthermion_dart. All guards are value
// checks (`#if`), so a macro defined to 0 excludes the material — the old
// presence checks (`#ifdef`) would have included it.
#ifndef IMAGE_ENABLED
#define IMAGE_ENABLED 0
#endif
#ifndef GRID_ENABLED
#define GRID_ENABLED 0
#endif
#ifndef GIZMO_ENABLED
#define GIZMO_ENABLED 0
#endif
#ifndef TRANSLATION_AXIS_ENABLED
#define TRANSLATION_AXIS_ENABLED 0
#endif
#ifndef BONE_OVERLAY_ENABLED
#define BONE_OVERLAY_ENABLED 0
#endif
#ifndef SILHOUETTE_ENABLED
#define SILHOUETTE_ENABLED 0
#endif
#ifndef EDGE_OUTLINE_ENABLED
#define EDGE_OUTLINE_ENABLED 0
#endif
#ifndef WIREFRAME_ENABLED
#define WIREFRAME_ENABLED 0
#endif
#ifndef NORMAL_COLOR_ENABLED
#define NORMAL_COLOR_ENABLED 0
#endif
#ifndef SHARP_EDGE_ENABLED
#define SHARP_EDGE_ENABLED 0
#endif
#ifndef CAPTURE_UV_ENABLED
#define CAPTURE_UV_ENABLED 0
#endif
#ifndef LINEAR_DEPTH_ENABLED
#define LINEAR_DEPTH_ENABLED 0
#endif
#ifndef UNLIT_FIXED_SIZE_ENABLED
#define UNLIT_FIXED_SIZE_ENABLED 0
#endif
