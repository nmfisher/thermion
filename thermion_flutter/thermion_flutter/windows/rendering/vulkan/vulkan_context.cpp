#include "vulkan_context.h"

#include <functional>
#include <vector>
#include <chrono>
#include <string>
#include <fstream>
#include <iostream>
#include <memory>
#include <thread>

#include "filament/backend/platforms/VulkanPlatform.h"
#include "filament/Engine.h"
#include "filament/Renderer.h"
#include "filament/View.h"
#include "filament/Viewport.h"
#include "filament/Scene.h"
#include "filament/SwapChain.h"
#include "filament/Texture.h"

#include "Log.hpp"

namespace thermion::windows::vulkan {

using namespace bluevk;

ThermionVulkanContext::ThermionVulkanContext() {
    bluevk::initialize();

    // Create Vulkan instance
    VkResult result = createVulkanInstance(&instance);
    if (result != VK_SUCCESS)
    {
        std::cout << "[ERROR] Failed to create Vulkan instance! Error: " << VkResultToString(result) << std::endl;
        return;
    }
    bluevk::bindInstance(instance);

    result = createLogicalDevice(instance, &physicalDevice, &device);
    if (result != VK_SUCCESS)
     {
        std::cout << "[ERROR] Failed to create logical device! Error: " << VkResultToString(result) << std::endl;
        vkDestroyInstance(instance, nullptr);
        return;
    }

    uint32_t queueFamilyIndex;
    
    createDeviceWithGraphicsQueue(physicalDevice,queueFamilyIndex, &device);
    
    CommandResources cmdResources = createCommandResources(device, physicalDevice);

    commandPool = cmdResources.commandPool;
    queue = cmdResources.queue;

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
        .flags = 0
    };

    VkExternalImageFormatProperties externFormatProps = {
        .sType = VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES
    };

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
        return;
    }

    _platform = new TVulkanPlatform();

}

void ThermionVulkanContext::CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {

    Log("Creating Vulkan texture %dx%d", width, height);

    // creates the D3D texture
    _texture = new thermion::windows::d3d::D3DTexture(width, height);

    // Create image with external memory support
    VkExternalMemoryImageCreateInfo extImageInfo = {
        .sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
        .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT };

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
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED };

    VkResult result = vkCreateImage(device, &imageInfo, nullptr, &image);

    if (result != VK_SUCCESS)
    {
        std::cout << "Failed to create iamge " << std::endl;
        return;
    }

    VkMemoryDedicatedRequirements MemoryDedicatedRequirements{
        .sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_REQUIREMENTS,
        .pNext = nullptr };
    VkMemoryRequirements2 MemoryRequirements2{
        .sType = VK_STRUCTURE_TYPE_MEMORY_REQUIREMENTS_2,
        .pNext = &MemoryDedicatedRequirements };
    const VkImageMemoryRequirementsInfo2 ImageMemoryRequirementsInfo2{
        .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_REQUIREMENTS_INFO_2,
        .pNext = nullptr,
        .image = image };
    // WARN: Memory access violation unless validation instance layer is enabled, otherwise success but...
    vkGetImageMemoryRequirements2(device, &ImageMemoryRequirementsInfo2, &MemoryRequirements2);
    //       ... if we happen to be here, MemoryRequirements2 is empty
    VkMemoryRequirements& MemoryRequirements = MemoryRequirements2.memoryRequirements;

    const VkMemoryDedicatedAllocateInfo MemoryDedicatedAllocateInfo{
        .sType = VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO,
        .pNext = nullptr,
        .image = image,
        .buffer = VK_NULL_HANDLE };

    const VkImportMemoryWin32HandleInfoKHR ImportMemoryWin32HandleInfo{
        .sType = VK_STRUCTURE_TYPE_IMPORT_MEMORY_WIN32_HANDLE_INFO_KHR,
        .pNext = &MemoryDedicatedAllocateInfo,
        .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT,
        .handle = _texture->GetTextureHandle(),
        .name = nullptr };
    VkDeviceMemory ImageMemory = VK_NULL_HANDLE;

    // Find suitable memory type
    uint32_t memoryTypeIndex = findOptimalMemoryType(
        physicalDevice,
        MemoryRequirements.memoryTypeBits,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT     // You might need to adjust these flags
    );

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
        const char* errorMsg;
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

        return ;
    }

    const VkBindImageMemoryInfo bindImageMemoryInfo{
        .sType = VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO,
        .pNext = nullptr,
        .image = image,
        .memory = ImageMemory,
        .memoryOffset = 0 };

    result = vkBindImageMemory2(device, 1, &bindImageMemoryInfo);

    if (result != VK_SUCCESS)
    {
        std::cout << "vkBindImageMemory2 failed" << std::endl;
        return;
    }

    // fillImageWithColor(device, commandPool, queue, image, VK_FORMAT_B8G8R8A8_UNORM, VK_IMAGE_LAYOUT_UNDEFINED,  // Current image layout
    //     { width, height, 1 }, // Image extent
    //     0.0f, 1.0f, 0.0f, 1.0f);    // Red color (RGBA))

    return ;
}

void ThermionVulkanContext::ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {
    _inactive = std::move(_texture);
    CreateRenderingSurface(width, height, left, top);
}

void ThermionVulkanContext::DestroyRenderingSurface() {
    std::cout << "DESTROYING" << std::endl;
}

void ThermionVulkanContext::Flush() {
    // ?? what to do here
}

// Function to perform the blit operation
void ThermionVulkanContext::BlitFromSwapchain() {
    std::lock_guard lock(_platform->mutex);

    auto height = _texture->GetHeight();
    auto width = _texture->GetWidth();

    auto bundle = _platform->getSwapChainBundle(_platform->_current);
    VkImage swapchainImage = bundle.colors[0];
    // Command buffer allocation
    VkCommandBufferAllocateInfo cmdBufInfo{};
    cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cmdBufInfo.commandPool = commandPool;
    cmdBufInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cmdBufInfo.commandBufferCount = 1;

    VkCommandBuffer cmd;
    VkResult result = bluevk::vkAllocateCommandBuffers(device, &cmdBufInfo, &cmd);
    if (result != VK_SUCCESS) {
        std::cout << "Failed to allocate command buffer: " << result << std::endl;
        return;
    }

    // Begin command buffer
    VkCommandBufferBeginInfo beginInfo{};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    
    result = bluevk::vkBeginCommandBuffer(cmd, &beginInfo);
    if (result != VK_SUCCESS) {
        std::cout << "Failed to begin command buffer: " << result << std::endl;
        return;
    }

    // std::cout << "Starting blit operation..." << std::endl;
    
    // Pre-transition barriers
    VkImageMemoryBarrier srcBarrier{};
    srcBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    srcBarrier.srcAccessMask = VK_ACCESS_MEMORY_READ_BIT;
    srcBarrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    srcBarrier.oldLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
    srcBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    srcBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    srcBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    srcBarrier.image = swapchainImage;
    srcBarrier.subresourceRange = {
        VK_IMAGE_ASPECT_COLOR_BIT,
        0, 1, 0, 1
    };

    VkImageMemoryBarrier dstBarrier{};
    dstBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    dstBarrier.srcAccessMask = 0;
    dstBarrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    dstBarrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    dstBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    dstBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    dstBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    dstBarrier.image = image;
    dstBarrier.subresourceRange = {
        VK_IMAGE_ASPECT_COLOR_BIT,
        0, 1, 0, 1
    };

    // std::cout << "Transitioning images to transfer layouts..." << std::endl;

    // Pre-blit barriers
    VkImageMemoryBarrier preBlitBarriers[] = {srcBarrier, dstBarrier};
    vkCmdPipelineBarrier(
        cmd,
        VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,  // Changed from TRANSFER_BIT for better sync
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        0,
        0, nullptr,
        0, nullptr,
        2, preBlitBarriers
    );

    // Define blit region with bounds checking
    VkImageBlit blit{};
    blit.srcSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
    blit.srcOffsets[0] = {0, 0, 0};
    blit.srcOffsets[1] = {static_cast<int32_t>(width), static_cast<int32_t>(height), 1};
    blit.dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
    blit.dstOffsets[0] = {0, 0, 0};
    blit.dstOffsets[1] = {static_cast<int32_t>(width), static_cast<int32_t>(height), 1};

    // std::cout << "Executing blit command..." << std::endl;
    // std::cout << "Source dimensions: " << width << "x" << height << std::endl;
    // std::cout << "Destination dimensions: " << width << "x" << height << std::endl;

    // Perform blit with validation
    bluevk::vkCmdBlitImage(
        cmd,
        swapchainImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        1, &blit,
        VK_FILTER_NEAREST  // Changed to NEAREST for debugging
    );

    // Post-transition barriers
    srcBarrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    srcBarrier.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT;
    srcBarrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    srcBarrier.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    dstBarrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    dstBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    dstBarrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    dstBarrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

    // std::cout << "Transitioning images back to original layouts..." << std::endl;

    // Post-blit barriers
    VkImageMemoryBarrier postBlitBarriers[] = {srcBarrier, dstBarrier};
    bluevk::vkCmdPipelineBarrier(
        cmd,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,  // Changed for better sync
        0,
        0, nullptr,
        0, nullptr,
        2, postBlitBarriers
    );

    // End command buffer
    result = bluevk::vkEndCommandBuffer(cmd);
    if (result != VK_SUCCESS) {
        std::cout << "Failed to end command buffer: " << result << std::endl;
        return;
    }

    // Create fence for synchronization
    // VkFenceCreateInfo fenceInfo{};
    // fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    
    // VkFence fence;
    // result = bluevk::vkCreateFence(device, &fenceInfo, nullptr, &fence);
    // if (result != VK_SUCCESS) {
    //     std::cout << "Failed to create fence: " << result << std::endl;
    //     return;
    // }

    // // Submit with fence
    VkSubmitInfo submitInfo{};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &cmd;

    result = bluevk::vkQueueSubmit(queue, 1, &submitInfo, VK_NULL_HANDLE); //fence);
    if (result != VK_SUCCESS) {
        std::cout << "Failed to submit queue: " << result << std::endl;
        // bluevk::vkDestroyFence(device, fence, nullptr);
        return;
    }

    // // Wait for fence with timeout
    // result = bluevk::vkWaitForFences(device, 1, &fence, VK_TRUE, 5000000000); // 5 second timeout
    // if (result != VK_SUCCESS) {
    //     std::cout << "Failed to wait for fence: " << result << std::endl;
    //     vkDestroyFence(device, fence, nullptr);
    //     return;
    // }

    // std::cout << "Blit operation completed successfully" << std::endl;

    // // Cleanup
    // bluevk::vkDestroyFence(device, fence, nullptr);
    // bluevk::vkFreeCommandBuffers(device, commandPool, 1, &cmd);
}

// Helper function to find suitable memory type
uint32_t findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags properties, VkPhysicalDevice physicalDevice) {
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);
    
    for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
        if ((typeFilter & (1 << i)) && 
            (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
            return i;
        }
    }
    
    throw std::runtime_error("Failed to find suitable memory type");
}

void ThermionVulkanContext::readPixelsFromImage(
    uint32_t width,
    uint32_t height,
    std::vector<uint8_t>& outPixels
) {
   
    VkDeviceSize bufferSize = width * height * 4; // RGBA8 format
    
    // Create staging buffer
    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;
    
    VkBufferCreateInfo bufferInfo{};
    bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufferInfo.size = bufferSize;
    bufferInfo.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    
    VkResult result = bluevk::vkCreateBuffer(device, &bufferInfo, nullptr, &stagingBuffer);
    if (result != VK_SUCCESS) {
        throw std::runtime_error("Failed to create staging buffer");
    }
    
    // Get memory requirements and allocate
    VkMemoryRequirements memRequirements;
    bluevk::vkGetBufferMemoryRequirements(device, stagingBuffer, &memRequirements);
    
    VkMemoryAllocateInfo allocInfo{};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.allocationSize = memRequirements.size;
    allocInfo.memoryTypeIndex = findMemoryType(
        memRequirements.memoryTypeBits,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        physicalDevice
    );
    
    result = bluevk::vkAllocateMemory(device, &allocInfo, nullptr, &stagingBufferMemory);
    if (result != VK_SUCCESS) {
        bluevk::vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to allocate staging buffer memory");
    }
    
    result = bluevk::vkBindBufferMemory(device, stagingBuffer, stagingBufferMemory, 0);
    if (result != VK_SUCCESS) {
        vkFreeMemory(device, stagingBufferMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to bind buffer memory");
    }
    
    // Create command buffer
    VkCommandBufferAllocateInfo cmdBufAllocInfo{};
    cmdBufAllocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cmdBufAllocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cmdBufAllocInfo.commandPool = commandPool;
    cmdBufAllocInfo.commandBufferCount = 1;
    
    VkCommandBuffer commandBuffer;
    result = bluevk::vkAllocateCommandBuffers(device, &cmdBufAllocInfo, &commandBuffer);
    if (result != VK_SUCCESS) {
        throw std::runtime_error("Failed to allocate command buffer");
    }
    
    // Begin command buffer
    VkCommandBufferBeginInfo beginInfo{};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    
    result = bluevk::vkBeginCommandBuffer(commandBuffer, &beginInfo);
    if (result != VK_SUCCESS) {
        throw std::runtime_error("Failed to begin command buffer");
    }
    
    // Transition image layout for transfer with proper sync
    VkImageMemoryBarrier barrier{};
    barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.srcAccessMask = VK_ACCESS_MEMORY_READ_BIT;
    barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    barrier.oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL; // Assuming this is the current layout
    barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.image = image;
    barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier.subresourceRange.baseMipLevel = 0;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.baseArrayLayer = 0;
    barrier.subresourceRange.layerCount = 1;
    
    bluevk::vkCmdPipelineBarrier(
        commandBuffer,
        VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        0,
        0, nullptr,
        0, nullptr,
        1, &barrier
    );
    
    // Copy image to buffer
    VkBufferImageCopy region{};
    region.bufferOffset = 0;
    region.bufferRowLength = 0;
    region.bufferImageHeight = 0;
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.mipLevel = 0;
    region.imageSubresource.baseArrayLayer = 0;
    region.imageSubresource.layerCount = 1;
    region.imageOffset = {0, 0, 0};
    region.imageExtent = {width, height, 1};
    
    bluevk::vkCmdCopyImageToBuffer(
        commandBuffer,
        image,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        stagingBuffer,
        1,
        &region
    );
    
    // Transition image layout back
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    
    bluevk::vkCmdPipelineBarrier(
        commandBuffer,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
        0,
        0, nullptr,
        0, nullptr,
        1, &barrier
    );
    
    result = bluevk::vkEndCommandBuffer(commandBuffer);
    if (result != VK_SUCCESS) {
        throw std::runtime_error("Failed to end command buffer");
    }
    
    // Submit command buffer with fence for synchronization
    VkFenceCreateInfo fenceInfo{};
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    
    VkFence fence;
    result = bluevk::vkCreateFence(device, &fenceInfo, nullptr, &fence);
    if (result != VK_SUCCESS) {
        throw std::runtime_error("Failed to create fence");
    }
    
    VkSubmitInfo submitInfo{};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffer;
    
    result = bluevk::vkQueueSubmit(queue, 1, &submitInfo, fence);
    if (result != VK_SUCCESS) {
        bluevk::vkDestroyFence(device, fence, nullptr);
        throw std::runtime_error("Failed to submit queue");
    }
    
    // Wait for the command buffer to complete with timeout
    result = bluevk::vkWaitForFences(device, 1, &fence, VK_TRUE, 5000000000); // 5 second timeout
    if (result != VK_SUCCESS) {
        bluevk::vkDestroyFence(device, fence, nullptr);
        throw std::runtime_error("Failed to wait for fence");
    }
    
    // Map memory and copy data
    void* data;
    result = bluevk::vkMapMemory(device, stagingBufferMemory, 0, bufferSize, 0, &data);
    if (result != VK_SUCCESS) {
        throw std::runtime_error("Failed to map memory");
    }
    
    outPixels.resize(bufferSize);
    memcpy(outPixels.data(), data, bufferSize);
    bluevk::vkUnmapMemory(device, stagingBufferMemory);
    
    // Cleanup
    bluevk::vkDestroyFence(device, fence, nullptr);
    vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer);
    vkDestroyBuffer(device, stagingBuffer, nullptr);
    vkFreeMemory(device, stagingBufferMemory, nullptr);
    
    std::cout << "Successfully completed readPixelsFromImage" << std::endl;
}

}
