#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

    /// Shading models, mirroring filamat::MaterialBuilder::Shading.
    /// Keep in sync with filament::Shading in MaterialEnums.h.
    enum TShading
    {
        SHADING_UNLIT = 0,
        SHADING_LIT = 1,
        SHADING_SUBSURFACE = 2,
        SHADING_CLOTH = 3,
        SHADING_SPECULAR_GLOSSINESS = 4,
    };
    typedef enum TShading TShading;

    /// Opaque payload type for a compiled material package.
    typedef struct TMaterialCompilerPackage TMaterialCompilerPackage;

    /// Returns 1 when this build was compiled with runtime material
    /// compilation support (the `runtime_materials` build flag), 0 otherwise.
    /// When 0, MaterialCompiler_compileMaterialSource returns null and callers
    /// should fall back to precompiled .filamat packages.
    EMSCRIPTEN_KEEPALIVE uint8_t MaterialCompiler_isSupported();

    /// Compiles a material source string to a .filamat package at runtime.
    ///
    /// `tJobThread` is the render job thread that owns `tEngine`; the compile
    /// runs there because MaterialBuilder::build drives the engine's
    /// JobSystem, whose calling thread must have been adopted — which the
    /// engine-creating job thread is. `materialSource` is the GLSL of the
    /// material() function, the same string format accepted by
    /// MaterialBuilder::material(), e.g.:
    ///
    ///   void material(inout MaterialInputs material) {
    ///       prepareMaterial(material);
    ///       material.baseColor.rgb = float3(1.0, 0.0, 0.0);
    ///   }
    ///
    /// `name` is the material name (used in diagnostics/shader names). `shading`
    /// selects the lighting model. The output target API is derived from the
    /// compiled platform this function is linked into (e.g. Metal on Apple
    /// platforms, OpenGL+Vulkan on Android/Linux/Windows), matching how the
    /// precompiled Thermion materials are built.
    ///
    /// Returns null when compilation fails or this build lacks runtime material
    /// support. Failure diagnostics are logged through the Filament logger.
    ///
    /// This call blocks the calling Dart thread until the compile finishes on
    /// the job thread (hundreds of ms). The Dart API dispatches it via the
    /// same future-based task pattern as the other *JobThread entry points,
    /// so Dart code simply awaits.
    ///
    /// The returned package is owned by the caller and must be released with
    /// MaterialCompiler_destroyPackage.
    EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialSource(
        TJobThread *tJobThread,
        TEngine *tEngine,
        const char *name,
        const char *materialSource,
        TShading shading);

    /// Compiles a full .mat material package source at runtime, using the same
    /// parser (matp) that backs the matc tool. Unlike
    /// MaterialCompiler_compileMaterialSource, `matSource` is a complete .mat
    /// file: `material { ... }` configuration blocks (name, shading model,
    /// parameters, variants, ...), optional `vertex { ... }` code and the
    /// `fragment { ... }` block, e.g.:
    ///
    ///   material {
    ///       name : "MyMaterial",
    ///       shadingModel : unlit,
    ///       parameters : [ { type : float4, name : baseColor } ]
    ///   }
    ///   fragment {
    ///       void material(inout MaterialInputs material) {
    ///           prepareMaterial(material);
    ///           material.baseColor = materialParams.baseColor;
    ///       }
    ///   }
    ///
    /// `includesJson` is either null or a JSON object mapping include names to
    /// file contents, e.g. {"common.glsl": "..."}. `#include "name"` directives
    /// in the source (and in included files) are resolved against this map by
    /// exact name before parsing; there is no filesystem access. The JSON must
    /// be a flat object of string keys to string values (what Dart's
    /// json.encode emits for a Map<String, String>); all standard JSON string
    /// escapes, including \u and surrogate pairs, are supported.
    ///
    /// The platform/target API/optimization are derived the same way as
    /// MaterialCompiler_compileMaterialSource; all other compilation settings
    /// come from the .mat source itself.
    ///
    /// Returns null when include resolution, parsing or compilation fails, or
    /// when this build lacks runtime material support. Failure diagnostics are
    /// logged through the Filament logger. Blocking/threading semantics and
    /// ownership of the returned package match
    /// MaterialCompiler_compileMaterialSource.
    EMSCRIPTEN_KEEPALIVE TMaterialCompilerPackage *MaterialCompiler_compileMaterialPackage(
        TJobThread *tJobThread,
        TEngine *tEngine,
        const char *name,
        const char *matSource,
        const char *includesJson);

    /// Copies the compiled package bytes into `out`, which must hold at least
    /// MaterialCompiler_getPackageSize bytes. Returns the number of bytes copied.
    EMSCRIPTEN_KEEPALIVE size_t MaterialCompiler_getPackageBytes(
        TMaterialCompilerPackage *package, uint8_t *out, size_t capacity);

    /// Returns a pointer to the compiled package bytes living in native/Wasm
    /// heap memory, or null. Valid until MaterialCompiler_destroyPackage; pair
    /// with MaterialCompiler_getPackageSize for the length. Web callers should
    /// read the bytes through this pointer (typed-array view over the Wasm
    /// heap) instead of MaterialCompiler_getPackageBytes, which can only write
    /// into a native scratch buffer on that platform.
    EMSCRIPTEN_KEEPALIVE const uint8_t *MaterialCompiler_getPackagePtr(
        TMaterialCompilerPackage *package);

    /// Returns the byte size of the compiled package.
    EMSCRIPTEN_KEEPALIVE size_t MaterialCompiler_getPackageSize(TMaterialCompilerPackage *package);

    /// Frees a package returned by MaterialCompiler_compileMaterialSource or
    /// MaterialCompiler_compileMaterialPackage. Null is ignored.
    EMSCRIPTEN_KEEPALIVE void MaterialCompiler_destroyPackage(TMaterialCompilerPackage *package);

#ifdef __cplusplus
}
#endif
