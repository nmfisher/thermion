// #include <filament/Engine.h>
// #include <filament/Camera.h>
// #include <filament/Texture.h>
// #include <filament/VertexBuffer.h>
// #include <filament/IndexBuffer.h>
// #include <filament/RenderableManager.h>
// #include <filament/TransformManager.h>
// #include <math/mat4.h>
// #include <math/vec2.h>
// #include <math/vec3.h>
// #include <math/vec4.h>
// #include <utils/EntityManager.h>
// #include <backend/PixelBufferDescriptor.h>
// #include "Log.hpp"
// #include <vector>
// #include <algorithm>
// #include <iostream>
// #include "scene/CustomGeometry.hpp"
// #include "TextureProjection.hpp"

// namespace thermion
// {

//     bool TextureProjection::isInsideTriangle(const math::float2 &p, const math::float2 &a, const math::float2 &b, const math::float2 &c)
//     {
//         float d1 = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y);
//         float d2 = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y);
//         float d3 = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y);
//         return (d1 >= 0 && d2 >= 0 && d3 >= 0) || (d1 <= 0 && d2 <= 0 && d3 <= 0);
//     }

//     math::float3 TextureProjection::barycentric(const math::float2 &p, const math::float2 &a, const math::float2 &b, const math::float2 &c)
//     {
//         math::float2 v0 = b - a;
//         math::float2 v1 = c - a;
//         math::float2 v2 = p - a;

//         float d00 = dot(v0, v0);
//         float d01 = dot(v0, v1);
//         float d11 = dot(v1, v1);
//         float d20 = dot(v2, v0);
//         float d21 = dot(v2, v1);

//         float denom = d00 * d11 - d01 * d01;

//         float v = (d11 * d20 - d01 * d21) / denom;
//         float w = (d00 * d21 - d01 * d20) / denom;
//         float u = 1.0f - v - w;

//         return math::float3(u, v, w);
//     }

//     void TextureProjection::project(utils::Entity entity, const uint8_t *inputTexture, uint8_t *outputTexture,
//                                      uint32_t inputWidth, uint32_t inputHeight,
//                                      uint32_t outputWidth, uint32_t outputHeight)
//     {

//         // auto &rm = _engine->getRenderableManager();

//         // auto &tm = _engine->getTransformManager();

//         // math::mat4 invViewProj = Camera::inverseProjection(_camera.getProjectionMatrix()) * _camera.getModelMatrix();

//         // auto ti = tm.getInstance(entity);
//         // math::mat4f worldTransform = tm.getWorldTransform(ti);
//         // auto inverseWorldTransform = inverse(worldTransform);

//         // const float *vertices = _geometry->vertices;
//         // const float *uvs = _geometry->uvs;
//         // const uint16_t *indices = _geometry->indices;
//         // uint32_t numIndices = _geometry->numIndices;

//         // // Create a depth buffer
//         // std::vector<float> depthBuffer(inputWidth * inputHeight, std::numeric_limits<float>::infinity());

//         // // Create a buffer to store the triangle index for each pixel
//         // std::vector<int> triangleIndexBuffer(inputWidth * inputHeight, -1);

//         // auto max = 0.0f;
//         // auto min = 99.0f;

//         // // Depth pre-pass
//         // for (size_t i = 0; i < numIndices; i += 3)
//         // {
//         //     math::float3 v0(vertices[indices[i] * 3], vertices[indices[i] * 3 + 1], vertices[indices[i] * 3 + 2]);
//         //     math::float3 v1(vertices[indices[i + 1] * 3], vertices[indices[i + 1] * 3 + 1], vertices[indices[i + 1] * 3 + 2]);
//         //     math::float3 v2(vertices[indices[i + 2] * 3], vertices[indices[i + 2] * 3 + 1], vertices[indices[i + 2] * 3 + 2]);

//         //     math::float2 uv0(uvs[(indices[i] * 2)], uvs[(indices[i] * 2) + 1]);
//         //     math::float2 uv1(uvs[(indices[i + 1] * 2)], uvs[(indices[i + 1] * 2) + 1]);
//         //     math::float2 uv2(uvs[(indices[i + 2] * 2)], uvs[(indices[i + 2] * 2) + 1]);

//         //     // Transform vertices to world space
//         //     v0 = (worldTransform * math::float4(v0, 1.0f)).xyz;
//         //     v1 = (worldTransform * math::float4(v1, 1.0f)).xyz;
//         //     v2 = (worldTransform * math::float4(v2, 1.0f)).xyz;

//         //     // Project vertices to screen space
//         //     math::float4 clipPos0 = _camera.getProjectionMatrix() * _camera.getViewMatrix() * math::float4(v0, 1.0f);
//         //     math::float4 clipPos1 = _camera.getProjectionMatrix() * _camera.getViewMatrix() * math::float4(v1, 1.0f);
//         //     math::float4 clipPos2 = _camera.getProjectionMatrix() * _camera.getViewMatrix() * math::float4(v2, 1.0f);

//         //     math::float3 ndcPos0 = clipPos0.xyz / clipPos0.w;
//         //     math::float3 ndcPos1 = clipPos1.xyz / clipPos1.w;
//         //     math::float3 ndcPos2 = clipPos2.xyz / clipPos2.w;

//         //     // Convert NDC to screen coordinates
//         //     math::float2 screenPos0((ndcPos0.x * 0.5f + 0.5f) * inputWidth, (1.0f - (ndcPos0.y * 0.5f + 0.5f)) * inputHeight);
//         //     math::float2 screenPos1((ndcPos1.x * 0.5f + 0.5f) * inputWidth, (1.0f - (ndcPos1.y * 0.5f + 0.5f)) * inputHeight);
//         //     math::float2 screenPos2((ndcPos2.x * 0.5f + 0.5f) * inputWidth, (1.0f - (ndcPos2.y * 0.5f + 0.5f)) * inputHeight);

//         //     // Compute bounding box of the triangle
//         //     int minX = std::max(0, static_cast<int>(std::min({screenPos0.x, screenPos1.x, screenPos2.x})));
//         //     int maxX = std::min(static_cast<int>(inputWidth) - 1, static_cast<int>(std::max({screenPos0.x, screenPos1.x, screenPos2.x})));
//         //     int minY = std::max(0, static_cast<int>(std::min({screenPos0.y, screenPos1.y, screenPos2.y})));
//         //     int maxY = std::min(static_cast<int>(inputHeight) - 1, static_cast<int>(std::max({screenPos0.y, screenPos1.y, screenPos2.y})));

//         //     // Iterate over the bounding box
//         //     for (int y = minY; y <= maxY; ++y)
//         //     {
//         //         for (int x = minX; x <= maxX; ++x)
//         //         {
//         //             math::float2 pixelPos(x + 0.5f, y + 0.5f);

//         //             if (isInsideTriangle(pixelPos, screenPos0, screenPos1, screenPos2))
//         //             {
//         //                 math::float3 bary = barycentric(pixelPos, screenPos0, screenPos1, screenPos2);

//         //                 // Interpolate depth
//         //                 float depth = bary.x * ndcPos0.z + bary.y * ndcPos1.z + bary.z * ndcPos2.z;

//         //                 // Depth test
//         //                 if (depth < depthBuffer[y * inputWidth + x])
//         //                 {

//         //                     if (depth > max)
//         //                     {
//         //                         max = depth;
//         //                     }
//         //                     if (depth < min)
//         //                     {
//         //                         min = depth;
//         //                     }
//         //                     depthBuffer[y * inputWidth + x] = depth;
//         //                     triangleIndexBuffer[y * inputWidth + x] = i / 3; // Store triangle index
//         //                 }
//         //             }
//         //         }
//         //     }
//         // }

//         // for (uint32_t y = 0; y < outputHeight; ++y)
//         // {
//         //     for (uint32_t x = 0; x < outputWidth; ++x)
//         //     {

//         //         math::float2 uv(static_cast<float>(x) / outputWidth, static_cast<float>(y) / outputHeight);

//         //         // Use the UV coordinates to get the corresponding 3D position on the renderable
//         //         math::float3 objectPos;
//         //         math::float2 interpolatedUV;
//         //         bool found = false;

//         //         // Iterate over triangles to find which one contains this UV coordinate
//         //         for (size_t i = 0; i < numIndices; i += 3)
//         //         {
//         //             math::float2 uv0 = *(math::float2 *)&uvs[indices[i] * 2];
//         //             math::float2 uv1 = *(math::float2 *)&uvs[indices[i + 1] * 2];
//         //             math::float2 uv2 = *(math::float2 *)&uvs[indices[i + 2] * 2];

//         //             if (isInsideTriangle(uv, uv0, uv1, uv2))
//         //             {
//         //                 // Compute barycentric coordinates in UV space
//         //                 math::float3 bary = barycentric(uv, uv0, uv1, uv2);

//         //                 // Interpolate 3D position
//         //                 math::float3 v0(vertices[indices[i] * 3], vertices[indices[i] * 3 + 1], vertices[indices[i] * 3 + 2]);
//         //                 math::float3 v1(vertices[indices[i + 1] * 3], vertices[indices[i + 1] * 3 + 1], vertices[indices[i + 1] * 3 + 2]);
//         //                 math::float3 v2(vertices[indices[i + 2] * 3], vertices[indices[i + 2] * 3 + 1], vertices[indices[i + 2] * 3 + 2]);

//         //                 objectPos = v0 * bary.x + v1 * bary.y + v2 * bary.z;
//         //                 interpolatedUV = uv;

//         //                 // Find the screen coordinates on the input texture
//         //                 math::float3 worldPos = (worldTransform * math::float4(objectPos, 1.0f)).xyz;
//         //                 // Project the world position to screen space
//         //                 math::float4 clipPos = _camera.getProjectionMatrix() * _camera.getViewMatrix() * math::float4(worldPos, 1.0f);
//         //                 math::float3 ndcPos = clipPos.xyz / clipPos.w;
//         //                 // Convert NDC to screen coordinates
//         //                 uint32_t screenX = (ndcPos.x * 0.5f + 0.5f) * inputWidth;
//         //                 uint32_t screenY = (1.0f - (ndcPos.y * 0.5f + 0.5f)) * inputHeight;

//         //                 if (triangleIndexBuffer[(screenY * inputWidth) + screenX] == i / 3)
//         //                 {
//         //                     if (screenX >= 0 && screenX < inputWidth && screenY >= 0 && screenY < inputHeight)
//         //                     {
//         //                         int inputIndex = (screenY * inputWidth + screenX) * 4;
//         //                         int outputIndex = (y * outputWidth + x) * 4;
//         //                         std::copy_n(&inputTexture[inputIndex], 4, &outputTexture[outputIndex]);
//         //                     }
//         //                 }
//         //             }
//         //         }
//         //     }
//         // }
//     }

// } // namespace thermion

