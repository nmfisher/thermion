#pragma once

#include "d3d_context.h"
#include "vulkan_texture.h"
#include "vulkan_utils.h"

#include <mutex>

#include <Windows.h>

#include "utils/ostream.h"
#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

#include "import.h"

namespace thermion::windows::vulkan {

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
};

class TVulkanPlatform : public filament::backend::VulkanPlatform {
    public:

       TVulkanPlatform();
       ~TVulkanPlatform();

       virtual VulkanPlatform::Customization getCustomization() const noexcept;

       SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags,
             VkExtent2D extent = {0, 0}) override;

       void destroy(SwapChainPtr handle) override;

       VkResult present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) override;

       ExternalImageMetadata extractExternalImageMetadata(ExternalImageHandleRef image) const override;
       ImageData createVkImageFromExternal(ExternalImageHandleRef image) const override;

       SwapChainPtr current = std::nullptr_t();
       std::mutex mutex;
       uint32_t currentColorIndex = 0;

      private:
       filament::backend::VulkanPlatform::Customization _customization;

 };
}