#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>
#include <assimp/DefaultLogger.hpp>

#include "Log.hpp"
#include "c_api/obj_import.h"

namespace thermion
{

    // Internal structure to hold Assimp scene data
    struct ObjImporterData {
        const aiScene* scene;
        Assimp::Importer* importer;

        ObjImporterData(const aiScene* s, Assimp::Importer* imp)
            : scene(s), importer(imp) {}
    };

    extern "C"
    {

        EMSCRIPTEN_KEEPALIVE TObjImporter* ObjImporter_loadFromBuffer(const uint8_t* data, size_t size)
        {
            auto* importer = new Assimp::Importer();

            // Set up Assimp logger (optional, for debugging)
            Assimp::DefaultLogger::create("", Assimp::Logger::VERBOSE);

            // Read file from memory with these flags:
            // - Triangulate: Convert polygons to triangles
            // - JoinIdenticalVertices: Merge duplicate vertices
            // - SortByPType: Separate meshes by primitive type
            // - GenerateNormals: Create normals if not present
            // - CalculateTangentSpace: Calculate tangents for normal mapping
            // - FlipUVs: Flip UV coordinates if needed (Assimp default)
            unsigned int flags =
                aiProcess_Triangulate |
                aiProcess_JoinIdenticalVertices |
                aiProcess_SortByPType |
                aiProcess_GenNormals |
                aiProcess_CalcTangentSpace |
                aiProcess_FlipUVs;

            const aiScene* scene = importer->ReadFileFromMemory(
                data, size, flags, "obj");

            if (!scene || !scene->mRootNode) {
                ERROR("Failed to load OBJ file: %s", importer->GetErrorString());
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

            auto* importerData = new ObjImporterData(scene, importer);
            Assimp::DefaultLogger::kill();

            return reinterpret_cast<TObjImporter*>(importerData);
        }

        EMSCRIPTEN_KEEPALIVE int ObjImporter_getMeshCount(TObjImporter* importer)
        {
            if (!importer) return 0;
            auto* data = reinterpret_cast<ObjImporterData*>(importer);
            return static_cast<int>(data->scene->mNumMeshes);
        }

        EMSCRIPTEN_KEEPALIVE void ObjImporter_getVertices(TObjImporter* importer, int meshIndex,
                                                           float** outVertices, int* outCount)
        {
            *outVertices = nullptr;
            *outCount = 0;

            if (!importer) return;
            auto* data = reinterpret_cast<ObjImporterData*>(importer);

            if (meshIndex < 0 || meshIndex >= static_cast<int>(data->scene->mNumMeshes)) {
                ERROR("Invalid mesh index: %d", meshIndex);
                return;
            }

            const aiMesh* mesh = data->scene->mMeshes[meshIndex];
            if (!mesh->HasPositions()) {
                ERROR("Mesh %d has no vertices", meshIndex);
                return;
            }

            // Allocate and copy vertex data
            *outCount = static_cast<int>(mesh->mNumVertices * 3);
            *outVertices = static_cast<float*>(malloc(*outCount * sizeof(float)));

            for (unsigned int i = 0; i < mesh->mNumVertices; i++) {
                (*outVertices)[i * 3 + 0] = mesh->mVertices[i].x;
                (*outVertices)[i * 3 + 1] = mesh->mVertices[i].y;
                (*outVertices)[i * 3 + 2] = mesh->mVertices[i].z;
            }
        }

        EMSCRIPTEN_KEEPALIVE void ObjImporter_getIndices(TObjImporter* importer, int meshIndex,
                                                          uint32_t** outIndices, int* outCount)
        {
            *outIndices = nullptr;
            *outCount = 0;

            if (!importer) return;
            auto* data = reinterpret_cast<ObjImporterData*>(importer);

            if (meshIndex < 0 || meshIndex >= static_cast<int>(data->scene->mNumMeshes)) {
                ERROR("Invalid mesh index: %d", meshIndex);
                return;
            }

            const aiMesh* mesh = data->scene->mMeshes[meshIndex];
            if (!mesh->HasFaces()) {
                ERROR("Mesh %d has no faces", meshIndex);
                return;
            }

            // Count total indices (all faces are triangles due to aiProcess_Triangulate)
            unsigned int totalIndices = 0;
            for (unsigned int i = 0; i < mesh->mNumFaces; i++) {
                totalIndices += mesh->mFaces[i].mNumIndices;
            }

            // Allocate and copy index data
            *outCount = static_cast<int>(totalIndices);
            *outIndices = static_cast<uint32_t*>(malloc(*outCount * sizeof(uint32_t)));

            unsigned int offset = 0;
            for (unsigned int i = 0; i < mesh->mNumFaces; i++) {
                const aiFace& face = mesh->mFaces[i];
                for (unsigned int j = 0; j < face.mNumIndices; j++) {
                    (*outIndices)[offset++] = face.mIndices[j];
                }
            }
        }

        EMSCRIPTEN_KEEPALIVE void ObjImporter_getNormals(TObjImporter* importer, int meshIndex,
                                                          float** outNormals, int* outCount)
        {
            *outNormals = nullptr;
            *outCount = 0;

            if (!importer) return;
            auto* data = reinterpret_cast<ObjImporterData*>(importer);

            if (meshIndex < 0 || meshIndex >= static_cast<int>(data->scene->mNumMeshes)) {
                ERROR("Invalid mesh index: %d", meshIndex);
                return;
            }

            const aiMesh* mesh = data->scene->mMeshes[meshIndex];
            if (!mesh->HasNormals()) {
                // Mesh has no normals - this is fine, just return nullptr
                return;
            }

            // Allocate and copy normal data
            *outCount = static_cast<int>(mesh->mNumVertices * 3);
            *outNormals = static_cast<float*>(malloc(*outCount * sizeof(float)));

            for (unsigned int i = 0; i < mesh->mNumVertices; i++) {
                (*outNormals)[i * 3 + 0] = mesh->mNormals[i].x;
                (*outNormals)[i * 3 + 1] = mesh->mNormals[i].y;
                (*outNormals)[i * 3 + 2] = mesh->mNormals[i].z;
            }
        }

        EMSCRIPTEN_KEEPALIVE void ObjImporter_getUVs(TObjImporter* importer, int meshIndex,
                                                      float** outUVs, int* outCount)
        {
            *outUVs = nullptr;
            *outCount = 0;

            if (!importer) return;
            auto* data = reinterpret_cast<ObjImporterData*>(importer);

            if (meshIndex < 0 || meshIndex >= static_cast<int>(data->scene->mNumMeshes)) {
                ERROR("Invalid mesh index: %d", meshIndex);
                return;
            }

            const aiMesh* mesh = data->scene->mMeshes[meshIndex];
            if (!mesh->HasTextureCoords(0)) {
                // Mesh has no UVs - this is fine, just return nullptr
                return;
            }

            // Allocate and copy UV data (2 floats per UV)
            *outCount = static_cast<int>(mesh->mNumVertices * 2);
            *outUVs = static_cast<float*>(malloc(*outCount * sizeof(float)));

            for (unsigned int i = 0; i < mesh->mNumVertices; i++) {
                (*outUVs)[i * 2 + 0] = mesh->mTextureCoords[0][i].x;
                (*outUVs)[i * 2 + 1] = mesh->mTextureCoords[0][i].y;
            }
        }

        EMSCRIPTEN_KEEPALIVE const char* ObjImporter_getMaterialName(TObjImporter* importer, int meshIndex)
        {
            if (!importer) return nullptr;
            auto* data = reinterpret_cast<ObjImporterData*>(importer);

            if (meshIndex < 0 || meshIndex >= static_cast<int>(data->scene->mNumMeshes)) {
                ERROR("Invalid mesh index: %d", meshIndex);
                return nullptr;
            }

            const aiMesh* mesh = data->scene->mMeshes[meshIndex];
            if (mesh->mMaterialIndex >= data->scene->mNumMaterials) {
                return nullptr;
            }

            aiMaterial* material = data->scene->mMaterials[mesh->mMaterialIndex];
            aiString name;
            if (material->Get(AI_MATKEY_NAME, name) == AI_SUCCESS) {
                return name.C_Str();
            }

            return nullptr;
        }

        EMSCRIPTEN_KEEPALIVE const char* ObjImporter_getMeshName(TObjImporter* importer, int meshIndex)
        {
            if (!importer) return nullptr;
            auto* data = reinterpret_cast<ObjImporterData*>(importer);

            if (meshIndex < 0 || meshIndex >= static_cast<int>(data->scene->mNumMeshes)) {
                ERROR("Invalid mesh index: %d", meshIndex);
                return nullptr;
            }

            const aiMesh* mesh = data->scene->mMeshes[meshIndex];
            if (mesh->mName.length > 0) {
                return mesh->mName.C_Str();
            }

            return nullptr;
        }

        EMSCRIPTEN_KEEPALIVE void ObjImporter_destroy(TObjImporter* importer)
        {
            if (!importer) return;

            auto* data = reinterpret_cast<ObjImporterData*>(importer);
            delete data->importer;
            delete data;
        }

    } // extern "C"

} // namespace thermion
