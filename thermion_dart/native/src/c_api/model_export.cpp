#include "Log.hpp"
#include "c_api/model_export.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>

#ifdef THERMION_ASSIMP
#include <assimp/Exporter.hpp>
#include <assimp/material.h>
#include <assimp/mesh.h>
#include <assimp/scene.h>
#endif

namespace thermion
{
    extern "C"
    {

        // Always compiled (not guarded by THERMION_ASSIMP) so the Dart layer can
        // query at runtime whether model export is available in this build.
        EMSCRIPTEN_KEEPALIVE bool ModelExporter_isSupported()
        {
#ifdef THERMION_ASSIMP
            return true;
#else
            return false;
#endif
        }

#ifdef THERMION_ASSIMP

        // ---------------------------------------------------------------------------
        // Scene construction. The input is the flat TMeshData array the importer
        // produces; the output is a hand-built aiScene with one mesh + one node +
        // one material per entry (FBX requires a material per mesh). Every
        // allocation below is matched in freeScene.
        //
        // NOTE: the libassimp in the Filament artifacts is compiled against
        // libstdc++, while this library is compiled against libc++. The two
        // mangle std::string differently, so no assimp API taking a std::string
        // may be called (e.g. aiNode(const std::string&)): use the default
        // constructors plus the inline aiString::Set(const char*) instead.
        // ---------------------------------------------------------------------------

        // Sets [target] from [value], leaving it empty for null/empty input.
        static void setAiString(aiString &target, const char *value)
        {
            if (value && value[0] != '\0')
            {
                target.Set(value);
            }
        }

        // Writes "Model<prefix><index>" into [buffer] and returns it.
        static const char *fallbackName(char *buffer, size_t bufferSize, const char *prefix, int index)
        {
            snprintf(buffer, bufferSize, "%s%d", prefix, index);
            return buffer;
        }

        static void freeScene(aiScene *scene); // defined below buildScene

        static aiMesh *buildMesh(const TMeshData &src, int meshIndex)
        {
            const unsigned vertexCount = static_cast<unsigned>(src.vertexCount / 3);
            if (vertexCount == 0 || src.vertexCount % 3 != 0)
            {
                ERROR("Mesh %d has invalid vertex count %d", meshIndex, src.vertexCount);
                return nullptr;
            }

            aiMesh *mesh = new aiMesh();
            mesh->mName.Set(src.name ? src.name : "");
            mesh->mPrimitiveTypes = aiPrimitiveType_TRIANGLE;
            mesh->mMaterialIndex = static_cast<unsigned>(meshIndex);

            mesh->mNumVertices = vertexCount;
            mesh->mVertices = new aiVector3D[vertexCount];
            for (unsigned i = 0; i < vertexCount; i++)
            {
                mesh->mVertices[i] = aiVector3D(
                    src.vertices[i * 3 + 0], src.vertices[i * 3 + 1], src.vertices[i * 3 + 2]);
            }

            if (src.normals != nullptr && src.normalCount >= src.vertexCount)
            {
                mesh->mNormals = new aiVector3D[vertexCount];
                for (unsigned i = 0; i < vertexCount; i++)
                {
                    mesh->mNormals[i] = aiVector3D(
                        src.normals[i * 3 + 0], src.normals[i * 3 + 1], src.normals[i * 3 + 2]);
                }
            }

            if (src.uvs != nullptr && src.uvCount >= src.vertexCount / 3 * 2)
            {
                mesh->mTextureCoords[0] = new aiVector3D[vertexCount];
                mesh->mNumUVComponents[0] = 2;
                for (unsigned i = 0; i < vertexCount; i++)
                {
                    mesh->mTextureCoords[0][i] = aiVector3D(src.uvs[i * 2 + 0], src.uvs[i * 2 + 1], 0.0f);
                }
            }

            // Triangle faces. A non-indexed mesh gets sequential indices.
            const bool indexed = src.indices != nullptr && src.indexCount >= 3 && src.indexCount % 3 == 0;
            const unsigned faceCount = indexed
                                           ? static_cast<unsigned>(src.indexCount / 3)
                                           : vertexCount / 3;
            if (faceCount > 0)
            {
                mesh->mNumFaces = faceCount;
                mesh->mFaces = new aiFace[faceCount];
                for (unsigned f = 0; f < faceCount; f++)
                {
                    aiFace &face = mesh->mFaces[f];
                    face.mNumIndices = 3;
                    face.mIndices = new unsigned[3];
                    if (indexed)
                    {
                        face.mIndices[0] = src.indices[f * 3 + 0];
                        face.mIndices[1] = src.indices[f * 3 + 1];
                        face.mIndices[2] = src.indices[f * 3 + 2];
                    }
                    else
                    {
                        face.mIndices[0] = f * 3 + 0;
                        face.mIndices[1] = f * 3 + 1;
                        face.mIndices[2] = f * 3 + 2;
                    }
                }
            }

            return mesh;
        }

        static aiScene *buildScene(const TMeshData *meshes, int meshCount)
        {
            auto *scene = new aiScene();
            scene->mFlags = 0;
            scene->mRootNode = new aiNode();
            scene->mRootNode->mName.Set("RootNode");

            // Zero-initialized so a failure partway through the loop leaves
            // the not-yet-filled slots null and freeScene can clean up.
            scene->mNumMeshes = static_cast<unsigned>(meshCount);
            scene->mMeshes = new aiMesh *[meshCount]();
            scene->mNumMaterials = static_cast<unsigned>(meshCount);
            scene->mMaterials = new aiMaterial *[meshCount]();
            scene->mRootNode->mNumChildren = static_cast<unsigned>(meshCount);
            scene->mRootNode->mChildren = new aiNode *[meshCount]();

            // Exception barrier: buildScene must not let an exception
            // escape (see the note in model_import.cpp); a throw partway
            // through the loop still frees everything built so far.
            try
            {
                for (int i = 0; i < meshCount; i++)
                {
                    const TMeshData &src = meshes[i];
                    if (src.primitiveType != PRIMITIVETYPE_TRIANGLES)
                    {
                        ERROR("Mesh %d is not a triangle list (type %d); export supports triangles only",
                              i, static_cast<int>(src.primitiveType));
                        freeScene(scene);
                        return nullptr;
                    }
                    if (src.vertices == nullptr)
                    {
                        ERROR("Mesh %d has no positions", i);
                        freeScene(scene);
                        return nullptr;
                    }

                    aiMesh *mesh = buildMesh(src, i);
                    if (!mesh)
                    {
                        freeScene(scene);
                        return nullptr;
                    }
                    scene->mMeshes[i] = mesh;

                    // One material per mesh (FBX requirement). The name is all we keep
                    // from the source material; assimp fills the rest with defaults.
                    auto *material = new aiMaterial();
                    char materialFallback[32];
                    aiString materialName;
                    setAiString(materialName, src.materialName);
                    if (materialName.length == 0)
                    {
                        materialName.Set(fallbackName(materialFallback, sizeof(materialFallback), "Material", i));
                    }
                    material->AddProperty(&materialName, AI_MATKEY_NAME);
                    scene->mMaterials[i] = material;

                    // One identity-transform node per mesh, named after the mesh so
                    // the name survives the round trip.
                    char nodeFallback[32];
                    aiString nodeName;
                    setAiString(nodeName, src.name);
                    if (nodeName.length == 0)
                    {
                        nodeName.Set(fallbackName(nodeFallback, sizeof(nodeFallback), "Mesh", i));
                    }
                    auto *node = new aiNode();
                    node->mName = nodeName;
                    node->mNumMeshes = 1;
                    node->mMeshes = new unsigned[1];
                    node->mMeshes[0] = static_cast<unsigned>(i);
                    node->mParent = scene->mRootNode;
                    scene->mRootNode->mChildren[i] = node;
                }

                return scene;
            }
            catch (const std::exception &e)
            {
                ERROR("Building export scene threw: %s", e.what());
                freeScene(scene);
                return nullptr;
            }
            catch (...)
            {
                ERROR("Building export scene threw an unknown exception");
                freeScene(scene);
                return nullptr;
            }
        }

        // The destructors of aiNode/aiMesh/aiScene/aiFace (some out-of-line in
        // libassimp, some inline in the headers) all delete the members they
        // own. freeScene therefore frees each buffer itself AND nulls it
        // before the enclosing `delete`, so no destructor frees it a second
        // time. Child nodes are freed recursively first (their members are
        // nulled the same way).
        static void freeNode(aiNode *node)
        {
            if (!node)
                return;
            for (unsigned i = 0; i < node->mNumChildren; i++)
            {
                freeNode(node->mChildren[i]);
            }
            node->mNumChildren = 0;
            delete[] node->mChildren;
            node->mChildren = nullptr;
            node->mNumMeshes = 0;
            delete[] node->mMeshes;
            node->mMeshes = nullptr;
            delete node;
        }

        static void freeScene(aiScene *scene)
        {
            if (!scene)
                return;
            if (scene->mMeshes)
            {
                for (unsigned i = 0; i < scene->mNumMeshes; i++)
                {
                    aiMesh *mesh = scene->mMeshes[i];
                    if (!mesh)
                        continue;
                    delete[] mesh->mVertices;
                    mesh->mVertices = nullptr;
                    mesh->mNumVertices = 0;
                    delete[] mesh->mNormals;
                    mesh->mNormals = nullptr;
                    for (unsigned c = 0; c < AI_MAX_NUMBER_OF_TEXTURECOORDS; c++)
                    {
                        delete[] mesh->mTextureCoords[c];
                        mesh->mTextureCoords[c] = nullptr;
                    }
                    if (mesh->mFaces)
                    {
                        for (unsigned f = 0; f < mesh->mNumFaces; f++)
                        {
                            delete[] mesh->mFaces[f].mIndices;
                            mesh->mFaces[f].mIndices = nullptr;
                            mesh->mFaces[f].mNumIndices = 0;
                        }
                    }
                    mesh->mNumFaces = 0;
                    delete[] mesh->mFaces;
                    mesh->mFaces = nullptr;
                    delete mesh;
                }
                delete[] scene->mMeshes;
                scene->mMeshes = nullptr;
            }
            scene->mNumMeshes = 0;
            if (scene->mMaterials)
            {
                for (unsigned i = 0; i < scene->mNumMaterials; i++)
                {
                    delete scene->mMaterials[i];
                }
                delete[] scene->mMaterials;
                scene->mMaterials = nullptr;
            }
            scene->mNumMaterials = 0;
            freeNode(scene->mRootNode);
            scene->mRootNode = nullptr;
            delete scene;
        }

        EMSCRIPTEN_KEEPALIVE uint8_t *ModelExporter_exportToBuffer(
            const TMeshData *meshes, int meshCount, const char *formatId,
            int64_t *outSize)
        {
            if (outSize)
                *outSize = 0;
            if (!meshes || meshCount <= 0 || !outSize)
            {
                ERROR("ModelExporter_exportToBuffer: invalid arguments");
                return nullptr;
            }

            const char *format = (formatId && formatId[0] != '\0') ? formatId : "fbx";

            aiScene *scene = nullptr;
            try
            {
                scene = buildScene(meshes, meshCount);
                if (!scene)
                {
                    return nullptr;
                }

                uint8_t *result = nullptr;
                {
                    Assimp::Exporter exporter;
                    const aiExportDataBlob *blob = exporter.ExportToBlob(scene, format, 0u, nullptr);
                    if (!blob || !blob->data || blob->size == 0)
                    {
                        ERROR("Model export failed (%s): %s", format, exporter.GetErrorString());
                    }
                    else
                    {
                        // FBX is a single-file format: the first blob is the model
                        // file itself, any chained entries are auxiliary files the
                        // exporter asked to write alongside it (assimp's blob
                        // exporter names its scratch file "$blobfile"). There is
                        // nothing to store them in (we return one buffer), so drop
                        // them — the main file is complete on its own. TRACE only:
                        // this happens on every export and loses nothing (this API
                        // never writes textures or other companions).
                        for (const aiExportDataBlob *extra = blob->next; extra; extra = extra->next)
                        {
                            TRACE("Model export (%s): dropping auxiliary file \"%s\" (%zu bytes)",
                                  format, extra->name.C_Str(), extra->size);
                        }
                        result = static_cast<uint8_t *>(malloc(blob->size));
                        if (result)
                        {
                            memcpy(result, blob->data, blob->size);
                            *outSize = static_cast<int64_t>(blob->size);
                        }
                        else
                        {
                            ERROR("Model export: out of memory for %zu bytes", blob->size);
                        }
                    }
                    // The Exporter owns the blob and frees it when it goes out of
                    // scope (or on the next Export call).
                }

                freeScene(scene);
                return result;
            }
            catch (const std::exception &e)
            {
                ERROR("Model export threw: %s", e.what());
                freeScene(scene);
                return nullptr;
            }
            catch (...)
            {
                ERROR("Model export threw an unknown exception");
                freeScene(scene);
                return nullptr;
            }
        }

        EMSCRIPTEN_KEEPALIVE void ModelExporter_disposeBuffer(uint8_t *data)
        {
            free(data);
        }
#endif // THERMION_ASSIMP

    } // extern "C"
} // namespace thermion
