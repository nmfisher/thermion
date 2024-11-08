
#define THERMION_WIN32_KHR_BUILD
#include "windows/vulkan/vulkan_context.h"

#include "ThermionWin32.h"

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

    _d3dContext = std::make_unique<thermion::windows::d3d::D3DContext>();

}

HANDLE ThermionVulkanContext::CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {

    Log("Creating Vulkan texture %dx%d", width, height);

    // creates the D3D texture
    auto d3dTexture = _d3dContext->CreateTexture(width, height);
    auto d3dTextureHandle = d3dTexture->GetTextureHandle();
    auto vkTexture = VulkanTexture::create(device, physicalDevice, width, height, d3dTextureHandle);


    // fillImageWithColor(device, commandPool, queue, image, VK_FORMAT_B8G8R8A8_UNORM, VK_IMAGE_LAYOUT_UNDEFINED,  // Current image layout
    //     { width, height, 1 }, // Image extent
    //     0.0f, 1.0f, 0.0f, 1.0f);    // Red color (RGBA))
    
    _d3dTextures.push_back(std::move(d3dTexture));
    _vulkanTextures.push_back(std::move(vkTexture));
    return d3dTextureHandle;
}

void ThermionVulkanContext::ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {
    
}
 
void ThermionVulkanContext::DestroyRenderingSurface(HANDLE handle) {

    _vulkanTextures.erase(std::remove_if(_vulkanTextures.begin(), _vulkanTextures.end(), [=](auto&& vkTexture) {
        return vkTexture->GetD3DTextureHandle() == handle;
    }));

    _d3dTextures.erase(std::remove_if(_d3dTextures.begin(), _d3dTextures.end(), [=](auto&& d3dTexture) {
        return d3dTexture->GetTextureHandle() == handle;
    }));
}

void ThermionVulkanContext::Flush() {
    // ?? what to do here
}

// Function to perform the blit operation
void ThermionVulkanContext::BlitFromSwapchain() {
    std::lock_guard lock(_platform->mutex);
    if(!_platform->_current || _d3dTextures.size() == 0) {
        return;
    }

    
    auto&& vkTexture = _vulkanTextures.back();
    auto image = vkTexture->GetImage();

    auto&& texture = _d3dTextures.back();

    auto height = texture->GetHeight();
    auto width = texture->GetWidth();

    auto bundle = _platform->getSwapChainBundle(_platform->_current);
    VkImage swapchainImage = bundle.colors[_platform->_currentColorIndex];
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

void ThermionVulkanContext::readPixelsFromImage(
    uint32_t width,
    uint32_t height,
    std::vector<uint8_t>& outPixels
) {

    auto&& vkTexture = _vulkanTextures.back();
    auto image = vkTexture->GetImage();
   
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
