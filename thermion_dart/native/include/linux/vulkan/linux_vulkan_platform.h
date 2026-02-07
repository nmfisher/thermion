#pragma once

#include <mutex>
#include <unordered_map>

#include "utils/ostream.h"
#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

namespace thermion::linux_platform::vulkan {

class TVulkanPlatform : public filament::backend::VulkanPlatform {
    public:
       TVulkanPlatform();
       ~TVulkanPlatform();

       virtual VulkanPlatform::Customization getCustomization() const noexcept;

       SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags,
             VkExtent2D extent = {0, 0}) override;

       void destroy(SwapChainPtr handle) override;

       VkResult acquire(SwapChainPtr handle, ImageSyncData* outImageSyncData) override;

       VkResult present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) override;

       VkImage getLastRenderedImage() const { return lastRenderedImage; }

       SwapChainPtr current = std::nullptr_t();
       std::mutex mutex;
       uint32_t currentColorIndex = 0;

      private:
       filament::backend::VulkanPlatform::Customization _customization;
       std::unordered_map<SwapChainPtr, SwapChainBundle> _cachedBundles;
       VkImage lastRenderedImage = VK_NULL_HANDLE;
 };

}
