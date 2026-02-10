#pragma once 

#include <cstdint>
#include <memory>
#include "bluevk/BlueVK.h"

#include "import.h"

namespace thermion::windows::vulkan { 

typedef void *HANDLE;

class DLL_EXPORT VulkanTexture {
    public:
        // Constructor for D3D-interop textures (doesn't own memory)
        VulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory, uint32_t width, uint32_t height, HANDLE d3dTextureHandle);

        // Constructor for pure Vulkan textures (owns memory)
        VulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory, uint32_t width, uint32_t height, bool ownsMemory);

        ~VulkanTexture();

        HANDLE GetD3DTextureHandle() {
            return _d3dTextureHandle;
        }

        // Factory method for D3D-interop textures
        static std::unique_ptr<VulkanTexture> create(VkDevice device, VkPhysicalDevice physicalDevice, uint32_t width, uint32_t height, HANDLE d3dTextureHandle);

        // Factory method for pure Vulkan textures (render target backing)
        static std::unique_ptr<VulkanTexture> createPure(VkDevice device, VkPhysicalDevice physicalDevice, uint32_t width, uint32_t height);

        VkImage GetImage() {
            return _image;
        }

        VkDeviceMemory GetMemory() {
            return _imageMemory;
        }

        uint32_t GetWidth() {
            return _width;
        }

        uint32_t GetHeight() {
            return _height;
        }
    private:
        VkImage _image = VK_NULL_HANDLE;
        VkDevice _device = VK_NULL_HANDLE;
        VkDeviceMemory _imageMemory = VK_NULL_HANDLE;
        uint32_t _width = 0;
        uint32_t _height = 0;
        HANDLE _d3dTextureHandle = nullptr;
        bool _ownsMemory = false;
};

}