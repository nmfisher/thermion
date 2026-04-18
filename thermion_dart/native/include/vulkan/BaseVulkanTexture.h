#pragma once

#include <cstdint>
#include <memory>
#include "bluevk/BlueVK.h"

namespace thermion::vulkan {

/**
 * Base class for Vulkan textures with common functionality.
 * Platform-specific subclasses handle external memory integration (D3D on Windows, DMA-BUF on Linux).
 */
class BaseVulkanTexture {
public:
    virtual ~BaseVulkanTexture();

    // Common getters
    VkImage GetImage() const { return _image; }
    VkDeviceMemory GetMemory() const { return _imageMemory; }
    uint32_t GetWidth() const { return _width; }
    uint32_t GetHeight() const { return _height; }
    VkDevice GetDevice() const { return _device; }

    /// Release ownership of the VkImage and VkDeviceMemory so the
    /// destructor will not free them.  Use when an external consumer
    /// (e.g. Filament via setExternalImage) has taken ownership.
    void releaseOwnership() {
        _image = VK_NULL_HANDLE;
        _imageMemory = VK_NULL_HANDLE;
    }

protected:
    // Protected constructor - only subclasses can instantiate
    BaseVulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory,
                      uint32_t width, uint32_t height);

    // Protected members accessible to subclasses
    VkImage _image = VK_NULL_HANDLE;
    VkDevice _device = VK_NULL_HANDLE;
    VkDeviceMemory _imageMemory = VK_NULL_HANDLE;
    uint32_t _width = 0;
    uint32_t _height = 0;

    // Helper to destroy resources (called by subclass destructors if needed)
    void destroyResources(bool freeMemory);
    bool _ownsMemory = false;

};

} // namespace thermion::vulkan
