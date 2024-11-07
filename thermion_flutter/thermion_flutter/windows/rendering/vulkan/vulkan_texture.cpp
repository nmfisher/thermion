#include "vulkan_texture.h"
#include "bluevk/BlueVK.h"
#include "utils.h"

#include <iostream>

namespace thermion::windows::vulkan
{

    VulkanTexture::VulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory, uint32_t width, uint32_t height, HANDLE d3dTextureHandle) : _image(image), _device(device),  _imageMemory(imageMemory), _width(width), _height(height), _d3dTextureHandle(d3dTextureHandle) {};

    VulkanTexture::~VulkanTexture() {
        bluevk::vkDeviceWaitIdle(_device);
        if(_image != VK_NULL_HANDLE) {
            bluevk::vkDestroyImage(_device, _image, nullptr);
        } else { 
            std::cout << "Warning : no vkImage found" << std::endl;
        }

        // https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/VkImportMemoryWin32HandleInfoKHR.html
        // imageMemory has been imported from D3D without transferring ownership
        // therefore we don't need to release
    }         
    

    std::unique_ptr<VulkanTexture> VulkanTexture::create(VkDevice device, VkPhysicalDevice physicalDevice, uint32_t width, uint32_t height, HANDLE d3dTextureHandle)
    {
        // Create image with external memory support
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
            .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT, 
            .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
            .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED};

        VkImage image;

        VkResult result = bluevk::vkCreateImage(device, &imageInfo, nullptr, &image);

        if (result != VK_SUCCESS)
        {
            std::cout << "Failed to create iamge " << std::endl;
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
        // WARN: Memory access violation unless validation instance layer is enabled, otherwise success but...
        bluevk::vkGetImageMemoryRequirements2(device, &ImageMemoryRequirementsInfo2, &MemoryRequirements2);
        //       ... if we happen to be here, MemoryRequirements2 is empty
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

        // Find suitable memory type
        uint32_t memoryTypeIndex = findOptimalMemoryType(
            physicalDevice,
            MemoryRequirements.memoryTypeBits,
            VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT 
        );

        VkMemoryAllocateInfo allocInfo{
            .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = &ImportMemoryWin32HandleInfo,
            .allocationSize = MemoryRequirements.size,
            .memoryTypeIndex = memoryTypeIndex 
        };

        VkDeviceMemory imageMemory = VK_NULL_HANDLE;

        VkResult allocResult = bluevk::vkAllocateMemory(device, &allocInfo, nullptr, &imageMemory);
        if (allocResult != VK_SUCCESS || imageMemory == VK_NULL_HANDLE)
        {
            std::cout << "IMAGE MEMORY ALLOCATION FAILED:" << std::endl;
            std::cout << "  Allocation size: " << MemoryRequirements.size << " bytes" << std::endl;
            std::cout << "  Memory type index: " << allocInfo.memoryTypeIndex << std::endl;
            std::cout << "  Error code: " << allocResult << std::endl;

            // Get more detailed error message based on VkResult
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

            // Print memory requirements
            std::cout << "  Memory requirements:" << std::endl;
            std::cout << "    Size: " << MemoryRequirements.size << std::endl;
            std::cout << "    Alignment: " << MemoryRequirements.alignment << std::endl;
            std::cout << "    Memory type bits: 0x" << std::hex << MemoryRequirements.memoryTypeBits << std::dec << std::endl;

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
            return nullptr;
        }
        return std::make_unique<VulkanTexture>(image, device, imageMemory, width, height, d3dTextureHandle);
    }
}