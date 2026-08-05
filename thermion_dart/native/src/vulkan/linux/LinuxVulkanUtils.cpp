#include <iostream>
#include <vector>
#include <string>
#include <stdexcept>
#include <cstring>
#include <drm/drm_fourcc.h>

#include "vulkan/linux/LinuxVulkanUtils.h"

namespace thermion::vulkan::linux_platform {

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
    case VK_ERROR_DEVICE_LOST:
        return "VK_ERROR_DEVICE_LOST";
    case VK_ERROR_FEATURE_NOT_PRESENT:
        return "VK_ERROR_FEATURE_NOT_PRESENT";
    case VK_ERROR_FORMAT_NOT_SUPPORTED:
        return "VK_ERROR_FORMAT_NOT_SUPPORTED";
    case VK_ERROR_INCOMPATIBLE_DRIVER:
        return "VK_ERROR_INCOMPATIBLE_DRIVER";
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

// Vulkan validation debug callback
static VKAPI_ATTR VkBool32 VKAPI_CALL vulkanDebugCallback(
    VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
    VkDebugUtilsMessageTypeFlagsEXT messageType,
    const VkDebugUtilsMessengerCallbackDataEXT* pCallbackData,
    void* pUserData)
{
    const char* severity = "UNKNOWN";
    if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT)
        severity = "ERROR";
    else if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT)
        severity = "WARNING";
    else if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT)
        severity = "INFO";
    else if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT)
        severity = "VERBOSE";

    std::cerr << "[VkValidation " << severity << "] " << pCallbackData->pMessage << std::endl;
    return VK_FALSE;
}

static VkDebugUtilsMessengerEXT sDebugMessenger = VK_NULL_HANDLE;

// Consolidated function for creating Vulkan instance (offscreen, no surface extension needed)
VkResult createVulkanInstance(VkInstance *instance)
{
    std::vector<const char *> instanceExtensions = {
        VK_KHR_EXTERNAL_MEMORY_CAPABILITIES_EXTENSION_NAME,
        VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
        VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };

    const char* validationLayer = "VK_LAYER_KHRONOS_validation";

    // Check if validation layer is available
    uint32_t layerCount = 0;
    vkEnumerateInstanceLayerProperties(&layerCount, nullptr);
    std::vector<VkLayerProperties> availableLayers(layerCount);
    vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.data());

    bool validationAvailable = false;
    for (const auto& layer : availableLayers) {
        if (strcmp(layer.layerName, validationLayer) == 0) {
            validationAvailable = true;
            break;
        }
    }

    if (validationAvailable) {
        std::cerr << "[VkValidation] Enabling Vulkan validation layers" << std::endl;
    } else {
        std::cerr << "[VkValidation] WARNING: VK_LAYER_KHRONOS_validation not available. "
                  << "Install vulkan-validation-layers package." << std::endl;
    }

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

    if (validationAvailable) {
        createInfo.enabledLayerCount = 1;
        createInfo.ppEnabledLayerNames = &validationLayer;
    }

    VkResult result = vkCreateInstance(&createInfo, nullptr, instance);
    if (result != VK_SUCCESS) {
        return result;
    }

    // Set up debug messenger
    if (validationAvailable) {
        VkDebugUtilsMessengerCreateInfoEXT debugCreateInfo = {};
        debugCreateInfo.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        debugCreateInfo.messageSeverity =
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT;
        debugCreateInfo.messageType =
            VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        debugCreateInfo.pfnUserCallback = vulkanDebugCallback;

        auto createMessenger = (PFN_vkCreateDebugUtilsMessengerEXT)
            vkGetInstanceProcAddr(*instance, "vkCreateDebugUtilsMessengerEXT");
        if (createMessenger) {
            createMessenger(*instance, &debugCreateInfo, nullptr, &sDebugMessenger);
        }
    }

    return VK_SUCCESS;
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

    // 2. Get the queue handle. Use the SECOND queue in the family when the
    //    hardware has one (the device requests two — see createLogicalDevice):
    //    queue 0 belongs to Filament; submitting to it concurrently from the
    //    blit thread is a data race. Fall back to queue 0 only on single-queue
    //    hardware, where the LinuxVulkanContext shim serializes queue calls.
    uint32_t familyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &familyCount, nullptr);
    std::vector<VkQueueFamilyProperties> families(familyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &familyCount, families.data());
    const uint32_t queueIndex =
        families[resources.queueFamilyIndex].queueCount >= 2 ? 1u : 0u;
    resources.queueSharedWithFilament = (queueIndex == 0);
    std::cerr << "[ThermionVk] Blit/command queue: family "
              << resources.queueFamilyIndex << ", queue index " << queueIndex
              << (resources.queueSharedWithFilament ? " (shared with Filament)" : "")
              << std::endl;

    vkGetDeviceQueue(device,
        resources.queueFamilyIndex,
        queueIndex,
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

std::vector<uint64_t> queryColorAttachmentModifiers(VkPhysicalDevice physicalDevice, VkFormat format) {
    std::vector<uint64_t> result;

    VkDrmFormatModifierPropertiesListEXT modifierPropsList = {};
    modifierPropsList.sType = VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT;

    VkFormatProperties2 formatProps2 = {};
    formatProps2.sType = VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2;
    formatProps2.pNext = &modifierPropsList;

    // First call to get the count
    vkGetPhysicalDeviceFormatProperties2(physicalDevice, format, &formatProps2);

    if (modifierPropsList.drmFormatModifierCount == 0) {
        return result;
    }

    // Second call to get the actual properties
    std::vector<VkDrmFormatModifierPropertiesEXT> modifierProps(modifierPropsList.drmFormatModifierCount);
    modifierPropsList.pDrmFormatModifierProperties = modifierProps.data();
    vkGetPhysicalDeviceFormatProperties2(physicalDevice, format, &formatProps2);

    // Filter for modifiers that support COLOR_ATTACHMENT_BIT
    for (uint32_t i = 0; i < modifierPropsList.drmFormatModifierCount; i++) {
        if (modifierProps[i].drmFormatModifierTilingFeatures & VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT) {
            result.push_back(modifierProps[i].drmFormatModifier);
            std::cerr << "[ThermionVk] COLOR_ATTACHMENT modifier: 0x"
                      << std::hex << modifierProps[i].drmFormatModifier << std::dec
                      << " planes=" << modifierProps[i].drmFormatModifierPlaneCount
                      << std::endl;
        }
    }

    return result;
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

    // Log GPU info
    VkPhysicalDeviceProperties devProps;
    vkGetPhysicalDeviceProperties(*physicalDevice, &devProps);
    std::cerr << "[ThermionVk] GPU: " << devProps.deviceName
              << " (vendor 0x" << std::hex << devProps.vendorID
              << ", device 0x" << devProps.deviceID << std::dec
              << ", driver " << devProps.driverVersion
              << ", api " << VK_VERSION_MAJOR(devProps.apiVersion)
              << "." << VK_VERSION_MINOR(devProps.apiVersion)
              << "." << VK_VERSION_PATCH(devProps.apiVersion) << ")" << std::endl;

    *queueFamilyIndex = findGraphicsQueueFamily(*physicalDevice);

    // Log queue family details
    uint32_t qfCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(*physicalDevice, &qfCount, nullptr);
    std::vector<VkQueueFamilyProperties> qfProps(qfCount);
    vkGetPhysicalDeviceQueueFamilyProperties(*physicalDevice, &qfCount, qfProps.data());
    for (uint32_t i = 0; i < qfCount; i++) {
        std::cerr << "[ThermionVk] Queue family " << i
                  << ": flags=0x" << std::hex << qfProps[i].queueFlags << std::dec
                  << " count=" << qfProps[i].queueCount << std::endl;
    }
    // Request a second queue in the family when the hardware exposes one.
    // Queue 0 is handed to Filament; the blit submits from a separate thread.
    // VkQueue access is externally synchronized, so sharing one queue across
    // those threads is a data race. With two queues the blit gets its own
    // (see createCommandResources); with one queue they share queue 0 and the
    // blit's queue calls are serialized via the LinuxVulkanContext shim.
    const uint32_t queueCount = qfProps[*queueFamilyIndex].queueCount >= 2 ? 2u : 1u;
    std::cerr << "[ThermionVk] Using graphics queue family " << *queueFamilyIndex
              << " (supports " << qfProps[*queueFamilyIndex].queueCount
              << " queues, requesting " << queueCount << ")" << std::endl;

    if (queueCount < 2) {
        std::cerr << "[ThermionVk] Single graphics queue: Filament and blit share queue 0; "
                  << "queue calls will be serialized (see LinuxVulkanContext shim)." << std::endl;
    }

    // Check which device extensions are available
    uint32_t extCount = 0;
    vkEnumerateDeviceExtensionProperties(*physicalDevice, nullptr, &extCount, nullptr);
    std::vector<VkExtensionProperties> availableExts(extCount);
    vkEnumerateDeviceExtensionProperties(*physicalDevice, nullptr, &extCount, availableExts.data());

    std::vector<const char *> deviceExtensions = {
        VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME,
        VK_KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME,
        VK_EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME,
        VK_EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME,
        VK_KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME,
        VK_KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME,
    };

    for (const auto* reqExt : deviceExtensions) {
        bool found = false;
        for (const auto& avail : availableExts) {
            if (strcmp(avail.extensionName, reqExt) == 0) {
                found = true;
                break;
            }
        }
        std::cerr << "[ThermionVk] Extension " << reqExt << ": " << (found ? "OK" : "MISSING") << std::endl;
    }

    // Query DMA-BUF render capability - check all modifiers
    auto dmaBufCap = queryDmaBufRenderCapability(*physicalDevice);
    std::cerr << "[ThermionVk] DMA-BUF COLOR_ATTACHMENT with LINEAR modifier: "
              << (dmaBufCap.colorAttachmentSupported ? "SUPPORTED" : "NOT SUPPORTED") << std::endl;

    // Log ALL available DRM format modifiers and their capabilities
    {
        VkDrmFormatModifierPropertiesListEXT modList = {};
        modList.sType = VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT;
        VkFormatProperties2 fp2 = {};
        fp2.sType = VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2;
        fp2.pNext = &modList;
        vkGetPhysicalDeviceFormatProperties2(*physicalDevice, VK_FORMAT_R8G8B8A8_UNORM, &fp2);

        if (modList.drmFormatModifierCount > 0) {
            std::vector<VkDrmFormatModifierPropertiesEXT> mods(modList.drmFormatModifierCount);
            modList.pDrmFormatModifierProperties = mods.data();
            vkGetPhysicalDeviceFormatProperties2(*physicalDevice, VK_FORMAT_R8G8B8A8_UNORM, &fp2);

            std::cerr << "[ThermionVk] R8G8B8A8_UNORM DRM modifiers (" << modList.drmFormatModifierCount << "):" << std::endl;
            for (uint32_t i = 0; i < modList.drmFormatModifierCount; i++) {
                bool hasColorAttach = mods[i].drmFormatModifierTilingFeatures & VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT;
                bool hasTransferSrc = mods[i].drmFormatModifierTilingFeatures & VK_FORMAT_FEATURE_TRANSFER_SRC_BIT;
                bool hasTransferDst = mods[i].drmFormatModifierTilingFeatures & VK_FORMAT_FEATURE_TRANSFER_DST_BIT;
                bool hasSampled = mods[i].drmFormatModifierTilingFeatures & VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT;
                std::cerr << "[ThermionVk]   modifier=0x" << std::hex << mods[i].drmFormatModifier << std::dec
                          << " planes=" << mods[i].drmFormatModifierPlaneCount
                          << " features=0x" << std::hex << mods[i].drmFormatModifierTilingFeatures << std::dec
                          << " [" << (hasColorAttach ? "COLOR_ATTACH " : "")
                          << (hasTransferSrc ? "XFER_SRC " : "")
                          << (hasTransferDst ? "XFER_DST " : "")
                          << (hasSampled ? "SAMPLED" : "")
                          << "]" << std::endl;
            }
        } else {
            std::cerr << "[ThermionVk] No DRM format modifiers available for R8G8B8A8_UNORM" << std::endl;
        }
    }

    // Query physical device features so we can enable what Filament needs.
    VkPhysicalDeviceFeatures supportedFeatures = {};
    vkGetPhysicalDeviceFeatures(*physicalDevice, &supportedFeatures);

    // Enable the features Filament uses (see VulkanPlatform::createLogicalDeviceAndQueues).
    VkPhysicalDeviceFeatures enabledFeatures = {};
    enabledFeatures.depthClamp = supportedFeatures.depthClamp;
    enabledFeatures.samplerAnisotropy = supportedFeatures.samplerAnisotropy;
    enabledFeatures.textureCompressionETC2 = supportedFeatures.textureCompressionETC2;
    enabledFeatures.textureCompressionBC = supportedFeatures.textureCompressionBC;
    enabledFeatures.shaderClipDistance = supportedFeatures.shaderClipDistance;

    // Request 2 queues from the graphics family: index 0 for Filament, index 1 for blit.
    // Filament assumes exclusive ownership of its queue, so submitting external blit
    // commands to the same queue corrupts its internal semaphore tracking (VK_ERROR_DEVICE_LOST).
    float queuePriorities[2] = {1.0f, 1.0f};
    VkDeviceQueueCreateInfo queueCreateInfo = {};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = *queueFamilyIndex;
    queueCreateInfo.queueCount = queueCount;
    queueCreateInfo.pQueuePriorities = queuePriorities;

    VkDeviceCreateInfo deviceCreateInfo = {};
    deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    deviceCreateInfo.queueCreateInfoCount = 1;
    deviceCreateInfo.pQueueCreateInfos = &queueCreateInfo;
    deviceCreateInfo.enabledExtensionCount = static_cast<uint32_t>(deviceExtensions.size());
    deviceCreateInfo.ppEnabledExtensionNames = deviceExtensions.data();
    deviceCreateInfo.pEnabledFeatures = &enabledFeatures;

    return vkCreateDevice(*physicalDevice, &deviceCreateInfo, nullptr, device);
}

} // namespace thermion::vulkan::linux_platform
