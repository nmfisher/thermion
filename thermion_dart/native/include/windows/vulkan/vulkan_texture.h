#pragma once 

#include <cstdint>
#include <memory>
#include "bluevk/BlueVK.h"

#include "import.h"

namespace thermion::windows::vulkan { 

typedef void *HANDLE;

class DLL_EXPORT VulkanTexture {
    public:
        VulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory, uint32_t width, uint32_t height, HANDLE d3dTextureHandle);
        ~VulkanTexture();

        HANDLE GetD3DTextureHandle() { 
            return _d3dTextureHandle;
        }

        static std::unique_ptr<VulkanTexture> create(VkDevice device, VkPhysicalDevice physicalDevice, uint32_t width, uint32_t height, HANDLE d3dTextureHandle);

        VkImage GetImage() {
            return _image;
        }
    private:
        VkImage _image = VK_NULL_HANDLE;
        VkDevice _device = VK_NULL_HANDLE;
        VkDeviceMemory _imageMemory = VK_NULL_HANDLE;
        uint32_t _width = 0;
        uint32_t _height = 0;
        HANDLE _d3dTextureHandle;
};

}