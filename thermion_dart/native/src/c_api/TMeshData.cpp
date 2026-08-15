#include "c_api/TMeshData.h"

#include <cstdlib>
#include <cstring>

namespace thermion
{

    extern "C"
    {

        // TMeshData buffers and strings are malloced by whichever parser filled
        // the struct (see model_import.cpp / TGltfParser.cpp), so free() is the
        // matching deallocator for everything here.
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
    }
}
