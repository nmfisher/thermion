#pragma once

#include <cstdint>
#include <memory>
#include "bluevk/BlueVK.h"

namespace thermion::linux_platform::vulkan {

class LinuxVulkanTexture {
    public:
        LinuxVulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory,
                           uint32_t width, uint32_t height,
                           int dmaBufFd, uint32_t stride, uint32_t offset, uint32_t drmFormat);

        ~LinuxVulkanTexture();

        // Factory method for exportable dmabuf-backed textures (transfer-dst only, for blit path)
        static std::unique_ptr<LinuxVulkanTexture> createExportable(VkDevice device, VkPhysicalDevice physicalDevice, uint32_t width, uint32_t height);

        // Factory method for color-attachable dmabuf-backed textures (zero-copy direct rendering)
        // Returns nullptr if the GPU does not support COLOR_ATTACHMENT_BIT on DRM_FORMAT_MOD_LINEAR
        static std::unique_ptr<LinuxVulkanTexture> createColorAttachable(VkDevice device, VkPhysicalDevice physicalDevice, uint32_t width, uint32_t height);

        VkImage GetImage() { return _image; }
        int GetDmaBufFd() { return _dmaBufFd; }
        uint32_t GetStride() { return _stride; }
        uint32_t GetOffset() { return _offset; }
        uint32_t GetDrmFormat() { return _drmFormat; }
        uint32_t GetWidth() { return _width; }
        uint32_t GetHeight() { return _height; }

    private:
        VkImage _image = VK_NULL_HANDLE;
        VkDevice _device = VK_NULL_HANDLE;
        VkDeviceMemory _imageMemory = VK_NULL_HANDLE;
        uint32_t _width = 0;
        uint32_t _height = 0;
        int _dmaBufFd = -1;
        uint32_t _stride = 0;
        uint32_t _offset = 0;
        uint32_t _drmFormat = 0;
};

}
