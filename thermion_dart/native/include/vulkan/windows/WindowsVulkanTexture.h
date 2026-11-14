#pragma once

#include <cstdint>
#include <memory>
#include "vulkan/BaseVulkanTexture.h"
#include "windows/import.h"

namespace thermion::vulkan::windows {

/**
 * Windows-focused Vulkan texture importing a shared D3D11 RGBA8 texture handle
 * directly for Filament RenderTarget color attachment rendering.
 */
class DLL_EXPORT WindowsVulkanTexture : public BaseVulkanTexture {
public:
    WindowsVulkanTexture(
        VkImage image,
        VkDevice device,
        VkDeviceMemory imageMemory,
        uint32_t width,
        uint32_t height,
        HANDLE d3dTextureHandle
    );

    ~WindowsVulkanTexture() override;

    HANDLE GetD3DTextureHandle() const { return _d3dTextureHandle; }

    static std::unique_ptr<WindowsVulkanTexture> create(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height,
        HANDLE d3dTextureHandle
    );

private:
    HANDLE _d3dTextureHandle = nullptr;
};

} // namespace thermion::vulkan::windows
