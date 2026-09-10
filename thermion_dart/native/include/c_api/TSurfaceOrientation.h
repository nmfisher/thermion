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

    // Configure and build synchronously. Input lengths are scalar element counts;
    // a zero length omits that input. Strides are in bytes. No input pointers are
    // retained after this call returns, so Dart can borrow them with .address.
    EMSCRIPTEN_KEEPALIVE TSurfaceOrientation* SurfaceOrientation_build(
        size_t vertexCount,
        const float* normals, size_t normalsLength, size_t normalStride,
        const float* tangents, size_t tangentsLength, size_t tangentStride,
        const float* uvs, size_t uvsLength, size_t uvStride,
        const float* positions, size_t positionsLength, size_t positionStride,
        size_t triangleCount,
        const uint32_t* triangles32, size_t triangles32Length,
        const uint16_t* triangles16, size_t triangles16Length
    );

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
