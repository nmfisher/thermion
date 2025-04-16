#include "vulkan_utils.h"

#include <fstream>

#include <iostream>
#include <thread>
#include <chrono>
#include <vector>
#include <string>

#include <functional>
#include <iostream>
#include <memory>
#include <thread>

#include "ThermionWin32.h"
#include <Windows.h>

using namespace bluevk;

// Helper function to convert VkResult to string for error reporting
const char *VkResultToString(VkResult result)
{
    switch (result)
    {
    case VK_SUCCESS:
        return "VK_SUCCESS";
    case VK_ERROR_OUT_OF_HOST_MEMORY:
        return "VK_ERROR_OUT_OF_HOST_MEMORY";
    case VK_ERROR_OUT_OF_DEVICE_MEMORY:
        return "VK_ERROR_OUT_OF_DEVICE_MEMORY";
    case VK_ERROR_INITIALIZATION_FAILED:
        return "VK_ERROR_INITIALIZATION_FAILED";
    case VK_ERROR_LAYER_NOT_PRESENT:
        return "VK_ERROR_LAYER_NOT_PRESENT";
    case VK_ERROR_EXTENSION_NOT_PRESENT:
        return "VK_ERROR_EXTENSION_NOT_PRESENT";
    default:
        return "UNKNOWN_ERROR";
    }
}



// bool checkD3D11VulkanInterop(VkPhysicalDevice physicalDevice, ID3D11Device *d3dDevice)
// {
//     std::cout << "\n=== Checking D3D11-Vulkan Interop Support in QEMU ===" << std::endl;

//     // Check Vulkan external memory capabilities
//     VkPhysicalDeviceExternalImageFormatInfo externFormatInfo = {
//         .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
//         .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT};

//     VkPhysicalDeviceImageFormatInfo2 formatInfo = {
//         .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
//         .pNext = &externFormatInfo,
//         .format = VK_FORMAT_R8G8B8A8_UNORM,
//         .type = VK_IMAGE_TYPE_2D,
//         .tiling = VK_IMAGE_TILING_OPTIMAL,
//         .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
//         .flags = 0};

//     VkExternalImageFormatProperties externFormatProps = {
//         .sType = VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES};

//     VkImageFormatProperties2 formatProps = {
//         .sType = VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2,
//         .pNext = &externFormatProps};

//     // Check device properties
//     VkPhysicalDeviceProperties deviceProps;
//     vkGetPhysicalDeviceProperties(physicalDevice, &deviceProps);

//     std::cout << "Vulkan Device: " << deviceProps.deviceName << std::endl;
//     std::cout << "Driver Version: " << deviceProps.driverVersion << std::endl;
//     std::cout << "API Version: " << VK_VERSION_MAJOR(deviceProps.apiVersion) << "." << VK_VERSION_MINOR(deviceProps.apiVersion) << "." << VK_VERSION_PATCH(deviceProps.apiVersion) << std::endl;

//     // Check D3D11 device capabilities
//     D3D11_FEATURE_DATA_D3D11_OPTIONS3 featureData = {};
//     HRESULT hr = d3dDevice->CheckFeatureSupport(
//         D3D11_FEATURE_D3D11_OPTIONS3,
//         &featureData,
//         sizeof(featureData));

//     std::cout << "\nChecking D3D11 Device:" << std::endl;

//     // Get D3D11 device information
//     IDXGIDevice *dxgiDevice = nullptr;
//     hr = d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void **)&dxgiDevice);
//     if (SUCCEEDED(hr))
//     {
//         IDXGIAdapter *adapter = nullptr;
//         hr = dxgiDevice->GetAdapter(&adapter);
//         if (SUCCEEDED(hr))
//         {
//             DXGI_ADAPTER_DESC desc;
//             adapter->GetDesc(&desc);
//             std::wcout << L"D3D11 Adapter: " << desc.Description << std::endl;
//             adapter->Release();
//         }
//         dxgiDevice->Release();
//     }

//     // Check for external memory support
//     VkResult result = vkGetPhysicalDeviceImageFormatProperties2(
//         physicalDevice,
//         &formatInfo,
//         &formatProps);

//     std::cout << "\nInterop Support Details:" << std::endl;

//     // Check external memory extension
//     uint32_t extensionCount = 0;
//     vkEnumerateDeviceExtensionProperties(physicalDevice, nullptr, &extensionCount, nullptr);
//     std::vector<VkExtensionProperties> extensions(extensionCount);
//     vkEnumerateDeviceExtensionProperties(physicalDevice, nullptr, &extensionCount, extensions.data());

//     bool hasExternalMemoryExt = false;
//     bool hasWin32Ext = false;

//     for (const auto &ext : extensions)
//     {
//         if (strcmp(ext.extensionName, VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME) == 0)
//         {
//             hasExternalMemoryExt = true;
//         }
//         if (strcmp(ext.extensionName, VK_KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME) == 0)
//         {
//             hasWin32Ext = true;
//         }
//     }

//     std::cout << "External Memory Extension: " << (hasExternalMemoryExt ? "Yes" : "No") << std::endl;
//     std::cout << "Win32 External Memory Extension: " << (hasWin32Ext ? "Yes" : "No") << std::endl;
//     std::cout << "Format Properties Check: " << (result == VK_SUCCESS ? "Passed" : "Failed") << std::endl;

//     // Check memory properties
//     VkPhysicalDeviceMemoryProperties memProps;
//     vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProps);

//     std::cout << "\nMemory Types Available:" << std::endl;
//     for (uint32_t i = 0; i < memProps.memoryTypeCount; i++)
//     {
//         VkMemoryPropertyFlags flags = memProps.memoryTypes[i].propertyFlags;
//         std::cout << "Type " << i << ": ";
//         if (flags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
//             std::cout << "Device Local ";
//         if (flags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)
//             std::cout << "Host Visible ";
//         if (flags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
//             std::cout << "Host Coherent ";
//         if (flags & VK_MEMORY_PROPERTY_HOST_CACHED_BIT)
//             std::cout << "Host Cached ";
//         std::cout << std::endl;
//     }

//     // Check if all required features are available
//     bool supportsInterop =
//         hasExternalMemoryExt &&
//         hasWin32Ext &&
//         result == VK_SUCCESS;

//     std::cout << "\nFinal Result: " << (supportsInterop ? "Interop Supported" : "Interop Not Supported") << std::endl;
//     std::cout << "================================================" << std::endl;

//     return supportsInterop;
// }

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


// Modified memory type selection function with more detailed requirements checking
uint32_t findOptimalMemoryType(VkPhysicalDevice physicalDevice,
                              uint32_t typeFilter,
                              VkMemoryPropertyFlags requiredProperties,
                              VkMemoryPropertyFlags preferredProperties) {
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);
    
    // First try to find memory type with all preferred properties
    if (preferredProperties != 0) {
        for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
            if ((typeFilter & (1 << i)) && 
                (memProperties.memoryTypes[i].propertyFlags & (requiredProperties | preferredProperties)) == 
                (requiredProperties | preferredProperties)) {
                return i;
            }
        }
    }
    
    // Fall back to just required properties
    for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
        if ((typeFilter & (1 << i)) && 
            (memProperties.memoryTypes[i].propertyFlags & requiredProperties) == requiredProperties) {
            return i;
        }
    }
    
    return UINT32_MAX;
}

// Consolidated function for creating Vulkan instance
VkResult createVulkanInstance(VkInstance *instance)
{
    std::vector<const char *> instanceExtensions = {
        VK_KHR_SURFACE_EXTENSION_NAME,
        VK_KHR_WIN32_SURFACE_EXTENSION_NAME,
        VK_KHR_EXTERNAL_MEMORY_CAPABILITIES_EXTENSION_NAME,
        // VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME,
        // VK_KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME
        VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME};

    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Vulkan-D3D11 Interop";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_1;

    VkInstanceCreateInfo createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = static_cast<uint32_t>(instanceExtensions.size());
    createInfo.ppEnabledExtensionNames = instanceExtensions.data();

    return vkCreateInstance(&createInfo, nullptr, instance);
}

// Helper function to find a queue family that supports graphics operations
uint32_t findGraphicsQueueFamily(VkPhysicalDevice physicalDevice) {
    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nullptr);

    std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, queueFamilies.data());

    // Find a queue family that supports graphics operations
    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        if (queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            return i;
        }
    }

    throw std::runtime_error("Failed to find graphics queue family");
}


CommandResources createCommandResources(VkDevice device, VkPhysicalDevice physicalDevice) {
    CommandResources resources{};

    // 1. Find a suitable queue family
    resources.queueFamilyIndex = findGraphicsQueueFamily(physicalDevice);

    // 2. Get the queue handle
    vkGetDeviceQueue(device,
        resources.queueFamilyIndex,
        0,  // First queue in family
        &resources.queue);

    // 3. Create command pool
    VkCommandPoolCreateInfo poolInfo{};
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;  // Allow resetting individual command buffers
    poolInfo.queueFamilyIndex = resources.queueFamilyIndex;

    if (vkCreateCommandPool(device, &poolInfo, nullptr, &resources.commandPool) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create command pool");
    }

    return resources;
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

// Consolidated function for creating logical device
VkResult createLogicalDevice(VkInstance instance, VkPhysicalDevice *physicalDevice, VkDevice *device)
{
    uint32_t deviceCount = 0;
    bluevk::vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr);
    std::vector<VkPhysicalDevice> physicalDevices(deviceCount);
    bluevk::vkEnumeratePhysicalDevices(instance, &deviceCount, physicalDevices.data());

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

void fillImageWithColor(
    VkDevice device,
    VkCommandPool commandPool,
    VkQueue queue,
    VkImage image,
    VkFormat format,
    VkImageLayout currentLayout,
    VkExtent3D extent,
    float r, float g, float b, float a
) {
    // Create command buffer
    VkCommandBufferAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandPool = commandPool;
    allocInfo.commandBufferCount = 1;

    VkCommandBuffer commandBuffer;
    vkAllocateCommandBuffers(device, &allocInfo, &commandBuffer);

    // Begin command buffer
    VkCommandBufferBeginInfo beginInfo = {};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(commandBuffer, &beginInfo);

    // Transition image layout to TRANSFER_DST_OPTIMAL if needed
    if (currentLayout != VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        VkImageMemoryBarrier barrier = {};
        barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = currentLayout;
        barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.image = image;
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier.subresourceRange.baseMipLevel = 0;
        barrier.subresourceRange.levelCount = 1;
        barrier.subresourceRange.baseArrayLayer = 0;
        barrier.subresourceRange.layerCount = 1;
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

        vkCmdPipelineBarrier(
            commandBuffer,
            VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            0,
            0, nullptr,
            0, nullptr,
            1, &barrier
        );
    }

    // Clear the image
    VkClearColorValue clearColor = {{r, g, b, a}};
    VkImageSubresourceRange range = {};
    range.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    range.baseMipLevel = 0;
    range.levelCount = 1;
    range.baseArrayLayer = 0;
    range.layerCount = 1;

    vkCmdClearColorImage(
        commandBuffer,
        image,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        &clearColor,
        1,
        &range
    );

    // Transition back to original layout if needed
    if (currentLayout != VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        VkImageMemoryBarrier barrier = {};
        barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier.newLayout = currentLayout;
        barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.image = image;
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier.subresourceRange.baseMipLevel = 0;
        barrier.subresourceRange.levelCount = 1;
        barrier.subresourceRange.baseArrayLayer = 0;
        barrier.subresourceRange.layerCount = 1;
        barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = 0;

        vkCmdPipelineBarrier(
            commandBuffer,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            0,
            0, nullptr,
            0, nullptr,
            1, &barrier
        );
    }

    // End and submit command buffer
    vkEndCommandBuffer(commandBuffer);

    VkSubmitInfo submitInfo = {};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffer;

    vkQueueSubmit(queue, 1, &submitInfo, VK_NULL_HANDLE);
    vkQueueWaitIdle(queue);

    // Cleanup
    vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer);
}

bool SavePixelsAsBMP(uint8_t* pixels, uint32_t width, uint32_t height, int rowPitch, const char* filename) {
// Create and fill header
    BMPHeader header = {};
    header.signature = 0x4D42;  // 'BM'
    header.fileSize = sizeof(BMPHeader) + width * height * 4;
    header.dataOffset = sizeof(BMPHeader);
    header.headerSize = 40;
    header.width = width;
    header.height = height;
    header.planes = 1;
    header.bitsPerPixel = 32;
    header.compression = 0;
    header.imageSize = width * height * 4;
    header.xPixelsPerMeter = 2835;  // 72 DPI
    header.yPixelsPerMeter = 2835;  // 72 DPI

    // Write to file
    FILE* file = nullptr;
    fopen_s(&file, filename, "wb");
       
    if (!file) {
        std::cout << "Couldn't open file for pixels" << std::endl;
        return false;
    }

    fwrite(&header, sizeof(header), 1, file);

    // Write pixel data (need to flip rows as BMP is bottom-up)
    for (int y = height - 1; y >= 0; y--) {
        uint8_t* rowData = pixels + y * rowPitch;
        fwrite(rowData, width * 4, 1, file);
    }

    fclose(file);
    return true;

}
