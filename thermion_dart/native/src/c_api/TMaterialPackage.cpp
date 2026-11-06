#include "c_api/TMaterialPackage.h"

#include "trace_shim.h"

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
        // TEMPORARY trace: a null buffer is itself a transfer failure.
        thermion::trace::logLine("[material-trace] Material_getPackageVersion null reject");
        return -1;
    }

    // TEMPORARY trace: the raw input this function is asked to parse.
    thermion::trace::tracePackageBytes("Material_getPackageVersion input", data, length);

    constexpr size_t headerSize = sizeof(uint64_t) + sizeof(uint32_t);
    size_t offset = 0;
    int64_t version = -1;
    while (offset < length) {
        if (length - offset < headerSize) {
            // TEMPORARY trace: trailing bytes cannot hold a chunk header.
            thermion::trace::logLine(
                "[material-trace] Material_getPackageVersion short-header reject");
            return -1;
        }
        const auto type = readLittleEndian<uint64_t>(data + offset);
        const auto size = readLittleEndian<uint32_t>(data + offset + sizeof(uint64_t));
        offset += headerSize;
        // Subtract before comparing so a corrupt size cannot wrap the offset.
        if (size > length - offset) {
            // TEMPORARY trace: a chunk size that exceeds the buffer is the
            // signature of a corrupt or truncated transfer.
            char line[160];
            std::snprintf(line, sizeof(line),
                          "[material-trace] Material_getPackageVersion overflow reject: "
                          "offset=%zu type=0x%016" PRIx64 " size=%" PRIu32 " length=%zu",
                          offset, type, size, length);
            thermion::trace::logLine(line);
            return -1;
        }
        if (type == filamat::MaterialVersion) {
            if (version != -1 || size != sizeof(uint32_t)) {
                // TEMPORARY trace: MAT_VERS must appear exactly once with a
                // 4-byte payload; anything else means the bytes are corrupt.
                char line[160];
                std::snprintf(line, sizeof(line),
                              "[material-trace] Material_getPackageVersion version-chunk reject: "
                              "size=%" PRIu32 " (want 4), version=%" PRId64,
                              size, version);
                thermion::trace::logLine(line);
                return -1;
            }
            version = readLittleEndian<uint32_t>(data + offset);
        }
        offset += size;
    }
    char line[96];
    std::snprintf(line, sizeof(line),
                  "[material-trace] Material_getPackageVersion -> %" PRId64 " (chunk scan done)",
                  version);
    thermion::trace::logLine(line);
    return version;
}

}
