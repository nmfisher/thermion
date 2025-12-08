#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include <stddef.h>

#ifdef __cplusplus
extern "C"
{
#endif

    // ============================================================================
    // TSurfaceOrientation
    // ============================================================================

    // Create a surface orientation builder
    EMSCRIPTEN_KEEPALIVE TSurfaceOrientationBuilder* SurfaceOrientationBuilder_create();

    // Configure the builder
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_vertexCount(TSurfaceOrientationBuilder* builder, size_t count);
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_normals(
        TSurfaceOrientationBuilder* builder,
        const float* normals,
        size_t stride
    );
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_tangents(
        TSurfaceOrientationBuilder* builder,
        const float* tangents,
        size_t stride
    );
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_uvs(
        TSurfaceOrientationBuilder* builder,
        const float* uvs,
        size_t stride
    );
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_positions(
        TSurfaceOrientationBuilder* builder,
        const float* positions,
        size_t stride
    );
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_triangleCount(TSurfaceOrientationBuilder* builder, size_t count);
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_triangles_uint(
        TSurfaceOrientationBuilder* builder,
        const uint32_t* triangles
    );
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_triangles_ushort(
        TSurfaceOrientationBuilder* builder,
        const uint16_t* triangles
    );

    // Build and destroy
    EMSCRIPTEN_KEEPALIVE TSurfaceOrientation* SurfaceOrientationBuilder_build(TSurfaceOrientationBuilder* builder);
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_destroy(TSurfaceOrientationBuilder* builder);

    // ============================================================================
    // TSurfaceOrientation Operations
    // ============================================================================

    // Get vertex count
    EMSCRIPTEN_KEEPALIVE size_t SurfaceOrientation_getVertexCount(TSurfaceOrientation* orientation);

    // Get quaternions in different formats
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_getQuats_float4(
        TSurfaceOrientation* orientation,
        float* out,
        size_t quatCount,
        size_t stride
    );
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_getQuats_short4(
        TSurfaceOrientation* orientation,
        int16_t* out,
        size_t quatCount,
        size_t stride
    );
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_getQuats_half4(
        TSurfaceOrientation* orientation,
        uint16_t* out,
        size_t quatCount,
        size_t stride
    );

    // Destroy
    EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_destroy(TSurfaceOrientation* orientation);

#ifdef __cplusplus
}
#endif