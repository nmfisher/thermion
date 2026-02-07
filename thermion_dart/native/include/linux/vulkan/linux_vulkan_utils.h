#pragma once

#include <bluevk/BlueVK.h>

// Helper function to convert VkResult to string for error reporting
const char *VkResultToString(VkResult result);

uint32_t findOptimalMemoryType(VkPhysicalDevice physicalDevice,
                              uint32_t typeFilter,
                              VkMemoryPropertyFlags requiredProperties,
                              VkMemoryPropertyFlags preferredProperties = 0);

uint32_t findMemoryType(uint32_t typeFilter, VkMemoryPropertyFlags properties, VkPhysicalDevice physicalDevice);

VkResult createVulkanInstance(VkInstance *instance);

uint32_t findGraphicsQueueFamily(VkPhysicalDevice physicalDevice);

// Structure to hold both command pool and queue
struct CommandResources {
    VkCommandPool commandPool;
    VkQueue queue;
    uint32_t queueFamilyIndex;
};

CommandResources createCommandResources(VkDevice device, VkPhysicalDevice physicalDevice);

VkResult createLogicalDevice(VkInstance instance, VkPhysicalDevice *physicalDevice, VkDevice *device, uint32_t* queueFamilyIndex);
