
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
  _customization.gpu.index = 0;
}
       
TVulkanPlatform::~TVulkanPlatform() {
  std::cerr << "Destroyed Vulkan platform" << std::endl;
}
 
filament::backend::VulkanPlatform::Customization TVulkanPlatform::getCustomization() const noexcept {
  return _customization;
}
 
filament::backend::VulkanPlatform::SwapChainPtr TVulkanPlatform::createSwapChain(void* nativeWindow, uint64_t flags,
      VkExtent2D extent) {
    std::lock_guard lock(mutex);
    current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
    std::cerr << "Created swap chain with flags " << flags << std::endl;
    return current;
}
       
void TVulkanPlatform::destroy(filament::backend::VulkanPlatform::SwapChainPtr handle) {
  std::lock_guard lock(mutex);
  current = nullptr;
  std::cerr << "Destroyed swap chain" << std::endl;
}
 
VkResult TVulkanPlatform::present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) {
  auto result = filament::backend::VulkanPlatform::present(handle, index, finishedDrawing);
  currentColorIndex = index;
  return result;
}
 
}