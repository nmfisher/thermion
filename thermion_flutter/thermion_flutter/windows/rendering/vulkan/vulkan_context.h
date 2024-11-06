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

#include "ThermionWin32.h"
#include <Windows.h>


namespace thermion::windows::vulkan {

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

  void BlitFromSwapchain(VkImage swapchainImage, uint32_t width, uint32_t height);

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

    thermion::windows::d3d::D3DTexture* _texture;
};

}
