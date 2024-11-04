#include "d3d_texture.h"
#include <iostream>
#include <thread>
#include <chrono>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_win32.h>
#include <vector>
#include <string>

#include "d3d_texture.h"

#include <functional>
#include <iostream>
#include <memory>
#include <thread>

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

    // Create logical device
    result = createLogicalDevice(instance, &physicalDevice, &device);
    if (result != VK_SUCCESS)
    {
        std::cout << "[ERROR] Failed to create logical device! Error: " << VkResultToString(result) << std::endl;
        vkDestroyInstance(instance, nullptr);
        return 1;
    }

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
    }
    else
    {
        std::cout << "Successfully created image " << std::endl;
    }

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
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT // You might need to adjust these flags
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

    // Cleanup
    std::cout << "\n[Step 6] Cleaning up resources..." << std::endl;
    vkDestroyImage(device, image, nullptr);
    // vkFreeMemory(device, memory, nullptr);
    vkDestroyDevice(device, nullptr);
    vkDestroyInstance(instance, nullptr);
    std::cout << "[Complete] All resources cleaned up successfully" << std::endl;

    return 0;
}
