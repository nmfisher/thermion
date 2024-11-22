#pragma once

#include "d3d_context.h"

#include "vulkan_texture.h"

#include "utils.h"

#include <fstream>

#include <iostream>
#include <thread>
#include <chrono>
#include <vector>
#include <string>

#include <functional>
#include <iostream>
#include <memory>
#include <thread>
#include <mutex>

#include <Windows.h>

#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

#include "import.h"

namespace thermion::windows::vulkan {

  class TVulkanPlatform : public filament::backend::VulkanPlatform {
   public:

      TVulkanPlatform() {
        _customization.gpu.index = 0;
      }

      virtual VulkanPlatform::Customization getCustomization() const noexcept override {
        return _customization;
      }

      SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags,
            VkExtent2D extent = {0, 0}) override {
              std::lock_guard lock(mutex);
              current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
              std::cout << "Created swap chain with flags " << flags << std::endl;
              return current;
            }
      
      void destroy(SwapChainPtr handle) override {
        std::lock_guard lock(mutex);
        current = nullptr;
        std::cout << "Destroyed swap chain" << std::endl;
      }

      VkResult present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) override {
        auto result = filament::backend::VulkanPlatform::present(handle, index, finishedDrawing);
        currentColorIndex = index;
        return result;
      }
    SwapChainPtr current;
    std::mutex mutex;
    uint32_t currentColorIndex = 0;

    private:  
      filament::backend::VulkanPlatform::Customization _customization;

};

class EMSCRIPTEN_KEEPALIVE ThermionVulkanContext {
public:
  ThermionVulkanContext();
  void* GetSharedContext();    
  HANDLE CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);
  void DestroyRenderingSurface(HANDLE handle);
  void ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);
  void Flush();

  filament::backend::VulkanPlatform *GetPlatform() { 
    return _platform;
  }

  void BlitFromSwapchain();

  void readPixelsFromImage(
    uint32_t width,
    uint32_t height,
    std::vector<uint8_t>& outPixels
  );


private:
    VkInstance instance = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    VkCommandPool commandPool = VK_NULL_HANDLE;
    VkQueue queue = VK_NULL_HANDLE;

    std::unique_ptr<thermion::windows::d3d::D3DContext> _d3dContext;

    std::vector<std::unique_ptr<thermion::windows::d3d::D3DTexture>> _d3dTextures;
    std::vector<std::unique_ptr<thermion::windows::vulkan::VulkanTexture>> _vulkanTextures;
    
    TVulkanPlatform *_platform;
};

}
