#include "c_api/TMaterialPackage.h"

#include <filament/MaterialChunkType.h>
#include <filament/MaterialEnums.h>

#include <cstdio>
#include <cinttypes>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

namespace {

// TEMPORARY tracing (remove with the other material-trace calls): prints the
// first bytes Material_getPackageVersion sees so the value can be compared
// with the Dart-side and compiler-side dumps in the browser console.
void tracePackageBytes(const char *label, const uint8_t *data, size_t length)
{
    char line[256];
    int written = snprintf(line, sizeof(line),
                           "[material-trace] %s: data=%p length=%zu bytes=", label,
                           static_cast<const void *>(data), length);
    const size_t n = length < 24 ? length : 24;
    for (size_t i = 0; i < n && written > 0 && size_t(written) < sizeof(line) - 4; ++i)
    {
        written += snprintf(line + written, sizeof(line) - size_t(written), "%s%02x",
                            i ? " " : "", unsigned(data[i]));
    }
#ifdef __EMSCRIPTEN__
    emscripten_log(EM_LOG_CONSOLE, "%s", line);
#else
    fprintf(stderr, "%s\n", line);
#endif
}

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
#ifdef __EMSCRIPTEN__
        emscripten_log(EM_LOG_CONSOLE,
                       "[material-trace] Material_getPackageVersion null reject: length=%zu",
                       length);
#else
        fprintf(stderr, "[material-trace] Material_getPackageVersion null reject: length=%zu\n",
                length);
#endif
        return -1;
    }

    // TEMPORARY trace: the raw input this function is asked to parse.
    tracePackageBytes("Material_getPackageVersion input", data, length);

    constexpr size_t headerSize = sizeof(uint64_t) + sizeof(uint32_t);
    size_t offset = 0;
    int64_t version = -1;
    while (offset < length) {
        if (length - offset < headerSize) {
            tracePackageBytes("Material_getPackageVersion short-header reject", data, length);
            return -1;
        }
        const auto type = readLittleEndian<uint64_t>(data + offset);
        const auto size = readLittleEndian<uint32_t>(data + offset + sizeof(uint64_t));
        offset += headerSize;
        // Subtract before comparing so a corrupt size cannot wrap the offset.
        if (size > length - offset) {
#ifdef __EMSCRIPTEN__
            emscripten_log(EM_LOG_CONSOLE,
                           "[material-trace] Material_getPackageVersion overflow reject: "
                           "offset=%zu type=0x%016" PRIx64 " size=%" PRIu32 " length=%zu",
                           offset, type, size, length);
#else
            fprintf(stderr,
                    "[material-trace] Material_getPackageVersion overflow reject: "
                    "offset=%zu type=0x%016" PRIx64 " size=%" PRIu32 " length=%zu\n",
                    offset, type, size, length);
#endif
            return -1;
        }
        if (type == filamat::MaterialVersion) {
            if (version != -1 || size != sizeof(uint32_t)) {
#ifdef __EMSCRIPTEN__
                emscripten_log(EM_LOG_CONSOLE,
                               "[material-trace] Material_getPackageVersion version-chunk reject: "
                               "size=%" PRIu32 " (want 4), version=%" PRId64,
                               size, version);
#else
                fprintf(stderr,
                        "[material-trace] Material_getPackageVersion version-chunk reject: "
                        "size=%" PRIu32 " (want 4), version=%" PRId64 "\n",
                        size, version);
#endif
                return -1;
            }
            version = readLittleEndian<uint32_t>(data + offset);
        }
        offset += size;
    }
#ifdef __EMSCRIPTEN__
    emscripten_log(EM_LOG_CONSOLE,
                   "[material-trace] Material_getPackageVersion -> %" PRId64 " (chunk scan done)",
                   version);
#else
    fprintf(stderr, "[material-trace] Material_getPackageVersion -> %" PRId64 " (chunk scan done)\n",
            version);
#endif
    return version;
}

}
