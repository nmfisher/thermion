#include "vulkan/windows/WindowsVulkanTexture.h"
#include "bluevk/BlueVK.h"
#include "vulkan/VulkanUtils.h"
#include "Log.hpp"
#include <iostream>
#include <cstring>

namespace thermion::vulkan::windows
{

// Import utility functions from base vulkan namespace
using ::thermion::vulkan::findOptimalMemoryType;

    WindowsVulkanTexture::WindowsVulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory,
                                 uint32_t width, uint32_t height, HANDLE d3dTextureHandle)
        : BaseVulkanTexture(image, device, imageMemory, width, height),
          _d3dTextureHandle(d3dTextureHandle) {}

    WindowsVulkanTexture::~WindowsVulkanTexture() {
        if (_image != VK_NULL_HANDLE || _imageMemory != VK_NULL_HANDLE) {
            destroyResources(true);
        }
    }


#ifdef _WIN32
    std::unique_ptr<WindowsVulkanTexture> WindowsVulkanTexture::create(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height,
        HANDLE d3dTextureHandle)
    {
        // Import the shared D3D11 RGBA8 texture directly as a renderable,
        // sampleable Vulkan image so Filament renders zero-copy into the
        // surface Flutter composites.
        VkExternalMemoryImageCreateInfo extImageInfo = {
            .sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
            .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT};

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
            .tiling = VK_IMAGE_TILING_OPTIMAL,
            .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                     VK_IMAGE_USAGE_TRANSFER_DST_BIT |
                     VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                     VK_IMAGE_USAGE_SAMPLED_BIT,
            .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
            .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED};

        VkImage image = VK_NULL_HANDLE;

        VkResult result = bluevk::vkCreateImage(device, &imageInfo, nullptr, &image);

        if (result != VK_SUCCESS)
        {
            std::cout << "Failed to create image " << std::endl;
            return nullptr;
        }

        std::cout << "Created vkImage " << (int64_t)image << std::endl;

        VkMemoryDedicatedRequirements MemoryDedicatedRequirements{
            .sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_REQUIREMENTS,
            .pNext = nullptr};
        VkMemoryRequirements2 MemoryRequirements2{
            .sType = VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2,
            .pNext = &MemoryDedicatedRequirements};
        const VkImageMemoryRequirementsInfo2 ImageMemoryRequirementsInfo2{
            .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2,
            .pNext = nullptr,
            .image = image};

        bluevk::vkGetImageMemoryRequirements2(device, &ImageMemoryRequirementsInfo2, &MemoryRequirements2);
        VkMemoryRequirements &MemoryRequirements = MemoryRequirements2.memoryRequirements;

        const VkMemoryDedicatedAllocateInfo MemoryDedicatedAllocateInfo{
            .sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO,
            .pNext = nullptr,
            .image = image,
            .buffer = VK_NULL_HANDLE};

        const VkImportMemoryWin32HandleInfoKHR ImportMemoryWin32HandleInfo{
            .sType = VK_STRUCTURE_TYPE_IMPORT_MEMORY_WIN32_HANDLE_INFO_KHR,
            .pNext = &MemoryDedicatedAllocateInfo,
            .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT,
            .handle = d3dTextureHandle,
            .name = nullptr};

        uint32_t memoryTypeIndex = findOptimalMemoryType(
            physicalDevice,
            MemoryRequirements.memoryTypeBits,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        );
        if (memoryTypeIndex == UINT32_MAX) {
            bluevk::vkDestroyImage(device, image, nullptr);
            ERROR("Failed to find suitable memory type for D3D11 interop image");
            return nullptr;
        }

        VkMemoryAllocateInfo allocInfo{
            .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = &ImportMemoryWin32HandleInfo,
            .allocationSize = MemoryRequirements.size,
            .memoryTypeIndex = memoryTypeIndex
        };

        VkDeviceMemory imageMemory = VK_NULL_HANDLE;

        VkResult allocResult = bluevk::vkAllocateMemory(device, &allocInfo, nullptr, &imageMemory);
        if(imageMemory == VK_NULL_HANDLE) {
            ERROR("imageMemory == VK_NULL_HANDLE");
        }
        if (allocResult != VK_SUCCESS || imageMemory == VK_NULL_HANDLE)
        {
            std::cout << "IMAGE MEMORY ALLOCATION FAILED:" << std::endl;
            std::cout << "  Allocation size: " << MemoryRequirements.size << " bytes" << std::endl;
            std::cout << "  Memory type index: " << allocInfo.memoryTypeIndex << std::endl;
            std::cout << "  Error code: " << allocResult << std::endl;

            const char *errorMsg;
            switch (allocResult)
            {
            case VK_ERROR_OUT_OF_HOST_MEMORY:
                errorMsg = "VK_ERROR_OUT_OF_HOST_MEMORY: Out of host memory";
                break;
            case VK_ERROR_OUT_OF_DEVICE_MEMORY:
                errorMsg = "VK_ERROR_OUT_OF_DEVICE_MEMORY: Out of device memory";
                break;
            case VK_ERROR_INVALID_EXTERNAL_HANDLE:
                errorMsg = "VK_ERROR_INVALID_EXTERNAL_HANDLE: The external handle is invalid";
                break;
            case VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS:
                errorMsg = "VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS: The requested address is not available";
                break;
            default:
                errorMsg = "Unknown error";
            }
            std::cout << "  Error message: " << errorMsg << std::endl;

            std::cout << "  Memory requirements:" << std::endl;
            std::cout << "    Size: " << MemoryRequirements.size << std::endl;
            std::cout << "    Alignment: " << MemoryRequirements.alignment << std::endl;
            std::cout << "    Memory type bits: 0x" << std::hex << MemoryRequirements.memoryTypeBits << std::dec << std::endl;

            bluevk::vkDestroyImage(device, image, nullptr);
            return nullptr;
        }

        const VkBindImageMemoryInfo bindImageMemoryInfo{
            .sType = VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO,
            .pNext = nullptr,
            .image = image,
            .memory = imageMemory,
            .memoryOffset = 0};

        result = bluevk::vkBindImageMemory2(device, 1, &bindImageMemoryInfo);

        if (result != VK_SUCCESS)
        {
            std::cout << "vkBindImageMemory2 failed" << std::endl;
            bluevk::vkFreeMemory(device, imageMemory, nullptr);
            bluevk::vkDestroyImage(device, image, nullptr);
            return nullptr;
        }
        return std::make_unique<WindowsVulkanTexture>(image, device, imageMemory, width, height, d3dTextureHandle);
    }
#else
    std::unique_ptr<WindowsVulkanTexture> WindowsVulkanTexture::create(
        VkDevice device,
        VkPhysicalDevice physicalDevice,
        uint32_t width,
        uint32_t height,
        HANDLE d3dTextureHandle) {
        return nullptr;
    }
#endif

} // namespace thermion::vulkan::windows
