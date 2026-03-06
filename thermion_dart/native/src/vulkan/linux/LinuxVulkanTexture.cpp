#include "vulkan/linux/LinuxVulkanTexture.h"
#include "vulkan/linux/LinuxVulkanUtils.h"
#include "Log.hpp"

#include <cstring>
#include <iostream>
#include <unistd.h>
#include <drm/drm_fourcc.h>

namespace thermion::vulkan::linux_platform
{

    LinuxVulkanTexture::LinuxVulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory,
                                           uint32_t width, uint32_t height,
                                           int dmaBufFd, uint32_t stride, uint32_t offset, uint32_t drmFormat,
                                           VkDeviceSize allocationSize, uint32_t memoryTypeBits,
                                           uint64_t drmModifier)
        : BaseVulkanTexture(image, device, imageMemory, width, height),
          _dmaBufFd(dmaBufFd), _stride(stride), _offset(offset), _drmFormat(drmFormat),
          _allocationSize(allocationSize), _memoryTypeBits(memoryTypeBits),
          _drmModifier(drmModifier) {}

    LinuxVulkanTexture::~LinuxVulkanTexture() {
        // Close DMA-BUF fd before destroying Vulkan resources
        if (_dmaBufFd >= 0) {
            close(_dmaBufFd);
            _dmaBufFd = -1;
        }

        // Clean up blit mode resources
        if (_needsBlit && _device != VK_NULL_HANDLE) {
            bluevk::vkDeviceWaitIdle(_device);
            if (_renderImage != VK_NULL_HANDLE) {
                bluevk::vkDestroyImage(_device, _renderImage, nullptr);
                _renderImage = VK_NULL_HANDLE;
            }
            if (_renderMemory != VK_NULL_HANDLE) {
                bluevk::vkFreeMemory(_device, _renderMemory, nullptr);
                _renderMemory = VK_NULL_HANDLE;
            }
        }

        // LinuxVulkanTexture always owns its memory (the export image)
        destroyResources(true);
    }

    std::unique_ptr<LinuxVulkanTexture> LinuxVulkanTexture::createExportable(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height)
    {
        std::cerr << "[ThermionVk:Texture] createExportable " << width << "x" << height << std::endl;

        // Query modifiers that support COLOR_ATTACHMENT
        auto colorAttachModifiers = queryColorAttachmentModifiers(physicalDevice, VK_FORMAT_R8G8B8A8_UNORM);

        if (colorAttachModifiers.empty()) {
            std::cerr << "[ThermionVk:Texture] No COLOR_ATTACHMENT modifiers found, cannot create block-linear image" << std::endl;
            return nullptr;
        }

        std::cerr << "[ThermionVk:Texture] Found " << colorAttachModifiers.size()
                  << " COLOR_ATTACHMENT modifiers, passing to driver" << std::endl;

        VkImageDrmFormatModifierListCreateInfoEXT drmModListInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
            .pNext = nullptr,
            .drmFormatModifierCount = static_cast<uint32_t>(colorAttachModifiers.size()),
            .pDrmFormatModifiers = colorAttachModifiers.data()
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
            .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
            .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
            .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        };

        std::cerr << "[ThermionVk:Texture] Creating VkImage with " << colorAttachModifiers.size()
                  << " block-linear modifiers" << std::endl;

        VkImage image;
        VkResult result = bluevk::vkCreateImage(device, &imageInfo, nullptr, &image);
        if (result != VK_SUCCESS) {
            LOG_ERROR("Failed to create exportable VkImage: %s", VkResultToString(result));
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] vkCreateImage: OK (handle=0x"
                  << std::hex << reinterpret_cast<uintptr_t>(image) << std::dec << ")" << std::endl;

        // Query which modifier the driver actually chose
        VkImageDrmFormatModifierPropertiesEXT chosenModProps = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_PROPERTIES_EXT,
            .pNext = nullptr,
        };
        result = bluevk::vkGetImageDrmFormatModifierPropertiesEXT(device, image, &chosenModProps);
        uint64_t chosenModifier = 0;
        if (result == VK_SUCCESS) {
            chosenModifier = chosenModProps.drmFormatModifier;
            std::cerr << "[ThermionVk:Texture] Driver chose modifier: 0x"
                      << std::hex << chosenModifier << std::dec << std::endl;
        } else {
            std::cerr << "[ThermionVk:Texture] WARNING: Failed to query chosen modifier: "
                      << VkResultToString(result) << std::endl;
        }

        // Get memory requirements
        VkMemoryRequirements memRequirements;
        bluevk::vkGetImageMemoryRequirements(device, image, &memRequirements);
        std::cerr << "[ThermionVk:Texture] Memory requirements: size=" << memRequirements.size
                  << " alignment=" << memRequirements.alignment
                  << " typeBits=0x" << std::hex << memRequirements.memoryTypeBits << std::dec << std::endl;

        // DMA-BUF export requires dedicated allocation
        VkMemoryDedicatedAllocateInfo dedicatedAllocInfo = {
            .sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO,
            .pNext = nullptr,
            .image = image,
            .buffer = VK_NULL_HANDLE
        };

        // Allocate exportable memory
        VkExportMemoryAllocateInfo exportAllocInfo = {
            .sType = VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO,
            .pNext = &dedicatedAllocInfo,
            .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
        };

        uint32_t memoryTypeIndex = findOptimalMemoryType(
            physicalDevice,
            memRequirements.memoryTypeBits,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        );
        std::cerr << "[ThermionVk:Texture] Selected memory type index: " << memoryTypeIndex
                  << (memoryTypeIndex == UINT32_MAX ? " (FAILED)" : "") << std::endl;

        if (memoryTypeIndex == UINT32_MAX) {
            bluevk::vkDestroyImage(device, image, nullptr);
            LOG_ERROR("Failed to find suitable memory type for exportable image");
            return nullptr;
        }

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
            LOG_ERROR("Failed to allocate exportable memory: %s", VkResultToString(result));
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] vkAllocateMemory: OK (" << memRequirements.size << " bytes)" << std::endl;

        result = bluevk::vkBindImageMemory(device, image, imageMemory, 0);
        if (result != VK_SUCCESS) {
            bluevk::vkFreeMemory(device, imageMemory, nullptr);
            bluevk::vkDestroyImage(device, image, nullptr);
            LOG_ERROR("Failed to bind exportable image memory");
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] vkBindImageMemory: OK" << std::endl;

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
            LOG_ERROR("Failed to export dmabuf fd: %s", VkResultToString(result));
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] vkGetMemoryFdKHR: OK (fd=" << dmaBufFd << ")" << std::endl;

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

        std::cerr << "[ThermionVk:Texture] Subresource layout: offset=" << layout.offset
                  << " size=" << layout.size
                  << " rowPitch=" << layout.rowPitch
                  << " arrayPitch=" << layout.arrayPitch
                  << " depthPitch=" << layout.depthPitch << std::endl;

        // DRM_FORMAT_ABGR8888 corresponds to VK_FORMAT_R8G8B8A8_UNORM
        uint32_t drmFormat = DRM_FORMAT_ABGR8888;

        std::cerr << "[ThermionVk:Texture] Created exportable texture (block-linear): "
                  << width << "x" << height
                  << " fd=" << dmaBufFd
                  << " stride=" << stride
                  << " offset=" << offset
                  << " drmFormat=ABGR8888"
                  << " modifier=0x" << std::hex << chosenModifier << std::dec
                  << " allocSize=" << memRequirements.size
                  << " memTypeBits=0x" << std::hex << memRequirements.memoryTypeBits << std::dec
                  << std::endl;

        return std::make_unique<LinuxVulkanTexture>(image, device, imageMemory, width, height,
                                                     dmaBufFd, stride, offset, drmFormat,
                                                     memRequirements.size, memRequirements.memoryTypeBits,
                                                     chosenModifier);
    }

    std::unique_ptr<LinuxVulkanTexture> LinuxVulkanTexture::createWithBlit(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height)
    {
        std::cerr << "[ThermionVk:Texture] createWithBlit " << width << "x" << height << std::endl;

        // === 1. Create render image (TILING_OPTIMAL, COLOR_ATTACHMENT) ===
        VkImageCreateInfo renderImageInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .pNext = nullptr,
            .flags = 0,
            .imageType = VK_IMAGE_TYPE_2D,
            .format = VK_FORMAT_R8G8B8A8_UNORM,
            .extent = {width, height, 1},
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = VK_SAMPLE_COUNT_1_BIT,
            .tiling = VK_IMAGE_TILING_OPTIMAL,
            .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
            .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
            .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        };

        VkImage renderImage;
        VkResult result = bluevk::vkCreateImage(device, &renderImageInfo, nullptr, &renderImage);
        if (result != VK_SUCCESS) {
            LOG_ERROR("Failed to create render VkImage: %s", VkResultToString(result));
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] Render image created (TILING_OPTIMAL)" << std::endl;

        // Allocate device-local memory for render image (no export needed)
        VkMemoryRequirements renderMemReqs;
        bluevk::vkGetImageMemoryRequirements(device, renderImage, &renderMemReqs);

        uint32_t renderMemTypeIdx = findOptimalMemoryType(
            physicalDevice, renderMemReqs.memoryTypeBits,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        if (renderMemTypeIdx == UINT32_MAX) {
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to find memory type for render image");
            return nullptr;
        }

        VkMemoryAllocateInfo renderAllocInfo = {
            .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = nullptr,
            .allocationSize = renderMemReqs.size,
            .memoryTypeIndex = renderMemTypeIdx
        };

        VkDeviceMemory renderMemory;
        result = bluevk::vkAllocateMemory(device, &renderAllocInfo, nullptr, &renderMemory);
        if (result != VK_SUCCESS) {
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to allocate render image memory: %s", VkResultToString(result));
            return nullptr;
        }

        result = bluevk::vkBindImageMemory(device, renderImage, renderMemory, 0);
        if (result != VK_SUCCESS) {
            bluevk::vkFreeMemory(device, renderMemory, nullptr);
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to bind render image memory");
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] Render image memory bound OK" << std::endl;

        // === 2. Create export image (DRM_FORMAT_MOD_LINEAR, TRANSFER_DST only) ===
        uint64_t linearModifier = DRM_FORMAT_MOD_LINEAR;

        VkImageDrmFormatModifierListCreateInfoEXT drmModListInfo = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
            .pNext = nullptr,
            .drmFormatModifierCount = 1,
            .pDrmFormatModifiers = &linearModifier
        };

        VkExternalMemoryImageCreateInfo extImageInfo = {
            .sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
            .pNext = &drmModListInfo,
            .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
        };

        VkImageCreateInfo exportImageInfo = {
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
            .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
            .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
            .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        };

        VkImage exportImage;
        result = bluevk::vkCreateImage(device, &exportImageInfo, nullptr, &exportImage);
        if (result != VK_SUCCESS) {
            bluevk::vkFreeMemory(device, renderMemory, nullptr);
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to create export VkImage: %s", VkResultToString(result));
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] Export image created (LINEAR)" << std::endl;

        // Allocate exportable memory for export image (DMA-BUF requires dedicated allocation)
        VkMemoryRequirements exportMemReqs;
        bluevk::vkGetImageMemoryRequirements(device, exportImage, &exportMemReqs);

        VkMemoryDedicatedAllocateInfo exportDedicatedAllocInfo = {
            .sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO,
            .pNext = nullptr,
            .image = exportImage,
            .buffer = VK_NULL_HANDLE
        };

        VkExportMemoryAllocateInfo exportAllocInfo = {
            .sType = VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO,
            .pNext = &exportDedicatedAllocInfo,
            .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
        };

        uint32_t exportMemTypeIdx = findOptimalMemoryType(
            physicalDevice, exportMemReqs.memoryTypeBits,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        if (exportMemTypeIdx == UINT32_MAX) {
            bluevk::vkDestroyImage(device, exportImage, nullptr);
            bluevk::vkFreeMemory(device, renderMemory, nullptr);
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to find memory type for export image");
            return nullptr;
        }

        VkMemoryAllocateInfo exportMemAllocInfo = {
            .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = &exportAllocInfo,
            .allocationSize = exportMemReqs.size,
            .memoryTypeIndex = exportMemTypeIdx
        };

        VkDeviceMemory exportMemory;
        result = bluevk::vkAllocateMemory(device, &exportMemAllocInfo, nullptr, &exportMemory);
        if (result != VK_SUCCESS) {
            bluevk::vkDestroyImage(device, exportImage, nullptr);
            bluevk::vkFreeMemory(device, renderMemory, nullptr);
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to allocate export image memory: %s", VkResultToString(result));
            return nullptr;
        }

        result = bluevk::vkBindImageMemory(device, exportImage, exportMemory, 0);
        if (result != VK_SUCCESS) {
            bluevk::vkFreeMemory(device, exportMemory, nullptr);
            bluevk::vkDestroyImage(device, exportImage, nullptr);
            bluevk::vkFreeMemory(device, renderMemory, nullptr);
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to bind export image memory");
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] Export image memory bound OK" << std::endl;

        // === 3. Export DMA-BUF fd from export image ===
        VkMemoryGetFdInfoKHR getFdInfo = {
            .sType = VK_STRUCTURE_TYPE_MEMORY_GET_FD_INFO_KHR,
            .pNext = nullptr,
            .memory = exportMemory,
            .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
        };

        int dmaBufFd = -1;
        result = bluevk::vkGetMemoryFdKHR(device, &getFdInfo, &dmaBufFd);
        if (result != VK_SUCCESS || dmaBufFd < 0) {
            bluevk::vkFreeMemory(device, exportMemory, nullptr);
            bluevk::vkDestroyImage(device, exportImage, nullptr);
            bluevk::vkFreeMemory(device, renderMemory, nullptr);
            bluevk::vkDestroyImage(device, renderImage, nullptr);
            LOG_ERROR("Failed to export dmabuf fd: %s", VkResultToString(result));
            return nullptr;
        }
        std::cerr << "[ThermionVk:Texture] Export dmabuf fd=" << dmaBufFd << std::endl;

        // Query stride from export image
        VkImageSubresource subresource = {
            .aspectMask = VK_IMAGE_ASPECT_MEMORY_PLANE_0_BIT_EXT,
            .mipLevel = 0,
            .arrayLayer = 0
        };
        VkSubresourceLayout layout;
        bluevk::vkGetImageSubresourceLayout(device, exportImage, &subresource, &layout);

        uint32_t stride = static_cast<uint32_t>(layout.rowPitch);
        uint32_t offset = static_cast<uint32_t>(layout.offset);
        uint32_t drmFormat = DRM_FORMAT_ABGR8888;

        std::cerr << "[ThermionVk:Texture] Created blit-mode texture: "
                  << width << "x" << height
                  << " fd=" << dmaBufFd
                  << " stride=" << stride
                  << " offset=" << offset
                  << " (render=TILING_OPTIMAL, export=LINEAR)"
                  << std::endl;

        // The base class _image/_imageMemory holds the export image (DMA-BUF).
        // _renderImage/_renderMemory holds the render target.
        auto tex = std::make_unique<LinuxVulkanTexture>(
            exportImage, device, exportMemory, width, height,
            dmaBufFd, stride, offset, drmFormat,
            exportMemReqs.size, exportMemReqs.memoryTypeBits,
            DRM_FORMAT_MOD_LINEAR);

        tex->_needsBlit = true;
        tex->_renderImage = renderImage;
        tex->_renderMemory = renderMemory;

        return tex;
    }

} // namespace thermion::vulkan::linux_platform
