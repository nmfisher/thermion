#include <filament/Engine.h>
#include <filament/Camera.h>
#include <filament/Texture.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>
#include <math/mat4.h>
#include <math/vec2.h>
#include <math/vec3.h>
#include <math/vec4.h>
#include <utils/EntityManager.h>
#include <backend/PixelBufferDescriptor.h>
#include "Log.hpp"
#include <vector>
#include <algorithm>

#include <iostream>

#include "CustomGeometry.hpp"
#include "UnprojectTexture.hpp"

namespace thermion_filament {

void UnprojectTexture::unproject(utils::Entity entity, const uint8_t* inputTexture, uint8_t* outputTexture, uint32_t inputWidth, uint32_t inputHeight,
                                 uint32_t outputWidth, uint32_t outputHeight) {
    auto& rm = _engine->getRenderableManager();
    auto& tm = _engine->getTransformManager();

    // Get the inverse view-projection matrix
    math::mat4 invViewProj = Camera::inverseProjection(_camera.getProjectionMatrix()) * _camera.getModelMatrix();

    // Get the world transform of the entity
    auto ti = tm.getInstance(entity);
    math::mat4f worldTransform = tm.getWorldTransform(ti);
    auto inverseWorldTransform = inverse(worldTransform);

    // Get vertex, normal, UV, and index data from CustomGeometry
    const float* vertices = _geometry->vertices;
    const float* uvs = _geometry->uvs;
    const uint16_t* indices = _geometry->indices;
    uint32_t numIndices = _geometry->numIndices;

    // Iterate over each pixel in the output texture
    for (uint32_t y = 0; y < outputHeight; ++y) {
        for (uint32_t x = 0; x < outputWidth; ++x) {
            // Convert output texture coordinates to UV space
            math::float2 uv(static_cast<float>(x) / outputWidth, static_cast<float>(y) / outputHeight);
            
            // Use the UV coordinates to get the corresponding 3D position on the renderable
            math::float3 objectPos;
            math::float2 interpolatedUV;
            bool found = false;

            // Iterate over triangles to find which one contains this UV coordinate
            for (size_t i = 0; i < numIndices; i += 3) {
                math::float2 uv0 = *(math::float2*)&uvs[indices[i] * 2];
                math::float2 uv1 = *(math::float2*)&uvs[indices[i+1] * 2];
                math::float2 uv2 = *(math::float2*)&uvs[indices[i+2] * 2];

                if (isInsideTriangle(uv, uv0, uv1, uv2)) {
                    // Compute barycentric coordinates in UV space
                    math::float3 bary = barycentric(uv, uv0, uv1, uv2);

                    // Interpolate 3D position
                    math::float3 v0(vertices[indices[i] * 3], vertices[indices[i] * 3 + 1], vertices[indices[i] * 3 + 2]);
                    math::float3 v1(vertices[indices[i+1] * 3], vertices[indices[i+1] * 3 + 1], vertices[indices[i+1] * 3 + 2]);
                    math::float3 v2(vertices[indices[i+2] * 3], vertices[indices[i+2] * 3 + 1], vertices[indices[i+2] * 3 + 2]);
                    objectPos = v0 * bary.x + v1 * bary.y + v2 * bary.z;

                    interpolatedUV = uv;
                    found = true;
                    break;
                }
            }

            if (found) {
                // Transform the object position to world space
                math::float3 worldPos = (worldTransform * math::float4(objectPos, 1.0f)).xyz;

                // Project the world position to screen space
                math::float4 clipPos = _camera.getProjectionMatrix() * _camera.getViewMatrix() * math::float4(worldPos, 1.0f);
                math::float3 ndcPos = clipPos.xyz / clipPos.w;

                // Convert NDC to screen coordinates
                int sx = static_cast<int>((ndcPos.x * 0.5f + 0.5f) * inputWidth);
                int sy = static_cast<int>((1.0f - (ndcPos.y * 0.5f + 0.5f)) * inputHeight);

                // Ensure we're within the input texture bounds
                if (sx >= 0 && sx < inputWidth && sy >= 0 && sy < inputHeight) {
                    // Sample the input texture
                    int inputIndex = (sy * inputWidth + sx) * 4;
                    int outputIndex = (y * outputWidth + x) * 4;

                    // Copy the color to the output texture
                    std::copy_n(&inputTexture[inputIndex], 4, &outputTexture[outputIndex]);
                }
            }
        }
    }
}

math::float3 UnprojectTexture::doUnproject(const math::float2& screenPos, float depth, const math::mat4& invViewProj) {
    math::float4 clipSpace(screenPos.x * 2.0f - 1.0f, screenPos.y * 2.0f - 1.0f, depth * 2.0f - 1.0f, 1.0f);
    math::float4 worldSpace = invViewProj * clipSpace;
    return math::float3(worldSpace.xyz) / worldSpace.w;
}

bool UnprojectTexture::isInsideTriangle(const math::float2& p, const math::float2& a, const math::float2& b, const math::float2& c) {
    float d1 = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y);
    float d2 = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y);
    float d3 = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y);
    return (d1 >= 0 && d2 >= 0 && d3 >= 0) || (d1 <= 0 && d2 <= 0 && d3 <= 0);
}

math::float3 UnprojectTexture::barycentric(const math::float2& p, const math::float2& a, const math::float2& b, const math::float2& c) {
    math::float2 v0 = b - a, v1 = c - a, v2 = p - a;
    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);
    float denom = d00 * d11 - d01 * d01;
    float v = (d11 * d20 - d01 * d21) / denom;
    float w = (d00 * d21 - d01 * d20) / denom;
    float u = 1.0f - v - w;
    return math::float3(u, v, w);
}

} // namespace thermion_filament