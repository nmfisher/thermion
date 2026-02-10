#include "linux_vulkan_utils.h"

#include <iostream>
#include <vector>
#include <string>
#include <stdexcept>
#include <drm/drm_fourcc.h>

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

// Consolidated function for creating Vulkan instance (offscreen, no surface extension needed)
VkResult createVulkanInstance(VkInstance *instance)
{
    std::vector<const char *> instanceExtensions = {
        VK_KHR_EXTERNAL_MEMORY_CAPABILITIES_EXTENSION_NAME,
        VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME};

    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Thermion Linux";
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

    // 2. Get the queue handle (index 1 = blit queue, index 0 is reserved for Filament)
    vkGetDeviceQueue(device,
        resources.queueFamilyIndex,
        1,
        &resources.queue);

    // 3. Create command pool
    VkCommandPoolCreateInfo poolInfo{};
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    poolInfo.queueFamilyIndex = resources.queueFamilyIndex;

    if (vkCreateCommandPool(device, &poolInfo, nullptr, &resources.commandPool) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create command pool");
    }

    return resources;
}

DmaBufRenderCapability queryDmaBufRenderCapability(VkPhysicalDevice physicalDevice) {
    DmaBufRenderCapability capability{};
    capability.colorAttachmentSupported = false;

    // Query DRM format modifier properties for R8G8B8A8_UNORM
    VkDrmFormatModifierPropertiesListEXT modifierPropsList = {};
    modifierPropsList.sType = VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT;

    VkFormatProperties2 formatProps2 = {};
    formatProps2.sType = VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2;
    formatProps2.pNext = &modifierPropsList;

    // First call to get the count
    vkGetPhysicalDeviceFormatProperties2(physicalDevice, VK_FORMAT_R8G8B8A8_UNORM, &formatProps2);

    if (modifierPropsList.drmFormatModifierCount == 0) {
        return capability;
    }

    // Second call to get the actual properties
    std::vector<VkDrmFormatModifierPropertiesEXT> modifierProps(modifierPropsList.drmFormatModifierCount);
    modifierPropsList.pDrmFormatModifierProperties = modifierProps.data();
    vkGetPhysicalDeviceFormatProperties2(physicalDevice, VK_FORMAT_R8G8B8A8_UNORM, &formatProps2);

    // Check if DRM_FORMAT_MOD_LINEAR supports COLOR_ATTACHMENT_BIT
    for (uint32_t i = 0; i < modifierPropsList.drmFormatModifierCount; i++) {
        if (modifierProps[i].drmFormatModifier == DRM_FORMAT_MOD_LINEAR) {
            if (modifierProps[i].drmFormatModifierTilingFeatures & VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT) {
                capability.colorAttachmentSupported = true;
            }
            break;
        }
    }

    return capability;
}

// Consolidated function for creating logical device with Linux dmabuf extensions
VkResult createLogicalDevice(VkInstance instance, VkPhysicalDevice *physicalDevice, VkDevice *device, uint32_t* queueFamilyIndex)
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
    *queueFamilyIndex = findGraphicsQueueFamily(*physicalDevice);

    std::vector<const char *> deviceExtensions = {
        VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME,
        VK_KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME,
        VK_EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME,
        VK_EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME,
        VK_KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME,
        VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        VK_KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME,
    };

    // Request 2 queues from the graphics family: index 0 for Filament, index 1 for blit.
    // Filament assumes exclusive ownership of its queue, so submitting external blit
    // commands to the same queue corrupts its internal semaphore tracking (VK_ERROR_DEVICE_LOST).
    float queuePriorities[2] = {1.0f, 1.0f};
    VkDeviceQueueCreateInfo queueCreateInfo = {};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = *queueFamilyIndex;
    queueCreateInfo.queueCount = 2;
    queueCreateInfo.pQueuePriorities = queuePriorities;

    VkDeviceCreateInfo deviceCreateInfo = {};
    deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    deviceCreateInfo.queueCreateInfoCount = 1;
    deviceCreateInfo.pQueueCreateInfos = &queueCreateInfo;
    deviceCreateInfo.enabledExtensionCount = static_cast<uint32_t>(deviceExtensions.size());
    deviceCreateInfo.ppEnabledExtensionNames = deviceExtensions.data();

    return vkCreateDevice(*physicalDevice, &deviceCreateInfo, nullptr, device);
}
