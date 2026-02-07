#include "linux_vulkan_platform.h"
#include "Log.hpp"

#include <iostream>

namespace thermion::linux_platform::vulkan {

TVulkanPlatform::TVulkanPlatform() {
  _customization.gpu.index = -1;
  _customization.transitionSwapChainImageLayoutForPresent = false;
  std::cout << "[ThermionLinux] Using default Vulkan GPU selection" << std::endl;
}

TVulkanPlatform::~TVulkanPlatform() {
  std::cout << "[ThermionLinux] Destroyed Vulkan platform" << std::endl;
}

filament::backend::VulkanPlatform::Customization TVulkanPlatform::getCustomization() const noexcept {
  return _customization;
}

filament::backend::VulkanPlatform::SwapChainPtr TVulkanPlatform::createSwapChain(void* nativeWindow, uint64_t flags,
      VkExtent2D extent) {
    std::lock_guard lock(mutex);
    current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
    if (current) {
        _cachedBundles[current] = getSwapChainBundle(current);
        std::cout << "[ThermionLinux] Cached swap chain bundle with "
                  << _cachedBundles[current].colors.size() << " color images" << std::endl;
    }
    std::cout << "[ThermionLinux] Created swap chain with flags " << flags << std::endl;
    return current;
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
  filament::backend::VulkanPlatform::destroy(handle);
  if(handle == current) {
    current = nullptr;
  }
  std::cout << "[ThermionLinux] Destroyed swap chain" << std::endl;
}

VkResult TVulkanPlatform::acquire(SwapChainPtr handle, ImageSyncData* outImageSyncData) {
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
  auto it = _cachedBundles.find(handle);
  if (it != _cachedBundles.end() && index < it->second.colors.size()) {
    lastRenderedImage = it->second.colors[index];
  }
  auto result = filament::backend::VulkanPlatform::present(handle, index, finishedDrawing);
  currentColorIndex = index;
  return result;
}

}
