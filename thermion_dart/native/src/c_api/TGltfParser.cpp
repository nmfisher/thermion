#include "c_api/TGltfParser.h"
#include "Log.hpp"

// Don't define CGLTF_IMPLEMENTATION - cgltf is already compiled in filament libs
#include "cgltf.h"

#include <vector>
#include <string>
#include <cstring>

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif

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

        EMSCRIPTEN_KEEPALIVE int GltfParser_parseBuffer(
            const uint8_t *data,
            size_t length,
            const char *meshName,
            TGltfMeshData *outMeshData)
        {
            if (!outMeshData)
            {
                Log("outMeshData is null");
                return -1;
            }

            // Initialize output
            outMeshData->vertices = nullptr;
            outMeshData->vertexCount = 0;
            outMeshData->indices = nullptr;
            outMeshData->indexCount = 0;
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

                        // Extract indices
                        if (primitive->indices)
                        {
                            auto indices = extractIndexData(primitive->indices);
                            // Offset indices by current vertex count
                            for (auto idx : indices)
                            {
                                allIndices.push_back(idx + indexOffset);
                            }
                        }
                    }
                }

                cgltf_free(gltfData);


                if (allVertices.empty())
                {
                    Log("No vertex data found in glTF");
                    return -1;
                }

                outMeshData->vertexCount = allVertices.size();
                outMeshData->vertices = new float[allVertices.size()];
                memcpy(outMeshData->vertices, allVertices.data(), allVertices.size() * sizeof(float));

                outMeshData->indexCount = allIndices.size();
                if (!allIndices.empty())
                {
                    outMeshData->indices = new uint32_t[allIndices.size()];
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

        EMSCRIPTEN_KEEPALIVE void GltfParser_freeMeshData(TGltfMeshData *meshData)
        {
            if (!meshData)
                return;

            delete[] meshData->vertices;
            delete[] meshData->indices;

            meshData->vertices = nullptr;
            meshData->indices = nullptr;
            meshData->vertexCount = 0;
            meshData->indexCount = 0;
        }

#ifdef __cplusplus
    }
}
#endif
