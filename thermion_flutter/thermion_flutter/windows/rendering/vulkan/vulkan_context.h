#pragma once

#include "d3d_texture.h"
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

#include "ThermionWin32.h"
#include <Windows.h>

#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

namespace thermion::windows::vulkan {

  class TVulkanPlatform : public filament::backend::VulkanPlatform {
   public:
      SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags = 0,
            VkExtent2D extent = {0, 0}) override {
              std::lock_guard lock(mutex);
               _current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
               return _current;
            }
      
      void destroy(SwapChainPtr handle) override {
        std::lock_guard lock(mutex);
        _current = nullptr;
      }

      SwapChainPtr _current;
      std::mutex mutex;

};

class ThermionVulkanContext {
public:
  ThermionVulkanContext();
  void* GetSharedContext();    
  void CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);
  void DestroyRenderingSurface();
  void ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);
  void Flush();

  thermion::windows::d3d::D3DTexture* GetTexture() {
    return _texture;
  }

  int64_t GetImageHandle() {
      return (int64_t)image;
  }

  VkImage GetVkImage() {
    return image;
  }

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
    VkImage image = VK_NULL_HANDLE;
    VkCommandPool commandPool = VK_NULL_HANDLE;
    VkQueue queue = VK_NULL_HANDLE;

    thermion::windows::d3d::D3DTexture *_texture;
    thermion::windows::d3d::D3DTexture *_inactive;
    TVulkanPlatform *_platform;
};

}
