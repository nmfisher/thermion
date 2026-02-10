#pragma once
#include <cstdint>

struct SurfaceExportInfo {
    int dmabuf_fd;
    uint32_t stride;
    uint32_t offset;
    uint32_t drm_format;
    uint64_t drm_modifier;
    uint32_t width;
    uint32_t height;
};
