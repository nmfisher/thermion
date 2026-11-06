// TEMPORARY material-package transfer tracing shim. Remove together with
// the [material-trace] call sites once the web FormatException is
// diagnosed.
//
// This header is for C++ translation units in src/c_api only (e.g.
// TMaterialCompiler.cpp, TMaterialPackage.cpp). It must NEVER be included
// from headers under native/include/c_api: ffigen parses those as C, where
// default member initializers and C++-only declarations are parse errors.
#ifndef THERMION_C_API_TRACE_SHIM_H
#define THERMION_C_API_TRACE_SHIM_H

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cinttypes>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

namespace thermion
{
    namespace trace
    {

        // One-line console log that works on both web and native builds.
        // emscripten_log appends a newline itself, so no trailing \n.
        inline void logLine(const char *line)
        {
#ifdef __EMSCRIPTEN__
            emscripten_log(EM_LOG_CONSOLE, "%s", line);
#else
            std::fprintf(stderr, "%s\n", line);
#endif
        }

        // Logs label + length + the first (up to) 24 bytes at data as hex.
        // Never dereferences beyond length; safe for null data with
        // length == 0.
        inline void tracePackageBytes(const char *label, const void *data, size_t length)
        {
            char line[256];
            const auto *bytes = static_cast<const uint8_t *>(data);
            int written = std::snprintf(line, sizeof(line),
                                       "[material-trace] %s: ptr=%p length=%zu bytes=",
                                       label, data, length);
            const size_t n = length < 24 ? length : 24;
            for (size_t i = 0; i < n && written > 0 && size_t(written) < sizeof(line) - 4; ++i)
            {
                written += std::snprintf(line + written, sizeof(line) - size_t(written),
                                         "%s%02x", i ? " " : "", unsigned(bytes[i]));
            }
            logLine(line);
        }

    } // namespace trace
} // namespace thermion

#endif // THERMION_C_API_TRACE_SHIM_H
