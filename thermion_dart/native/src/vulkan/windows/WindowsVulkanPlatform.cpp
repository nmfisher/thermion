#include "vulkan/windows/WindowsVulkanPlatform.h"

#include "ThermionWin32.h"

#include <functional>
#include <vector>
#include <chrono>
#include <string>
#include <fstream>
#include <iostream>
#include <memory>
#include <thread>


#include "filament/Engine.h"
#include "filament/Renderer.h"
#include "filament/View.h"
#include "filament/Viewport.h"
#include "filament/Scene.h"
#include "filament/SwapChain.h"
#include "filament/Texture.h"
#include "Log.hpp"

namespace thermion::vulkan::windows {
 
WindowsVulkanPlatform::WindowsVulkanPlatform() {
  _customization.gpu.index = -1;
  TRACE("Using default Vulkan GPU selection");
}
       
WindowsVulkanPlatform::~WindowsVulkanPlatform() {
  TRACE("Destroyed Vulkan platform");
}
 
filament::backend::VulkanPlatform::Customization WindowsVulkanPlatform::getCustomization() const noexcept {
  return _customization;
}
 
filament::backend::VulkanPlatform::SwapChainPtr WindowsVulkanPlatform::createSwapChain(void* nativeWindow, uint64_t flags,
      VkExtent2D extent) {
    std::lock_guard lock(mutex);
    current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
    TRACE("Created swap chain with flags %d", flags);
    return current;
}
       
void WindowsVulkanPlatform::destroy(filament::backend::VulkanPlatform::SwapChainPtr handle) {
  std::lock_guard lock(mutex);
  filament::backend::VulkanPlatform::destroy(handle);
  if(handle == current) {
    current = nullptr;
  }
  TRACE("Destroyed swap chain");
}
 
VkResult WindowsVulkanPlatform::present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) {
  auto result = filament::backend::VulkanPlatform::present(handle, index, finishedDrawing);
  currentColorIndex = index;
  return result;
}
 
}
