
#include "vulkan_context.h"
#include "ThermionWin32.h"

#include <functional>
#include <vector>
#include <chrono>
#include <string>
#include <fstream>
#include <iostream>
#include <memory>
#include <thread>

#include "filament/backend/platforms/VulkanPlatform.h"
#include "filament/Engine.h"
#include "filament/Renderer.h"
#include "filament/View.h"
#include "filament/Viewport.h"
#include "filament/Scene.h"
#include "filament/SwapChain.h"
#include "filament/Texture.h"
#include "Log.hpp"

namespace thermion::windows::vulkan {
 
TVulkanPlatform::TVulkanPlatform() {
  _customization.gpu.index = -1;
  TRACE("Using default Vulkan GPU selection");
}
       
TVulkanPlatform::~TVulkanPlatform() {
  TRACE("Destroyed Vulkan platform");
}
 
filament::backend::VulkanPlatform::Customization TVulkanPlatform::getCustomization() const noexcept {
  return _customization;
}
 
filament::backend::VulkanPlatform::SwapChainPtr TVulkanPlatform::createSwapChain(void* nativeWindow, uint64_t flags,
      VkExtent2D extent) {
    std::lock_guard lock(mutex);
    current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
    TRACE("Created swap chain with flags %d", flags);
    return current;
}
       
void TVulkanPlatform::destroy(filament::backend::VulkanPlatform::SwapChainPtr handle) {
  std::lock_guard lock(mutex);
  filament::backend::VulkanPlatform::destroy(handle);
  if(handle == current) {
    current = nullptr;
  }
  TRACE("Destroyed swap chain");
}
 
VkResult TVulkanPlatform::present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) {
  auto result = filament::backend::VulkanPlatform::present(handle, index, finishedDrawing);
  currentColorIndex = index;
  return result;
}

filament::backend::VulkanPlatform::ExternalImageMetadata TVulkanPlatform::extractExternalImageMetadata(ExternalImageHandleRef image) const {
  auto* ext = static_cast<ExternalVulkanImage const*>(image.get());
  ExternalImageMetadata metadata{};
  metadata.filamentFormat = ext->filamentFormat;
  metadata.filamentUsage = ext->filamentUsage;
  metadata.width = ext->width;
  metadata.height = ext->height;
  metadata.layers = ext->layers;
  metadata.samples = VK_SAMPLE_COUNT_1_BIT;
  metadata.format = ext->format;
  metadata.externalFormat = 0;
  metadata.usage = ext->usage;
  metadata.allocationSize = ext->allocationSize;
  metadata.memoryTypeBits = ext->memoryTypeBits;
  return metadata;
}

filament::backend::VulkanPlatform::ImageData TVulkanPlatform::createVkImageFromExternal(ExternalImageHandleRef image) const {
  auto* ext = static_cast<ExternalVulkanImage const*>(image.get());
  ImageData data{};
  data.internal.image = ext->image;
  data.internal.memory = ext->memory;
  return data;
}

}
