#include "linux_vulkan_texture.h"
#include "linux_vulkan_utils.h"
#include "Log.hpp"

#include <iostream>
#include <unistd.h>
#include <drm/drm_fourcc.h>

namespace thermion::linux_platform::vulkan
{

    LinuxVulkanTexture::LinuxVulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory,
                                           uint32_t width, uint32_t height,
                                           int dmaBufFd, uint32_t stride, uint32_t offset, uint32_t drmFormat)
        : _image(image), _device(device), _imageMemory(imageMemory), _width(width), _height(height),
          _dmaBufFd(dmaBufFd), _stride(stride), _offset(offset), _drmFormat(drmFormat) {}

    LinuxVulkanTexture::~LinuxVulkanTexture() {
        bluevk::vkDeviceWaitIdle(_device);
        if (_image != VK_NULL_HANDLE) {
            bluevk::vkDestroyImage(_device, _image, nullptr);
        }
        if (_imageMemory != VK_NULL_HANDLE) {
            bluevk::vkFreeMemory(_device, _imageMemory, nullptr);
        }
        if (_dmaBufFd >= 0) {
            close(_dmaBufFd);
        }
    }

    std::unique_ptr<LinuxVulkanTexture> LinuxVulkanTexture::createExportable(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height)
    {
        // Use DRM_FORMAT_MOD_LINEAR for maximum compatibility
        uint64_t drmModifier = DRM_FORMAT_MOD_LINEAR;

        VkImageDrmFormatModifierListCreateInfoEXT drmModListInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
            .pNext = nullptr,
            .drmFormatModifierCount = 1,
            .pDrmFormatModifiers = &drmModifier
        };

        VkExternalMemoryImageCreateInfo extImageInfo = {
            .sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
            .pNext = &drmModListInfo,
            .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
        };

        VkImageCreateInfo imageInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .pNext = &extImageInfo,
            .flags = 0,
            .imageType = VK_IMAGE_TYPE_2D,
            .format = VK_FORMAT_R8G8B8A8_UNORM,
            .extent = {width, height, 1},
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = VK_SAMPLE_COUNT_1_BIT,
            .tiling = VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT,
            .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
            .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
            .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        };

        VkImage image;
        VkResult result = bluevk::vkCreateImage(device, &imageInfo, nullptr, &image);
        if (result != VK_SUCCESS) {
            std::cerr << "Failed to create exportable VkImage: " << VkResultToString(result) << std::endl;
            return nullptr;
        }

        std::cout << "Created exportable vkImage " << (int64_t)image << std::endl;

        // Get memory requirements
        VkMemoryRequirements memRequirements;
        bluevk::vkGetImageMemoryRequirements(device, image, &memRequirements);

        // Allocate exportable memory
        VkExportMemoryAllocateInfo exportAllocInfo = {
            .sType = VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO,
            .pNext = nullptr,
            .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
        };

        uint32_t memoryTypeIndex = findOptimalMemoryType(
            physicalDevice,
            memRequirements.memoryTypeBits,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        );

        VkMemoryAllocateInfo allocInfo = {
            .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = &exportAllocInfo,
            .allocationSize = memRequirements.size,
            .memoryTypeIndex = memoryTypeIndex
        };

        VkDeviceMemory imageMemory;
        result = bluevk::vkAllocateMemory(device, &allocInfo, nullptr, &imageMemory);
        if (result != VK_SUCCESS) {
            bluevk::vkDestroyImage(device, image, nullptr);
            std::cerr << "Failed to allocate exportable memory: " << VkResultToString(result) << std::endl;
            return nullptr;
        }

        result = bluevk::vkBindImageMemory(device, image, imageMemory, 0);
        if (result != VK_SUCCESS) {
            bluevk::vkFreeMemory(device, imageMemory, nullptr);
            bluevk::vkDestroyImage(device, image, nullptr);
            std::cerr << "Failed to bind exportable image memory" << std::endl;
            return nullptr;
        }

        // Export dmabuf fd
        VkMemoryGetFdInfoKHR getFdInfo = {
            .sType = VK_STRUCTURE_TYPE_MEMORY_GET_FD_INFO_KHR,
            .pNext = nullptr,
            .memory = imageMemory,
            .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
        };

        int dmaBufFd = -1;
        result = bluevk::vkGetMemoryFdKHR(device, &getFdInfo, &dmaBufFd);
        if (result != VK_SUCCESS || dmaBufFd < 0) {
            bluevk::vkFreeMemory(device, imageMemory, nullptr);
            bluevk::vkDestroyImage(device, image, nullptr);
            std::cerr << "Failed to export dmabuf fd: " << VkResultToString(result) << std::endl;
            return nullptr;
        }

        // Query stride via subresource layout
        VkImageSubresource subresource = {
            .aspectMask = VK_IMAGE_ASPECT_MEMORY_PLANE_0_BIT_EXT,
            .mipLevel = 0,
            .arrayLayer = 0
        };
        VkSubresourceLayout layout;
        bluevk::vkGetImageSubresourceLayout(device, image, &subresource, &layout);

        uint32_t stride = static_cast<uint32_t>(layout.rowPitch);
        uint32_t offset = static_cast<uint32_t>(layout.offset);

        // DRM_FORMAT_ABGR8888 corresponds to VK_FORMAT_R8G8B8A8_UNORM
        uint32_t drmFormat = DRM_FORMAT_ABGR8888;

        std::cout << "Exportable texture: dmabuf fd=" << dmaBufFd
                  << " stride=" << stride << " offset=" << offset
                  << " format=DRM_FORMAT_ABGR8888" << std::endl;

        return std::make_unique<LinuxVulkanTexture>(image, device, imageMemory, width, height,
                                                     dmaBufFd, stride, offset, drmFormat);
    }
}
