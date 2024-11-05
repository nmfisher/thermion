#include "d3d_texture.h"
#include "utils.h"

#include <iostream>
#include <thread>
#include <chrono>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_win32.h>
#include <vector>
#include <string>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory>
#include <thread>

int main()
{
    
    HANDLE sharedHandle = nullptr;

    uint32_t height = 100;
    uint32_t width = 100;

    std::cout << "[Step 1] Initializing D3D texture..." << std::endl;
    thermion::windows::d3d::D3DTexture texture(width, height, [=](size_t width, size_t height) {});

    sharedHandle = texture.GetTextureHandle();
    if (!sharedHandle)
    {
        std::cout << "[ERROR] Failed to get shared texture handle!" << std::endl;
        return 1;
    }

    texture.SaveToBMP("output0.bmp");
    std::cout << "[Info] Filled texture with blue and saved to output.bmp" << std::endl;

    // Create Vulkan instance
    VkResult result = createVulkanInstance(&instance);
    if (result != VK_SUCCESS)
    {
        std::cout << "[ERROR] Failed to create Vulkan instance! Error: " << VkResultToString(result) << std::endl;
        return 1;
    }

    result = createLogicalDevice(instance, &physicalDevice, &device);
    if (result != VK_SUCCESS)
     {
        std::cout << "[ERROR] Failed to create logical device! Error: " << VkResultToString(result) << std::endl;
        vkDestroyInstance(instance, nullptr);
        return 1;
    }

    uint32_t queueFamilyIndex;
    
    createDeviceWithGraphicsQueue(physicalDevice,queueFamilyIndex, &device);
    
    CommandResources cmdResources = createCommandResources(device, physicalDevice);

    VkCommandPool commandPool = cmdResources.commandPool;
    VkQueue queue = cmdResources.queue;


    // In main(), after creating both D3D11 and Vulkan devices:
    texture.SaveToBMP("output1.bmp");
    if (!checkD3D11VulkanInterop(physicalDevice, texture._D3D11Device))
    {
        std::cout << "D3D11-Vulkan interop is not supported in this QEMU environment" << std::endl;
        // Consider falling back to a different approach
        return 1;
    }

    VkPhysicalDeviceExternalImageFormatInfo externFormatInfo = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
        .pNext = nullptr,
        .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT};

    VkPhysicalDeviceImageFormatInfo2 formatInfo = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
        .pNext = &externFormatInfo,
        .format = VK_FORMAT_R8G8B8A8_UNORM,
        .type = VK_IMAGE_TYPE_2D,
        .tiling = VK_IMAGE_TILING_OPTIMAL,                                      // Changed to LINEAR for VM compatibility
        .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT, // Simplified usage flags
        .flags = 0};

    VkExternalImageFormatProperties externFormatProps = {
        .sType = VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES};

    VkImageFormatProperties2 formatProps = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2,
        .pNext = &externFormatProps};

    // Query supported features
    result = vkGetPhysicalDeviceImageFormatProperties2(
        physicalDevice,
        &formatInfo,
        &formatProps);

    if (result != VK_SUCCESS)
    {
        std::cout << "VM environment may not support required external memory features" << std::endl;
        return 1;
    }

    std::cout << "VM environment supports required external memory features" << std::endl;

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
        .tiling = VK_IMAGE_TILING_OPTIMAL,                                      // Changed to LINEAR for VM
        .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT, // Simplified usage
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED};

    result = vkCreateImage(device, &imageInfo, nullptr, &image);

    if (result != VK_SUCCESS)
    {
        std::cout << "Failed to create iamge " << std::endl;
        return 1;
    }
    
    std::cout << "Successfully created image " << std::endl;

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
    vkGetImageMemoryRequirements2(device, &ImageMemoryRequirementsInfo2, &MemoryRequirements2);
    //       ... if we happen to be here, MemoryRequirements2 is empty
    VkMemoryRequirements &MemoryRequirements = MemoryRequirements2.memoryRequirements;
    std::cout << "Got mem reqs " << std::endl;

    const VkMemoryDedicatedAllocateInfo MemoryDedicatedAllocateInfo{
        .sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO,
        .pNext = nullptr,
        .image = image,
        .buffer = VK_NULL_HANDLE};
    const VkImportMemoryWin32HandleInfoKHR ImportMemoryWin32HandleInfo{
        .sType = VK_STRUCTURE_TYPE_IMPORT_MEMORY_WIN32_HANDLE_INFO_KHR,
        .pNext = &MemoryDedicatedAllocateInfo,
        .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT,
        .handle = sharedHandle,
        .name = nullptr};
    VkDeviceMemory ImageMemory = VK_NULL_HANDLE;

    // Find suitable memory type
    uint32_t memoryTypeIndex = findOptimalMemoryType(
        physicalDevice,
        MemoryRequirements.memoryTypeBits,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT     // You might need to adjust these flags
    );

    std::cout << "memoryTypeIndex" << memoryTypeIndex << std::endl;

    VkMemoryAllocateInfo allocInfo{
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = &ImportMemoryWin32HandleInfo,
        .allocationSize = MemoryRequirements.size,
        .memoryTypeIndex = memoryTypeIndex // Assuming 'properties' is your memory type index
    };

    VkResult allocResult = vkAllocateMemory(device, &allocInfo, nullptr, &ImageMemory);
    if (allocResult != VK_SUCCESS || ImageMemory == VK_NULL_HANDLE)
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

        // Print shared handle info
        std::cout << "  Shared handle value: " << sharedHandle << std::endl;

        // Print memory requirements
        std::cout << "  Memory requirements:" << std::endl;
        std::cout << "    Size: " << MemoryRequirements.size << std::endl;
        std::cout << "    Alignment: " << MemoryRequirements.alignment << std::endl;
        std::cout << "    Memory type bits: 0x" << std::hex << MemoryRequirements.memoryTypeBits << std::dec << std::endl;

        return 1;
    }

    // memAllocator->Allocate(MemoryRequirements, &ImageMemory, properties, &ImportMemoryWin32HandleInfo);
    // if(ImageMemory == VK_NULL_HANDLE) {
    //     std::cout << "IMAGE MEMORY ALLOCATION FAILED" << std::endl;
    //     return;
    // }

    const VkBindImageMemoryInfo bindImageMemoryInfo{
        .sType = VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO,
        .pNext = nullptr,
        .image = image,
        .memory = ImageMemory,
        .memoryOffset = 0};

    result = vkBindImageMemory2(device, 1, &bindImageMemoryInfo);

    if (result != VK_SUCCESS)
    {
        std::cout << "bindimagememory2 failed" << std::endl;
    }
    std::cout << "FIISHED" << std::endl;

    fillImageWithColor(device, commandPool, queue, image, VK_FORMAT_B8G8R8A8_UNORM, VK_IMAGE_LAYOUT_UNDEFINED,  // Current image layout
        { width, height, 1 }, // Image extent
        0.0f, 1.0f, 0.0f, 1.0f);    // Red color (RGBA))

    readVkImageToBitmap(physicalDevice, device, commandPool, queue, image, width, height, "vulkan.bmp");

    texture.SaveToBMP("output2.bmp");

    // Cleanup
    std::cout << "\n[Step 6] Cleaning up resources..." << std::endl;
    vkDestroyImage(device, image, nullptr);
    // vkFreeMemory(device, memory, nullptr);
    vkDestroyDevice(device, nullptr);
    vkDestroyInstance(instance, nullptr);
    std::cout << "[Complete] All resources cleaned up successfully" << std::endl;

    return 0;
}
