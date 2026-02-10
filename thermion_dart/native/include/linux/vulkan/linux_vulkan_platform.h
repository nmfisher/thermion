#pragma once

#include <mutex>
#include <unordered_map>
#include <unordered_set>

#include "utils/ostream.h"
#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

namespace thermion::linux_platform::vulkan {

// Custom swapchain backed by a DMA-BUF image for zero-copy rendering.
// Non-owning: the VkImage lifetime is managed by the context (LinuxVulkanTexture).
struct DmaBufSwapChain : public filament::backend::Platform::SwapChain {
    VkImage image = VK_NULL_HANDLE;
    VkFormat colorFormat = VK_FORMAT_R8G8B8A8_UNORM;
    VkExtent2D extent = {0, 0};
};

class TVulkanPlatform : public filament::backend::VulkanPlatform {
    public:
       TVulkanPlatform();
       ~TVulkanPlatform();

       virtual VulkanPlatform::Customization getCustomization() const noexcept;

       SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags,
             VkExtent2D extent = {0, 0}) override;

       SwapChainBundle getSwapChainBundle(SwapChainPtr handle) override;

       void destroy(SwapChainPtr handle) override;

       VkResult acquire(SwapChainPtr handle, ImageSyncData* outImageSyncData) override;

       VkResult present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) override;

       bool hasResized(SwapChainPtr handle) override;

       VkImage getLastRenderedImage() const { return lastRenderedImage; }

       // Set a pending DMA-BUF image to be consumed by the next createSwapChain(nullptr, ...) call.
       void setPendingDmaBufImage(VkImage image, uint32_t width, uint32_t height);

       SwapChainPtr current = std::nullptr_t();
       std::mutex mutex;
       uint32_t currentColorIndex = 0;

      private:
       filament::backend::VulkanPlatform::Customization _customization;
       std::unordered_map<SwapChainPtr, SwapChainBundle> _cachedBundles;
       std::unordered_set<SwapChainPtr> _dmaBufSwapChains;
       VkImage lastRenderedImage = VK_NULL_HANDLE;

       VkImage _pendingDmaBufImage = VK_NULL_HANDLE;
       VkExtent2D _pendingExtent = {0, 0};
 };

}
