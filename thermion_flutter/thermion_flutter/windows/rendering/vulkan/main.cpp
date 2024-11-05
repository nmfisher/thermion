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


// Consolidated function for creating logical device
VkResult createLogicalDevice(VkInstance instance, VkPhysicalDevice *physicalDevice, VkDevice *device)
{
    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr);
    std::vector<VkPhysicalDevice> physicalDevices(deviceCount);
    vkEnumeratePhysicalDevices(instance, &deviceCount, physicalDevices.data());

    if (deviceCount == 0)
    {
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    *physicalDevice = physicalDevices[0];

    std::vector<const char *> deviceExtensions = {
        VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME,
        VK_KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME};

    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueCreateInfo = {};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = 0;
    queueCreateInfo.queueCount = 1;
    queueCreateInfo.pQueuePriorities = &queuePriority;

    VkDeviceCreateInfo deviceCreateInfo = {};
    deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    deviceCreateInfo.queueCreateInfoCount = 1;
    deviceCreateInfo.pQueueCreateInfos = &queueCreateInfo;
    deviceCreateInfo.enabledExtensionCount = static_cast<uint32_t>(deviceExtensions.size());
    deviceCreateInfo.ppEnabledExtensionNames = deviceExtensions.data();

    return vkCreateDevice(*physicalDevice, &deviceCreateInfo, nullptr, device);
}

// Example usage with device creation
void createDeviceWithGraphicsQueue(VkPhysicalDevice physicalDevice, uint32_t& queueFamilyIndex, VkDevice* device) {
    // Find queue family index
    queueFamilyIndex = findGraphicsQueueFamily(physicalDevice);
    
    // Specify queue creation
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueCreateInfo{};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = queueFamilyIndex;
    queueCreateInfo.queueCount = 1;
    queueCreateInfo.pQueuePriorities = &queuePriority;
    
    // Specify device features
    VkPhysicalDeviceFeatures deviceFeatures{};
    
    // Create logical device
    VkDeviceCreateInfo createInfo{};
    createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    createInfo.pQueueCreateInfos = &queueCreateInfo;
    createInfo.queueCreateInfoCount = 1;
    createInfo.pEnabledFeatures = &deviceFeatures;
    
    if (vkCreateDevice(physicalDevice, &createInfo, nullptr, device) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create logical device");
    }
}

void readVkImageToBitmap(
    VkPhysicalDevice physicalDevice,
    VkDevice device,
    VkCommandPool commandPool,
    VkQueue queue,
    VkImage sourceImage,
    uint32_t width,
    uint32_t height,
    const char* outputPath
) {
    // Create staging buffer for reading pixel data
    VkBufferCreateInfo bufferInfo{};
    bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufferInfo.size = width * height * 4; // Assuming RGBA8 format
    bufferInfo.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    VkBuffer stagingBuffer;
    VkResult result = vkCreateBuffer(device, &bufferInfo, nullptr, &stagingBuffer);
    if (result != VK_SUCCESS) {
        throw std::runtime_error("Failed to create staging buffer");
    }

    // Get memory requirements and properties
    VkMemoryRequirements memRequirements;
    vkGetBufferMemoryRequirements(device, stagingBuffer, &memRequirements);

    // Get physical device memory properties
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

    // Find suitable memory type index
    uint32_t memoryTypeIndex = -1;
    for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
        if ((memRequirements.memoryTypeBits & (1 << i)) &&
            (memProperties.memoryTypes[i].propertyFlags &
                (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) ==
            (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) {
            memoryTypeIndex = i;
            break;
        }
    }

    if (memoryTypeIndex == -1) {
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to find suitable memory type");
    }

    // Allocate memory
    VkMemoryAllocateInfo allocInfo{};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.allocationSize = memRequirements.size;
    allocInfo.memoryTypeIndex = memoryTypeIndex;

    VkDeviceMemory stagingMemory;
    result = vkAllocateMemory(device, &allocInfo, nullptr, &stagingMemory);
    if (result != VK_SUCCESS) {
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to allocate staging memory");
    }

    // Bind memory to buffer
    result = vkBindBufferMemory(device, stagingBuffer, stagingMemory, 0);
    if (result != VK_SUCCESS) {
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to bind buffer memory");
    }

    // Create command buffer
    VkCommandBufferAllocateInfo cmdBufInfo{};
    cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cmdBufInfo.commandPool = commandPool;
    cmdBufInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cmdBufInfo.commandBufferCount = 1;

    VkCommandBuffer cmdBuffer;
    result = vkAllocateCommandBuffers(device, &cmdBufInfo, &cmdBuffer);
    if (result != VK_SUCCESS) {
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to allocate command buffer");
    }

    // Begin command buffer
    VkCommandBufferBeginInfo beginInfo{};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

    result = vkBeginCommandBuffer(cmdBuffer, &beginInfo);
    if (result != VK_SUCCESS) {
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to begin command buffer");
    }

    // Transition image layout for transfer
    VkImageMemoryBarrier imageBarrier{};
    imageBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    imageBarrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED; // Adjust based on current layout
    imageBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    imageBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    imageBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    imageBarrier.image = sourceImage;
    imageBarrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    imageBarrier.subresourceRange.baseMipLevel = 0;
    imageBarrier.subresourceRange.levelCount = 1;
    imageBarrier.subresourceRange.baseArrayLayer = 0;
    imageBarrier.subresourceRange.layerCount = 1;
    imageBarrier.srcAccessMask = 0;
    imageBarrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;

    vkCmdPipelineBarrier(
        cmdBuffer,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        0,
        0, nullptr,
        0, nullptr,
        1, &imageBarrier
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
    region.imageOffset = { 0, 0, 0 };
    region.imageExtent = { width, height, 1 };

    vkCmdCopyImageToBuffer(
        cmdBuffer,
        sourceImage,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        stagingBuffer,
        1,
        &region
    );

    // Add memory barrier to ensure the transfer is complete before reading
    VkMemoryBarrier memBarrier{};
    memBarrier.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
    memBarrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    memBarrier.dstAccessMask = VK_ACCESS_HOST_READ_BIT;

    vkCmdPipelineBarrier(
        cmdBuffer,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_PIPELINE_STAGE_HOST_BIT,
        0,
        1, &memBarrier,
        0, nullptr,
        0, nullptr
    );

    // End command buffer
    result = vkEndCommandBuffer(cmdBuffer);
    if (result != VK_SUCCESS) {
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to end command buffer");
    }

    // Submit command buffer
    VkSubmitInfo submitInfo{};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &cmdBuffer;

    // Create fence to ensure command buffer has finished executing
    VkFenceCreateInfo fenceInfo{};
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;

    VkFence fence;
    result = vkCreateFence(device, &fenceInfo, nullptr, &fence);
    if (result != VK_SUCCESS) {
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to create fence");
    }

    // Submit with fence
    result = vkQueueSubmit(queue, 1, &submitInfo, fence);
    if (result != VK_SUCCESS) {
        vkDestroyFence(device, fence, nullptr);
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to submit queue");
    }

    // Wait for the command buffer to complete execution
    result = vkWaitForFences(device, 1, &fence, VK_TRUE, UINT64_MAX);
    if (result != VK_SUCCESS) {
        vkDestroyFence(device, fence, nullptr);
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to wait for fence");
    }

    // Now safe to map memory and read data
    void* data;
    result = vkMapMemory(device, stagingMemory, 0, bufferInfo.size, 0, &data);
    if (result != VK_SUCCESS) {
        vkDestroyFence(device, fence, nullptr);
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to map memory");
    }

    // Create bitmap header
    BMPHeader header{};
    header.signature = 0x4D42;  // "BM"
    header.fileSize = sizeof(BMPHeader) + width * height * 3;  // 3 bytes per pixel (BGR)
    header.dataOffset = sizeof(BMPHeader);
    header.headerSize = 40;
    header.width = width;
    header.height = height;
    header.planes = 1;
    header.bitsPerPixel = 24;
    header.compression = 0;
    header.imageSize = width * height * 3;
    

    //// Write to file
    std::ofstream file(outputPath, std::ios::binary);
    if (!file.is_open()) {
        vkUnmapMemory(device, stagingMemory);
        vkDestroyFence(device, fence, nullptr);
        vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
        vkFreeMemory(device, stagingMemory, nullptr);
        vkDestroyBuffer(device, stagingBuffer, nullptr);
        throw std::runtime_error("Failed to open output file");
    }

    file.write(reinterpret_cast<char*>(&header), sizeof(header));

    // Convert RGBA to BGR and write pixel data
    uint8_t* pixels = reinterpret_cast<uint8_t*>(data);
    std::vector<uint8_t> bgrData(width * height * 3);

    for (uint32_t y = 0; y < height; y++) {
        for (uint32_t x = 0; x < width; x++) {
            uint32_t srcIdx = (y * width + x) * 4;  // RGBA has 4 components
            uint32_t dstIdx = ((height - 1 - y) * width + x) * 3;  // Flip vertically

            // RGBA to BGR conversion
            bgrData[dstIdx + 0] = pixels[srcIdx + 0];  
            bgrData[dstIdx + 1] = pixels[srcIdx + 1];  
            bgrData[dstIdx + 2] = pixels[srcIdx + 2];  
        }
    }

    file.write(reinterpret_cast<char*>(bgrData.data()), bgrData.size());
    file.close();
    
    // Cleanup
    vkUnmapMemory(device, stagingMemory);
    vkDestroyFence(device, fence, nullptr);
    vkFreeCommandBuffers(device, commandPool, 1, &cmdBuffer);
    vkFreeMemory(device, stagingMemory, nullptr);
    vkDestroyBuffer(device, stagingBuffer, nullptr);
}

int main()
{
    VkInstance instance = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    VkImage image = VK_NULL_HANDLE;
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

    texture.FillBlueAndSaveToBMP("output.bmp");
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
    texture.FillBlueAndSaveToBMP("output.bmp");
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

    readVkImageToBitmap(physicalDevice, device, commandPool, queue, image, width, height, "vulkan.bmp");

    // Cleanup
    std::cout << "\n[Step 6] Cleaning up resources..." << std::endl;
    vkDestroyImage(device, image, nullptr);
    // vkFreeMemory(device, memory, nullptr);
    vkDestroyDevice(device, nullptr);
    vkDestroyInstance(instance, nullptr);
    std::cout << "[Complete] All resources cleaned up successfully" << std::endl;

    return 0;
}
