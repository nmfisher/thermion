#include "linux_vulkan_platform.h"
#include "Log.hpp"

#include "utils/FixedCapacityVector.h"

namespace thermion::linux_platform::vulkan {

TVulkanPlatform::TVulkanPlatform() {
  _customization.gpu.index = -1;
  _customization.transitionSwapChainImageLayoutForPresent = false;
}

TVulkanPlatform::~TVulkanPlatform() {
}

filament::backend::VulkanPlatform::Customization TVulkanPlatform::getCustomization() const noexcept {
  return _customization;
}

void TVulkanPlatform::setPendingDmaBufImage(VkImage image, uint32_t width, uint32_t height) {
  std::lock_guard lock(mutex);
  _pendingDmaBufImage = image;
  _pendingExtent = {width, height};
}

filament::backend::VulkanPlatform::SwapChainPtr TVulkanPlatform::createSwapChain(void* nativeWindow, uint64_t flags,
      VkExtent2D extent) {
    std::lock_guard lock(mutex);

    // If nativeWindow is null and we have a pending DMA-BUF image, create a custom swapchain
    if (nativeWindow == nullptr && _pendingDmaBufImage != VK_NULL_HANDLE) {
        auto* sc = new DmaBufSwapChain();
        sc->image = _pendingDmaBufImage;
        sc->extent = _pendingExtent;

        SwapChainPtr handle = sc;

        auto colors = utils::FixedCapacityVector<VkImage>::with_capacity(1);
        colors.push_back(sc->image);

        SwapChainBundle bundle{};
        bundle.colors = std::move(colors);
        bundle.depth = VK_NULL_HANDLE;
        bundle.colorFormat = sc->colorFormat;
        bundle.depthFormat = VK_FORMAT_UNDEFINED;
        bundle.extent = sc->extent;

        _cachedBundles[handle] = std::move(bundle);
        _dmaBufSwapChains.insert(handle);

        // Clear pending state
        _pendingDmaBufImage = VK_NULL_HANDLE;
        _pendingExtent = {0, 0};

        current = handle;
        Log("Created DMA-BUF swapchain for direct rendering (%ux%u)", sc->extent.width, sc->extent.height);
        return handle;
    }

    // Fallback: delegate to base class
    current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
    if (current) {
        _cachedBundles[current] = filament::backend::VulkanPlatform::getSwapChainBundle(current);
    }
    return current;
}

filament::backend::VulkanPlatform::SwapChainBundle TVulkanPlatform::getSwapChainBundle(SwapChainPtr handle) {
    std::lock_guard lock(mutex);
    if (_dmaBufSwapChains.count(handle)) {
        auto it = _cachedBundles.find(handle);
        if (it != _cachedBundles.end()) {
            return it->second;
        }
    }
    return filament::backend::VulkanPlatform::getSwapChainBundle(handle);
}

void TVulkanPlatform::destroy(filament::backend::VulkanPlatform::SwapChainPtr handle) {
  std::lock_guard lock(mutex);

  // Check if lastRenderedImage belongs to this swapchain before erasing
  auto it = _cachedBundles.find(handle);
  if (it != _cachedBundles.end()) {
    for (size_t i = 0; i < it->second.colors.size(); i++) {
      if (it->second.colors[i] == lastRenderedImage) {
        lastRenderedImage = VK_NULL_HANDLE;
        break;
      }
    }
  }
  _cachedBundles.erase(handle);

  if (_dmaBufSwapChains.count(handle)) {
    // DMA-BUF swapchain: just delete the struct, do NOT destroy the VkImage (context owns it)
    _dmaBufSwapChains.erase(handle);
    delete static_cast<DmaBufSwapChain*>(handle);
  } else {
    filament::backend::VulkanPlatform::destroy(handle);
  }

  if(handle == current) {
    current = nullptr;
  }
}

VkResult TVulkanPlatform::acquire(SwapChainPtr handle, ImageSyncData* outImageSyncData) {
  if (_dmaBufSwapChains.count(handle)) {
    // Single-image swapchain: always index 0, no synchronization needed
    outImageSyncData->imageIndex = 0;
    outImageSyncData->imageReadySemaphore = VK_NULL_HANDLE;
    outImageSyncData->explicitImageReadyWait = nullptr;
    auto it = _cachedBundles.find(handle);
    if (it != _cachedBundles.end() && !it->second.colors.empty()) {
      lastRenderedImage = it->second.colors[0];
    }
    return VK_SUCCESS;
  }

  auto result = filament::backend::VulkanPlatform::acquire(handle, outImageSyncData);
  if (result == VK_SUCCESS && outImageSyncData->imageIndex != ImageSyncData::INVALID_IMAGE_INDEX) {
    auto it = _cachedBundles.find(handle);
    if (it != _cachedBundles.end() && outImageSyncData->imageIndex < it->second.colors.size()) {
      lastRenderedImage = it->second.colors[outImageSyncData->imageIndex];
    }
  }
  return result;
}

VkResult TVulkanPlatform::present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) {
  if (_dmaBufSwapChains.count(handle)) {
    // No-op present for DMA-BUF swapchain -- the image is already available via DMA-BUF
    auto it = _cachedBundles.find(handle);
    if (it != _cachedBundles.end() && index < it->second.colors.size()) {
      lastRenderedImage = it->second.colors[index];
    }
    return VK_SUCCESS;
  }

  auto it = _cachedBundles.find(handle);
  if (it != _cachedBundles.end() && index < it->second.colors.size()) {
    lastRenderedImage = it->second.colors[index];
  }
  auto result = filament::backend::VulkanPlatform::present(handle, index, finishedDrawing);
  currentColorIndex = index;
  return result;
}

bool TVulkanPlatform::hasResized(SwapChainPtr handle) {
  if (_dmaBufSwapChains.count(handle)) {
    return false;
  }
  return filament::backend::VulkanPlatform::hasResized(handle);
}

}
