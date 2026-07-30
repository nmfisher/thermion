#pragma once

#include <mutex>

#include "utils/ostream.h"
#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

#include "windows/import.h"

namespace thermion::vulkan::windows {

class WindowsVulkanPlatform : public filament::backend::VulkanPlatform {
    public:

       WindowsVulkanPlatform();
       ~WindowsVulkanPlatform();

       virtual VulkanPlatform::Customization getCustomization() const noexcept;

       SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags,
             VkExtent2D extent = {0, 0}) override;

       void destroy(SwapChainPtr handle) override;

       VkResult present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) override;

       ExtensionSet getSwapchainInstanceExtensions() const override;
       SurfaceBundle createVkSurfaceKHR(void* nativeWindow, VkInstance instance,
             uint64_t flags) const noexcept override;

       ExternalImageMetadata extractExternalImageMetadata(ExternalImageHandleRef image) const override;
       ImageData createVkImageFromExternal(ExternalImageHandleRef image,
              uint32_t logicalWidth, uint32_t logicalHeight) const override;

       SwapChainPtr current = std::nullptr_t();
       std::mutex mutex;
       uint32_t currentColorIndex = 0;

      private:
       filament::backend::VulkanPlatform::Customization _customization;

 };
}