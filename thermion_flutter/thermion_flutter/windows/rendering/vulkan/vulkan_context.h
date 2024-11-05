#pragma once

#include <Windows.h>

#include <vulkan/vulkan.h>
#include <vulkan/vulkan_win32.h>

#include "d3d_texture.h"

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
