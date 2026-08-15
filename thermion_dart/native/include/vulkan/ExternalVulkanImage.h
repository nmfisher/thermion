#pragma once

#include "bluevk/BlueVK.h"
#include "backend/Platform.h"
#include "backend/platforms/VulkanPlatform.h"

namespace thermion::vulkan {

// A concrete ExternalImage subclass that wraps a Vulkan image created externally
// (e.g. via D3D-Vulkan interop). Pass an instance of this to Texture::setExternalImage().
struct ExternalVulkanImage : public filament::backend::Platform::ExternalImage {
    VkImage image = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    VkFormat format = VK_FORMAT_UNDEFINED;
    uint32_t width = 0;
    uint32_t height = 0;
    uint32_t layers = 1;
    VkImageUsageFlags usage = 0;
    VkDeviceSize allocationSize = 0;
    uint32_t memoryTypeBits = 0;

    // Filament-level metadata
    filament::backend::TextureFormat filamentFormat = filament::backend::TextureFormat::RGBA8;
    filament::backend::TextureUsage filamentUsage = filament::backend::TextureUsage::COLOR_ATTACHMENT;

protected:
    ~ExternalVulkanImage() override = default;
};

}