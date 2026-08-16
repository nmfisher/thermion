#include "Log.hpp"
#include "c_api/model_import.h"

#include <cstdlib>
#include <cstring>
#include <exception>
#include <vector>

#ifdef THERMION_ASSIMP
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>
#include <assimp/DefaultLogger.hpp>
#include <assimp/matrix4x4.h>
#include <assimp/matrix3x3.h>
#include <assimp/vector3.h>
#endif

namespace thermion
{

    extern "C"
    {

        // Always compiled (not guarded by THERMION_ASSIMP) so the Dart layer can
        // query at runtime whether model loading is available in this build.
        EMSCRIPTEN_KEEPALIVE bool ModelImporter_isSupported()
        {
#ifdef THERMION_ASSIMP
            return true;
#else
            return false;
#endif
        }

#ifdef THERMION_ASSIMP

        // ---------------------------------------------------------------------------
        // Exception barriers.
        //
        // Assimp parses with C++ exceptions (DeadlyImportError and, for some
        // formats, plain std:: exceptions) and ReadFile does not guarantee to
        // swallow all of them. This library is a C API consumed through Dart
        // FFI: an exception unwinding out of one of the entry points below
        // crosses frames the unwinder cannot describe, which crashes the
        // process (observed on CI as a SEGV inside libc++abi's exception
        // machinery). Every entry point therefore catches everything and
        // converts the failure to a normal error return.
        //
        // Note the thrower is compiled against libstdc++ (the artifact
        // libassimp) while this code is compiled against libc++, so the
        // catch handlers must not assume a shared std::exception layout —
        // catch(...) does the real work; the typed catches only log what().
        // ---------------------------------------------------------------------------

    // Internal structure to hold Assimp scene data
    struct ModelImporterData {
        const aiScene* scene;
        Assimp::Importer* importer;

        ModelImporterData(const aiScene* s, Assimp::Importer* imp)
            : scene(s), importer(imp) {}
    };

        // ---------------------------------------------------------------------------
        // Scene-node transform helpers.
        //
        // Assimp keeps each mesh in its node's local space. A mesh referenced by a
        // node with a non-identity transform chain (typical for FBX/ Collada
        // scenes) must be transformed by the accumulated node transform to land in
        // world space. Files with an identity root transform (OBJ/STL/PLY) are
        // unaffected.
        //
        // Assimp matrices use the row-vector convention: a point transforms as
        // p' = p * M (see the explicit component math below), and a child's global
        // matrix is mTransformation * parentGlobal.
        // ---------------------------------------------------------------------------

        // p' = p * M (row-vector multiply; assimp's column-major a/b/c/d layout).
        static inline aiVector3D transformPoint(const aiMatrix4x4 &m, const aiVector3D &v)
        {
            return aiVector3D(
                v.x * m.a1 + v.y * m.b1 + v.z * m.c1 + m.d1,
                v.x * m.a2 + v.y * m.b2 + v.z * m.c2 + m.d2,
                v.x * m.a3 + v.y * m.b3 + v.z * m.c3 + m.d3);
        }

        // n' = n * (M3^T)^-1 — the normal matrix for the row-vector convention —
        // then renormalised (non-uniform scale would otherwise skew normals).
        static inline aiVector3D transformNormal(const aiMatrix3x3 &normalMatrix, const aiVector3D &n)
        {
            aiVector3D r(
                n.x * normalMatrix.a1 + n.y * normalMatrix.b1 + n.z * normalMatrix.c1,
                n.x * normalMatrix.a2 + n.y * normalMatrix.b2 + n.z * normalMatrix.c2,
                n.x * normalMatrix.a3 + n.y * normalMatrix.b3 + n.z * normalMatrix.c3);
            r.NormalizeSafe();
            return r;
        }

        // Walk the node graph recording each mesh's first accumulated (global)
        // transform. Meshes not referenced by any node (or referenced by several,
        // i.e. instancing) keep the identity / first occurrence respectively.
        static void collectGlobalTransforms(const aiNode *node, const aiMatrix4x4 &parentGlobal,
                                            std::vector<aiMatrix4x4> &meshTransforms,
                                            std::vector<bool> &assigned)
        {
            if (!node)
                return;

            const aiMatrix4x4 global = node->mTransformation * parentGlobal;

            // The mMeshes/mChildren null guards are cheap insurance against a
            // malformed scene: assimp does not guarantee the arrays are
            // non-null when the counts are > 0 for every importer.
            for (unsigned int i = 0; node->mMeshes && i < node->mNumMeshes; i++)
            {
                unsigned int meshIndex = node->mMeshes[i];
                if (meshIndex < meshTransforms.size() && !assigned[meshIndex])
                {
                    meshTransforms[meshIndex] = global;
                    assigned[meshIndex] = true;
                }
            }

            for (unsigned int i = 0; node->mChildren && i < node->mNumChildren; i++)
            {
                collectGlobalTransforms(node->mChildren[i], global, meshTransforms, assigned);
            }
        }

        static char *duplicateString(const char *source)
        {
            if (!source || source[0] == '\0')
            {
                return nullptr;
            }
            size_t len = strlen(source) + 1;
            char *copy = static_cast<char *>(malloc(len));
            if (copy)
            {
                memcpy(copy, source, len);
            }
            return copy;
        }

        EMSCRIPTEN_KEEPALIVE TModelImporter* ModelImporter_loadFromBuffer(const uint8_t* data, size_t size,
                                                                     const char* extensionHint)
        {
            auto* importer = new Assimp::Importer();

            // Set up Assimp logger (optional, for debugging)
            Assimp::DefaultLogger::create("", Assimp::Logger::VERBOSE);

            try
            {
                // Read file from memory with these flags:
                // - Triangulate: Convert polygons to triangles
                // - JoinIdenticalVertices: Merge duplicate vertices
                // - SortByPType: Separate meshes by primitive type
                // - GenerateNormals: Create normals if not present
                // - CalculateTangentSpace: Calculate tangents for normal mapping
                //
                // NOTE: aiProcess_FlipUVs is intentionally NOT applied here. UV flipping is
                // handled on the Dart side (GeometryUtils / RawMesh.toGeometry) via the
                // parameterised `flipUvs` flag, so applying it in Assimp too would double-flip.
                unsigned int flags =
                    aiProcess_Triangulate |
                    aiProcess_JoinIdenticalVertices |
                    aiProcess_SortByPType |
                    aiProcess_GenNormals |
                    aiProcess_CalcTangentSpace;

                // Assimp's ReadFileFromMemory uses the hint extension (no dot) to pick the
                // importer. Default to "obj" when none is supplied.
                const char* hint = (extensionHint && extensionHint[0] != '\0') ? extensionHint : "obj";

                const aiScene* scene = importer->ReadFileFromMemory(
                    data, size, flags, hint);

                if (!scene || !scene->mRootNode) {
                    ERROR("Failed to load model file: %s", importer->GetErrorString());
                    delete importer;
                    Assimp::DefaultLogger::kill();
                    return nullptr;
                }

                if (scene->mFlags & AI_SCENE_FLAGS_INCOMPLETE) {
                    ERROR("Scene is incomplete");
                    delete importer;
                    Assimp::DefaultLogger::kill();
                    return nullptr;
                }

                if (!scene->HasMeshes()) {
                    ERROR("Scene has no meshes");
                    delete importer;
                    Assimp::DefaultLogger::kill();
                    return nullptr;
                }

                auto* importerData = new ModelImporterData(scene, importer);
                Assimp::DefaultLogger::kill();

                return reinterpret_cast<TModelImporter*>(importerData);
            }
            catch (const std::exception &e)
            {
                ERROR("Model import threw: %s", e.what());
                delete importer;
                Assimp::DefaultLogger::kill();
                return nullptr;
            }
            catch (...)
            {
                ERROR("Model import threw an unknown exception");
                delete importer;
                Assimp::DefaultLogger::kill();
                return nullptr;
            }
        }

        EMSCRIPTEN_KEEPALIVE int ModelImporter_getMeshCount(TModelImporter* importer)
        {
            if (!importer) return 0;
            auto* data = reinterpret_cast<ModelImporterData*>(importer);
            return static_cast<int>(data->scene->mNumMeshes);
        }

        EMSCRIPTEN_KEEPALIVE int ModelImporter_getMesh(TModelImporter* importer, int meshIndex,
                                                      TMeshData* outMesh)
        {
            if (!importer || !outMesh) return -1;

            memset(outMesh, 0, sizeof(TMeshData));

            auto* data = reinterpret_cast<ModelImporterData*>(importer);

            try
            {
                if (!data->scene->mMeshes || meshIndex < 0 || meshIndex >= static_cast<int>(data->scene->mNumMeshes)) {
                    ERROR("Invalid mesh index: %d", meshIndex);
                    return -2;
                }

                const aiMesh* mesh = data->scene->mMeshes[meshIndex];
                if (!mesh || !mesh->HasPositions()) {
                    ERROR("Mesh %d has no positions", meshIndex);
                    return -3;
                }

                // Accumulated scene-node transform for this mesh. Computed lazily per
                // getMesh call: the node walk is cheap compared to the buffer copies,
                // and the importer handle may outlive many getMesh calls.
                std::vector<aiMatrix4x4> meshTransforms(data->scene->mNumMeshes);
                std::vector<bool> assigned(data->scene->mNumMeshes, false);
                collectGlobalTransforms(data->scene->mRootNode, aiMatrix4x4(), meshTransforms, assigned);
                const aiMatrix4x4 &transform = meshTransforms[meshIndex];
                const bool identity = transform.IsIdentity();

                // Normal matrix: (upper3x3^T)^-1 in the row-vector convention. Only
                // needed for non-identity transforms with non-uniform scale; skipped
                // when the transform is rigid (rotation+uniform scale) or identity.
                aiMatrix3x3 normalMatrix;
                bool transformNormals = false;
                if (!identity && mesh->HasNormals())
                {
                    normalMatrix = aiMatrix3x3(transform);
                    normalMatrix.Transpose();
                    const float det = normalMatrix.Determinant();
                    if (det != 0.0f)
                    {
                        normalMatrix.Inverse();
                        transformNormals = true;
                    }
                    else
                    {
                        // Singular (degenerate scale) — fall back to the plain 3x3 so
                        // normals at least follow rotation/scale directions.
                        normalMatrix = aiMatrix3x3(transform);
                        transformNormals = true;
                    }
                }

                // Vertices (always transformed by the node chain unless identity).
                outMesh->vertexCount = static_cast<int>(mesh->mNumVertices) * 3;
                outMesh->vertices = static_cast<float*>(malloc(outMesh->vertexCount * sizeof(float)));
                if (!outMesh->vertices) return -4;
                for (unsigned int i = 0; i < mesh->mNumVertices; i++)
                {
                    aiVector3D v = identity ? mesh->mVertices[i]
                                            : transformPoint(transform, mesh->mVertices[i]);
                    outMesh->vertices[i * 3 + 0] = v.x;
                    outMesh->vertices[i * 3 + 1] = v.y;
                    outMesh->vertices[i * 3 + 2] = v.z;
                }

                // Normals (optional).
                if (mesh->HasNormals())
                {
                    outMesh->normalCount = static_cast<int>(mesh->mNumVertices) * 3;
                    outMesh->normals = static_cast<float*>(malloc(outMesh->normalCount * sizeof(float)));
                    if (!outMesh->normals) { MeshData_dispose(outMesh); return -4; }
                    for (unsigned int i = 0; i < mesh->mNumVertices; i++)
                    {
                        aiVector3D n = (identity || !transformNormals)
                                           ? mesh->mNormals[i]
                                           : transformNormal(normalMatrix, mesh->mNormals[i]);
                        outMesh->normals[i * 3 + 0] = n.x;
                        outMesh->normals[i * 3 + 1] = n.y;
                        outMesh->normals[i * 3 + 2] = n.z;
                    }
                }

                // First UV channel (optional).
                if (mesh->HasTextureCoords(0))
                {
                    outMesh->uvCount = static_cast<int>(mesh->mNumVertices) * 2;
                    outMesh->uvs = static_cast<float*>(malloc(outMesh->uvCount * sizeof(float)));
                    if (!outMesh->uvs) { MeshData_dispose(outMesh); return -4; }
                    for (unsigned int i = 0; i < mesh->mNumVertices; i++)
                    {
                        const aiVector3D &uv = mesh->mTextureCoords[0][i];
                        outMesh->uvs[i * 2 + 0] = uv.x;
                        outMesh->uvs[i * 2 + 1] = uv.y;
                    }
                }

                // Indices: all faces are triangles thanks to aiProcess_Triangulate
                // (guard anyway for malformed scenes).
                size_t totalIndices = 0;
                for (unsigned int f = 0; f < mesh->mNumFaces; f++)
                {
                    totalIndices += mesh->mFaces[f].mNumIndices >= 3 ? 3 : 0;
                }
                if (totalIndices > 0)
                {
                    outMesh->indexCount = static_cast<int>(totalIndices);
                    outMesh->indices = static_cast<uint32_t*>(malloc(totalIndices * sizeof(uint32_t)));
                    if (!outMesh->indices) { MeshData_dispose(outMesh); return -4; }
                    size_t out = 0;
                    for (unsigned int f = 0; f < mesh->mNumFaces; f++)
                    {
                        const aiFace &face = mesh->mFaces[f];
                        if (face.mNumIndices >= 3)
                        {
                            outMesh->indices[out++] = face.mIndices[0];
                            outMesh->indices[out++] = face.mIndices[1];
                            outMesh->indices[out++] = face.mIndices[2];
                        }
                    }
                }

                outMesh->name = duplicateString(mesh->mName.C_Str());
                if (mesh->mMaterialIndex < data->scene->mNumMaterials)
                {
                    const aiMaterial *material = data->scene->mMaterials[mesh->mMaterialIndex];
                    aiString materialName;
                    if (material && material->Get(AI_MATKEY_NAME, materialName) == aiReturn_SUCCESS)
                    {
                        outMesh->materialName = duplicateString(materialName.C_Str());
                    }
                }

                outMesh->primitiveType = PRIMITIVETYPE_TRIANGLES;

                return 0;
            }
            catch (const std::exception &e)
            {
                ERROR("Reading mesh %d threw: %s", meshIndex, e.what());
                MeshData_dispose(outMesh); // release partial buffers (zeros the struct)
                return -5;
            }
            catch (...)
            {
                ERROR("Reading mesh %d threw an unknown exception", meshIndex);
                MeshData_dispose(outMesh);
                return -5;
            }
        }

        EMSCRIPTEN_KEEPALIVE void ModelImporter_destroy(TModelImporter* importer)
        {
            if (!importer) return;
            auto* data = reinterpret_cast<ModelImporterData*>(importer);
            delete data->importer;
            delete data;
        }
#endif // THERMION_ASSIMP

    } // extern "C"
} // namespace thermion
