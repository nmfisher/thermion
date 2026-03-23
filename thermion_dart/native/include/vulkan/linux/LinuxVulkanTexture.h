#pragma once

#include <cstdint>
#include <memory>
#include "vulkan/BaseVulkanTexture.h"

namespace thermion::vulkan::linux_platform {

/**
 * Linux-focused Vulkan texture with DMA-BUF support for Wayland/X11 compositors.
 * Exports memory via DMA-BUF file descriptors for zero-copy display.
 *
 * Supports two modes:
 * - Block-linear: Single image with COLOR_ATTACHMENT, directly exported via DMA-BUF.
 * - Blit: Render image (TILING_OPTIMAL, COLOR_ATTACHMENT) + export image (LINEAR DMA-BUF).
 *   A per-frame blit copies render→export.
 */
class LinuxVulkanTexture : public thermion::vulkan::BaseVulkanTexture {
public:
    LinuxVulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory,
                       uint32_t width, uint32_t height,
                       int dmaBufFd, uint32_t stride, uint32_t offset, uint32_t drmFormat,
                       VkDeviceSize allocationSize, uint32_t memoryTypeBits,
                       uint64_t drmModifier = 0);

    ~LinuxVulkanTexture() override;

    // DMA-BUF accessors
    int GetDmaBufFd() const { return _dmaBufFd; }
    uint32_t GetStride() const { return _stride; }
    uint32_t GetOffset() const { return _offset; }
    uint32_t GetDrmFormat() const { return _drmFormat; }

    // DRM modifier that was chosen for the exported image
    uint64_t GetDrmModifier() const { return _drmModifier; }

    // Memory info accessors (needed for ExternalVulkanImage metadata)
    VkDeviceSize GetAllocationSize() const { return _allocationSize; }
    uint32_t GetMemoryTypeBits() const { return _memoryTypeBits; }

    // Blit mode accessors
    bool NeedsBlit() const { return _needsBlit; }
    VkImage GetRenderImage() const { return _needsBlit ? _renderImage : _image; }
    VkDeviceMemory GetRenderMemory() const { return _needsBlit ? _renderMemory : _imageMemory; }

    // Factory: create with block-linear modifiers (zero-copy path)
    static std::unique_ptr<LinuxVulkanTexture> createExportable(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height
    );

    // Factory: create with blit fallback (render image + linear export image)
    static std::unique_ptr<LinuxVulkanTexture> createWithBlit(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height
    );

private:
    int _dmaBufFd = -1;
    uint32_t _stride = 0;
    uint32_t _offset = 0;
    uint32_t _drmFormat = 0;
    VkDeviceSize _allocationSize = 0;
    uint32_t _memoryTypeBits = 0;
    uint64_t _drmModifier = 0;

    // Blit mode resources
    bool _needsBlit = false;
    VkImage _renderImage = VK_NULL_HANDLE;
    VkDeviceMemory _renderMemory = VK_NULL_HANDLE;
};

} // namespace thermion::vulkan::linux_platform
