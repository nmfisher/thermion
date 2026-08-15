#include <geometry/SurfaceOrientation.h>
#include <utils/compiler.h>

#include "Log.hpp"
#include "c_api/TSurfaceOrientation.h"

namespace thermion
{
    extern "C"
    {
        using namespace filament;
        using namespace filament::geometry;
        using namespace filament::math;

        // ============================================================================
        // TSurfaceOrientationBuilder
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE TSurfaceOrientationBuilder* SurfaceOrientationBuilder_create() {
            auto* builder = new SurfaceOrientation::Builder();
            return reinterpret_cast<TSurfaceOrientationBuilder*>(builder);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_vertexCount(TSurfaceOrientationBuilder* tBuilder, size_t count) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            builder->vertexCount(count);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_normals(
            TSurfaceOrientationBuilder* tBuilder,
            const float* normals,
            size_t stride
        ) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            const float3* normalsPtr = reinterpret_cast<const float3*>(normals);
            builder->normals(normalsPtr, stride);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_tangents(
            TSurfaceOrientationBuilder* tBuilder,
            const float* tangents,
            size_t stride
        ) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            const float4* tangentsPtr = reinterpret_cast<const float4*>(tangents);
            builder->tangents(tangentsPtr, stride);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_uvs(
            TSurfaceOrientationBuilder* tBuilder,
            const float* uvs,
            size_t stride
        ) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            const float2* uvsPtr = reinterpret_cast<const float2*>(uvs);
            builder->uvs(uvsPtr, stride);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_positions(
            TSurfaceOrientationBuilder* tBuilder,
            const float* positions,
            size_t stride
        ) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            const float3* positionsPtr = reinterpret_cast<const float3*>(positions);
            builder->positions(positionsPtr, stride);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_triangleCount(TSurfaceOrientationBuilder* tBuilder, size_t count) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            builder->triangleCount(count);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_triangles_uint(
            TSurfaceOrientationBuilder* tBuilder,
            const uint32_t* triangles
        ) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            const uint3* trianglesPtr = reinterpret_cast<const uint3*>(triangles);
            builder->triangles(trianglesPtr);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_triangles_ushort(
            TSurfaceOrientationBuilder* tBuilder,
            const uint16_t* triangles
        ) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            const ushort3* trianglesPtr = reinterpret_cast<const ushort3*>(triangles);
            builder->triangles(trianglesPtr);
        }

        EMSCRIPTEN_KEEPALIVE TSurfaceOrientation* SurfaceOrientationBuilder_build(TSurfaceOrientationBuilder* tBuilder) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            auto* orientation = builder->build();
            return reinterpret_cast<TSurfaceOrientation*>(orientation);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientationBuilder_destroy(TSurfaceOrientationBuilder* tBuilder) {
            auto* builder = reinterpret_cast<SurfaceOrientation::Builder*>(tBuilder);
            delete builder;
        }

        // ============================================================================
        // TSurfaceOrientation Operations
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE size_t SurfaceOrientation_getVertexCount(TSurfaceOrientation* tOrientation) {
            auto* orientation = reinterpret_cast<SurfaceOrientation*>(tOrientation);
            return orientation->getVertexCount();
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_getQuats_float4(
            TSurfaceOrientation* tOrientation,
            float* out,
            size_t quatCount,
            size_t stride
        ) {
            auto* orientation = reinterpret_cast<SurfaceOrientation*>(tOrientation);
            quatf* outPtr = reinterpret_cast<quatf*>(out);
            orientation->getQuats(outPtr, quatCount, stride);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_getQuats_short4(
            TSurfaceOrientation* tOrientation,
            int16_t* out,
            size_t quatCount,
            size_t stride
        ) {
            auto* orientation = reinterpret_cast<SurfaceOrientation*>(tOrientation);
            short4* outPtr = reinterpret_cast<short4*>(out);
            orientation->getQuats(outPtr, quatCount, stride);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_getQuats_half4(
            TSurfaceOrientation* tOrientation,
            uint16_t* out,
            size_t quatCount,
            size_t stride
        ) {
            auto* orientation = reinterpret_cast<SurfaceOrientation*>(tOrientation);
            quath* outPtr = reinterpret_cast<quath*>(out);
            orientation->getQuats(outPtr, quatCount, stride);
        }

        EMSCRIPTEN_KEEPALIVE void SurfaceOrientation_destroy(TSurfaceOrientation* tOrientation) {
            auto* orientation = reinterpret_cast<SurfaceOrientation*>(tOrientation);
            delete orientation;
        }

    } // extern "C"
} // namespace thermion