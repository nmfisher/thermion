#include "c_api/TGltfParser.h"
#include "Log.hpp"

// Don't define CGLTF_IMPLEMENTATION - cgltf is already compiled in filament libs
#include "cgltf.h"

#include <vector>
#include <string>
#include <cstring>
#include <cstdlib>

        // Helper to convert cgltf_primitive_type to TPrimitiveType
        static TPrimitiveType convertPrimitiveType(cgltf_primitive_type type)
        {
            Log("Converting cgltf primitive type %d", static_cast<int>(type));
            switch (type)
            {
            case cgltf_primitive_type_points:
                return PRIMITIVETYPE_POINTS;
            case cgltf_primitive_type_lines:
                return PRIMITIVETYPE_LINES;
            case cgltf_primitive_type_line_strip:
                return PRIMITIVETYPE_LINE_STRIP;
            case cgltf_primitive_type_triangles:
                return PRIMITIVETYPE_TRIANGLES;
            case cgltf_primitive_type_triangle_strip:
                return PRIMITIVETYPE_TRIANGLE_STRIP;
            case cgltf_primitive_type_line_loop:
                Log("Warning: line_loop primitive type not supported, defaulting to triangles");
                return PRIMITIVETYPE_TRIANGLES;
            case cgltf_primitive_type_triangle_fan:
                Log("Warning: triangle_fan primitive type not supported, defaulting to triangles");
                return PRIMITIVETYPE_TRIANGLES;
            case cgltf_primitive_type_invalid:
            default:
                Log("Warning: invalid primitive type, defaulting to triangles");
                return PRIMITIVETYPE_TRIANGLES;
            }
        }

        // Helper to extract vertex data from accessor
        static std::vector<float> extractVertexData(const cgltf_accessor *accessor)
        {
            std::vector<float> vertices;
            if (!accessor)
            {
                return vertices;
            }
            if (!accessor->buffer_view)
            {
                return vertices;
            }
            if (!accessor->buffer_view->buffer)
            {
                return vertices;
            }
            if (!accessor->buffer_view->buffer->data)
            {
                return vertices;
            }

            cgltf_size numFloats = cgltf_accessor_unpack_floats(accessor, nullptr, 0);
            vertices.resize(numFloats);
            cgltf_accessor_unpack_floats(accessor, vertices.data(), numFloats);

            return vertices;
        }

        // Helper to extract index data from accessor
        static std::vector<uint32_t> extractIndexData(const cgltf_accessor *accessor)
        {
            std::vector<uint32_t> indices;
            if (!accessor)
            {
                return indices;
            }
            if (!accessor->buffer_view)
            {
                return indices;
            }
            if (!accessor->buffer_view->buffer)
            {
                return indices;
            }
            if (!accessor->buffer_view->buffer->data)
            {
                return indices;
            }

            indices.reserve(accessor->count);
            for (cgltf_size i = 0; i < accessor->count; i++)
            {
                indices.push_back(static_cast<uint32_t>(cgltf_accessor_read_index(accessor, i)));
            }

            return indices;
        }

        // Helper to expand triangle strip indices to triangle list indices
        static std::vector<uint32_t> expandTriangleStrip(const std::vector<uint32_t>& stripIndices, uint32_t indexOffset)
        {
            std::vector<uint32_t> triangleIndices;
            if (stripIndices.size() < 3)
            {
                return triangleIndices;
            }

            // Number of triangles in a strip = numIndices - 2
            size_t numTriangles = stripIndices.size() - 2;
            triangleIndices.reserve(numTriangles * 3);

            for (size_t i = 0; i < numTriangles; i++)
            {
                uint32_t i0 = stripIndices[i] + indexOffset;
                uint32_t i1 = stripIndices[i + 1] + indexOffset;
                uint32_t i2 = stripIndices[i + 2] + indexOffset;

                // OpenGL/glTF triangle strip winding convention:
                // - Even triangles: v[i], v[i+1], v[i+2]
                // - Odd triangles:  v[i+1], v[i], v[i+2]
                // This maintains consistent CCW front-face winding.
                if (i % 2 == 0)
                {
                    triangleIndices.push_back(i0);
                    triangleIndices.push_back(i1);
                    triangleIndices.push_back(i2);
                }
                else
                {
                    // Odd triangles: swap first two vertices
                    triangleIndices.push_back(i1);
                    triangleIndices.push_back(i0);
                    triangleIndices.push_back(i2);
                }
            }

            return triangleIndices;
        }

        // Helper to expand triangle fan indices to triangle list indices
        static std::vector<uint32_t> expandTriangleFan(const std::vector<uint32_t>& fanIndices, uint32_t indexOffset)
        {
            std::vector<uint32_t> triangleIndices;
            if (fanIndices.size() < 3)
            {
                return triangleIndices;
            }

            // Number of triangles in a fan = numIndices - 2
            size_t numTriangles = fanIndices.size() - 2;
            triangleIndices.reserve(numTriangles * 3);

            uint32_t centerVertex = fanIndices[0] + indexOffset;
            for (size_t i = 0; i < numTriangles; i++)
            {
                triangleIndices.push_back(centerVertex);
                triangleIndices.push_back(fanIndices[i + 1] + indexOffset);
                triangleIndices.push_back(fanIndices[i + 2] + indexOffset);
            }

            return triangleIndices;
        }

extern "C" {

    // TMeshData buffers and strings are malloced by GltfParser_parseBuffer,
    // so free() is the matching deallocator for everything here.
    EMSCRIPTEN_KEEPALIVE void MeshData_dispose(TMeshData* meshData)
    {
        if (!meshData)
        {
            return;
        }

        free(meshData->name);
        free(meshData->materialName);
        free(meshData->vertices);
        free(meshData->normals);
        free(meshData->uvs);
        free(meshData->indices);

        memset(meshData, 0, sizeof(TMeshData));
    }

    EMSCRIPTEN_KEEPALIVE int GltfParser_parseBuffer(
        const uint8_t *data,
        size_t length,
        const char *meshName,
        TMeshData *outMeshData)
    {
        if (!outMeshData)
        {
            Log("outMeshData is null");
            return -1;
        }

        // Initialize output
        memset(outMeshData, 0, sizeof(TMeshData));
        outMeshData->primitiveType = PRIMITIVETYPE_TRIANGLES;

        cgltf_options options = {};
        cgltf_data *gltfData = nullptr;

        Log("Parsing glTF data of size %lu", length);

        cgltf_result result = cgltf_parse(&options, data, length, &gltfData);

        if (result != cgltf_result_success)
        {
            Log("Failed to parse glTF data: %d", result);
            return -1;
        }

        Log("Successfully parsed file, loading buffers");

        // Always call cgltf_load_buffers - it handles both GLB embedded buffers
        // and external file URIs. For GLB files, it sets up the data pointers.
        // Pass NULL as the path since we're loading from memory buffer.
        result = cgltf_load_buffers(&options, gltfData, nullptr);
        if (result != cgltf_result_success)
        {
            Log("Failed to load glTF buffers: %d", result);
            cgltf_free(gltfData);
            return -1;
        }

        Log("Buffers loaded successfully");

        // Validate
        result = cgltf_validate(gltfData);
        if (result != cgltf_result_success)
        {
            Log("glTF validation failed: %d", result);
            cgltf_free(gltfData);
            return -1;
        }

        std::vector<float> allVertices;
        std::vector<uint32_t> allIndices;
        cgltf_primitive_type primitiveType = cgltf_primitive_type_triangles; // Default to triangles

        // Check if meshes array exists
        if (!gltfData->meshes)
        {
            Log("No meshes found in glTF data");
            cgltf_free(gltfData);
            return -1;
        }

        // Iterate through meshes
        for (cgltf_size meshIdx = 0; meshIdx < gltfData->meshes_count; meshIdx++)
        {
            const cgltf_mesh *mesh = &gltfData->meshes[meshIdx];

            // Filter by name if specified
            if (meshName && mesh->name && strcmp(mesh->name, meshName) != 0)
            {
                continue;
            }

            // Check if primitives array exists
            if (!mesh->primitives)
            {
                Log("Mesh has no primitives array");
                continue;
            }

            Log("Mesh has %zu primitives", mesh->primitives_count);

            // Process each primitive in the mesh
            for (cgltf_size primIdx = 0; primIdx < mesh->primitives_count; primIdx++)
            {
                const cgltf_primitive *primitive = &mesh->primitives[primIdx];
                primitiveType = primitive->type;

                Log("primitive type at primitive index %zu is %d", primIdx, static_cast<int>(primitiveType));

                uint32_t indexOffset = allVertices.size() / 3;

                // Extract position data
                if (primitive->attributes)
                {
                    for (cgltf_size attrIdx = 0; attrIdx < primitive->attributes_count; attrIdx++)
                    {
                        const cgltf_attribute *attr = &primitive->attributes[attrIdx];
                        if (attr->type == cgltf_attribute_type_position)
                        {
                            auto vertices = extractVertexData(attr->data);
                            allVertices.insert(allVertices.end(), vertices.begin(), vertices.end());
                            break;
                        }
                    }

                    // Extract indices and expand strips/fans to triangle lists
                    if (primitive->indices)
                    {
                        auto indices = extractIndexData(primitive->indices);

                        if (primitiveType == cgltf_primitive_type_triangle_strip)
                        {
                            Log("Expanding triangle strip (%zu indices) to triangle list", indices.size());
                            auto expandedIndices = expandTriangleStrip(indices, indexOffset);
                            allIndices.insert(allIndices.end(), expandedIndices.begin(), expandedIndices.end());
                            // Override primitive type to triangles since we expanded
                            primitiveType = cgltf_primitive_type_triangles;
                        }
                        else if (primitiveType == cgltf_primitive_type_triangle_fan)
                        {
                            Log("Expanding triangle fan (%zu indices) to triangle list", indices.size());
                            auto expandedIndices = expandTriangleFan(indices, indexOffset);
                            allIndices.insert(allIndices.end(), expandedIndices.begin(), expandedIndices.end());
                            // Override primitive type to triangles since we expanded
                            primitiveType = cgltf_primitive_type_triangles;
                        }
                        else
                        {
                            // Regular triangle list - just offset indices
                            for (auto idx : indices)
                            {
                                allIndices.push_back(idx + indexOffset);
                            }
                        }
                    }
                }
            }

            // Copy the mesh name before cgltf_free: [mesh] points into
            // [gltfData], which is released below.
            if (mesh->name && mesh->name[0] != '\0')
            {
                size_t nameLen = strlen(mesh->name) + 1;
                outMeshData->name = static_cast<char *>(malloc(nameLen));
                if (outMeshData->name)
                {
                    memcpy(outMeshData->name, mesh->name, nameLen);
                }
            }

            cgltf_free(gltfData);

            if (allVertices.empty())
            {
                Log("No vertex data found in glTF");
                return -1;
            }

            outMeshData->vertexCount = static_cast<int>(allVertices.size());
            outMeshData->vertices = static_cast<float *>(malloc(allVertices.size() * sizeof(float)));
            if (!outMeshData->vertices)
            {
                return -1;
            }
            memcpy(outMeshData->vertices, allVertices.data(), allVertices.size() * sizeof(float));

            outMeshData->indexCount = static_cast<int>(allIndices.size());
            if (!allIndices.empty())
            {
                outMeshData->indices = static_cast<uint32_t *>(malloc(allIndices.size() * sizeof(uint32_t)));
                if (!outMeshData->indices)
                {
                    MeshData_dispose(outMeshData);
                    return -1;
                }
                memcpy(outMeshData->indices, allIndices.data(), allIndices.size() * sizeof(uint32_t));
            }
            else
            {
                outMeshData->indices = nullptr;
            }

            TPrimitiveType finalType = convertPrimitiveType(primitiveType);
            Log("Final converted primitive type: %d", static_cast<int>(finalType));
            outMeshData->primitiveType = finalType;

            return 0; // Success
        }
        return -1; // No matching mesh found
    }
}

