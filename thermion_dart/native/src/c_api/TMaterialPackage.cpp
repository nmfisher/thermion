#include "c_api/TMaterialPackage.h"

#include <filament/MaterialChunkType.h>
#include <filament/MaterialEnums.h>

namespace {

// Filament's chunk container stores integers little-endian, without alignment.
// Callers check the available byte count before reading.
template<typename T>
T readLittleEndian(const uint8_t *data) {
    T value = 0;
    for (size_t i = 0; i < sizeof(T); ++i) {
        value |= static_cast<T>(data[i]) << (8 * i);
    }
    return value;
}

}

extern "C" {

EMSCRIPTEN_KEEPALIVE uint32_t Material_getSupportedVersion() {
    return filament::MATERIAL_VERSION;
}

EMSCRIPTEN_KEEPALIVE int64_t Material_getPackageVersion(const uint8_t *data, size_t length) {
    if (!data) {
        return -1;
    }

    constexpr size_t headerSize = sizeof(uint64_t) + sizeof(uint32_t);
    size_t offset = 0;
    int64_t version = -1;
    while (offset < length) {
        if (length - offset < headerSize) {
            return -1;
        }
        const auto type = readLittleEndian<uint64_t>(data + offset);
        const auto size = readLittleEndian<uint32_t>(data + offset + sizeof(uint64_t));
        offset += headerSize;
        // Subtract before comparing so a corrupt size cannot wrap the offset.
        if (size > length - offset) {
            return -1;
        }
        if (type == filamat::MaterialVersion) {
            if (version != -1 || size != sizeof(uint32_t)) {
                return -1;
            }
            version = readLittleEndian<uint32_t>(data + offset);
        }
        offset += size;
    }
    return version;
}

}
