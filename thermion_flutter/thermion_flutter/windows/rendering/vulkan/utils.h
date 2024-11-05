#pragma once

#include <vulkan/vulkan.h>
#include <vulkan/vulkan_win32.h>

#include <iostream>
#include <thread>
#include <chrono>
#include <vector>
#include <string>

#include <functional>
#include <iostream>
#include <memory>
#include <thread>

#pragma pack(push, 1)
struct BMPHeader {
    uint16_t signature;
    uint32_t fileSize;
    uint32_t reserved;
    uint32_t dataOffset;
    uint32_t headerSize;
    int32_t width;
    int32_t height;
    uint16_t planes;
    uint16_t bitsPerPixel;
    uint32_t compression;
    uint32_t imageSize;
    int32_t xPixelsPerMeter;
    int32_t yPixelsPerMeter;
    uint32_t totalColors;
    uint32_t importantColors;
};
#pragma pack(pop)

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



bool checkD3D11VulkanInterop(VkPhysicalDevice physicalDevice, ID3D11Device *d3dDevice)
{
    std::cout << "\n=== Checking D3D11-Vulkan Interop Support in QEMU ===" << std::endl;

    // Check Vulkan external memory capabilities
    VkPhysicalDeviceExternalImageFormatInfo externFormatInfo = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
        .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT};

    VkPhysicalDeviceImageFormatInfo2 formatInfo = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
        .pNext = &externFormatInfo,
        .format = VK_FORMAT_R8G8B8A8_UNORM,
        .type = VK_IMAGE_TYPE_2D,
        .tiling = VK_IMAGE_TILING_OPTIMAL,
        .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
        .flags = 0};

    VkExternalImageFormatProperties externFormatProps = {
        .sType = VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES};

    VkImageFormatProperties2 formatProps = {
        .sType = VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2,
        .pNext = &externFormatProps};

    // Check device properties
    VkPhysicalDeviceProperties deviceProps;
    vkGetPhysicalDeviceProperties(physicalDevice, &deviceProps);

    std::cout << "Vulkan Device: " << deviceProps.deviceName << std::endl;
    std::cout << "Driver Version: " << deviceProps.driverVersion << std::endl;
    std::cout << "API Version: " << VK_VERSION_MAJOR(deviceProps.apiVersion) << "." << VK_VERSION_MINOR(deviceProps.apiVersion) << "." << VK_VERSION_PATCH(deviceProps.apiVersion) << std::endl;

    // Check D3D11 device capabilities
    D3D11_FEATURE_DATA_D3D11_OPTIONS3 featureData = {};
    HRESULT hr = d3dDevice->CheckFeatureSupport(
        D3D11_FEATURE_D3D11_OPTIONS3,
        &featureData,
        sizeof(featureData));

    std::cout << "\nChecking D3D11 Device:" << std::endl;

    // Get D3D11 device information
    IDXGIDevice *dxgiDevice = nullptr;
    hr = d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void **)&dxgiDevice);
    if (SUCCEEDED(hr))
    {
        IDXGIAdapter *adapter = nullptr;
        hr = dxgiDevice->GetAdapter(&adapter);
        if (SUCCEEDED(hr))
        {
            DXGI_ADAPTER_DESC desc;
            adapter->GetDesc(&desc);
            std::wcout << L"D3D11 Adapter: " << desc.Description << std::endl;
            adapter->Release();
        }
        dxgiDevice->Release();
    }

    // Check for external memory support
    VkResult result = vkGetPhysicalDeviceImageFormatProperties2(
        physicalDevice,
        &formatInfo,
        &formatProps);

    std::cout << "\nInterop Support Details:" << std::endl;

    // Check external memory extension
    uint32_t extensionCount = 0;
    vkEnumerateDeviceExtensionProperties(physicalDevice, nullptr, &extensionCount, nullptr);
    std::vector<VkExtensionProperties> extensions(extensionCount);
    vkEnumerateDeviceExtensionProperties(physicalDevice, nullptr, &extensionCount, extensions.data());

    bool hasExternalMemoryExt = false;
    bool hasWin32Ext = false;

    for (const auto &ext : extensions)
    {
        if (strcmp(ext.extensionName, VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME) == 0)
        {
            hasExternalMemoryExt = true;
        }
        if (strcmp(ext.extensionName, VK_KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME) == 0)
        {
            hasWin32Ext = true;
        }
    }

    std::cout << "External Memory Extension: " << (hasExternalMemoryExt ? "Yes" : "No") << std::endl;
    std::cout << "Win32 External Memory Extension: " << (hasWin32Ext ? "Yes" : "No") << std::endl;
    std::cout << "Format Properties Check: " << (result == VK_SUCCESS ? "Passed" : "Failed") << std::endl;

    // Check memory properties
    VkPhysicalDeviceMemoryProperties memProps;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProps);

    std::cout << "\nMemory Types Available:" << std::endl;
    for (uint32_t i = 0; i < memProps.memoryTypeCount; i++)
    {
        VkMemoryPropertyFlags flags = memProps.memoryTypes[i].propertyFlags;
        std::cout << "Type " << i << ": ";
        if (flags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
            std::cout << "Device Local ";
        if (flags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)
            std::cout << "Host Visible ";
        if (flags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
            std::cout << "Host Coherent ";
        if (flags & VK_MEMORY_PROPERTY_HOST_CACHED_BIT)
            std::cout << "Host Cached ";
        std::cout << std::endl;
    }

    // Check if all required features are available
    bool supportsInterop =
        hasExternalMemoryExt &&
        hasWin32Ext &&
        result == VK_SUCCESS;

    std::cout << "\nFinal Result: " << (supportsInterop ? "Interop Supported" : "Interop Not Supported") << std::endl;
    std::cout << "================================================" << std::endl;

    return supportsInterop;
}


// Modified memory type selection function with more detailed requirements checking
uint32_t findOptimalMemoryType(VkPhysicalDevice physicalDevice,
                              uint32_t typeFilter,
                              VkMemoryPropertyFlags requiredProperties,
                              VkMemoryPropertyFlags preferredProperties = 0) {
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

// Structure to hold both command pool and queue
struct CommandResources {
    VkCommandPool commandPool;
    VkQueue queue;
    uint32_t queueFamilyIndex;
};

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