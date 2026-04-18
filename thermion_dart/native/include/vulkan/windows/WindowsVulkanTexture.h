#pragma once

#include <cstdint>
#include <memory>
#include "vulkan/BaseVulkanTexture.h"
#include "windows/import.h"

namespace thermion::vulkan::windows {

/**
 * Windows-focused Vulkan texture with D3D11 interop support.
 * Two creation modes:
 * 1. D3D-interop: Imports memory from D3D11 texture (doesn't own memory)
 * 2. Pure Vulkan: Allocates own memory for render targets
 */
class DLL_EXPORT WindowsVulkanTexture : public BaseVulkanTexture {
public:
    // Constructor for D3D-interop textures (doesn't own memory)
    WindowsVulkanTexture(
        VkImage image,
        VkDevice device,
        VkDeviceMemory imageMemory,
        uint32_t width,
        uint32_t height,
        HANDLE d3dTextureHandle
    );

    // Constructor for pure Vulkan textures (owns memory)
    WindowsVulkanTexture(
        VkImage image,
        VkDevice device,
        VkDeviceMemory imageMemory,
        uint32_t width,
        uint32_t height,
        bool ownsMemory
    );

    ~WindowsVulkanTexture() override;

    HANDLE GetD3DTextureHandle() const { return _d3dTextureHandle; }
    bool OwnsMemory() const { return _ownsMemory; }

    // Factory method for D3D-interop textures (Windows only)
    static std::unique_ptr<WindowsVulkanTexture> create(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height,
        HANDLE d3dTextureHandle
    );

    // Factory method for pure Vulkan textures (render target backing)
    static std::unique_ptr<WindowsVulkanTexture> createPure(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height
    );

private:
    HANDLE _d3dTextureHandle = nullptr;
    bool _ownsMemory = false;
};

} // namespace thermion::vulkan::windows
