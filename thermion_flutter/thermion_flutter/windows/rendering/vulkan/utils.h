#pragma once

#include <bluevk/BlueVK.h>

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
const char *VkResultToString(VkResult result);
// bool checkD3D11VulkanInterop(VkPhysicalDevice physicalDevice, ID3D11Device *d3dDevice);
uint32_t findOptimalMemoryType(VkPhysicalDevice physicalDevice,
                              uint32_t typeFilter,
                              VkMemoryPropertyFlags requiredProperties,
                              VkMemoryPropertyFlags preferredProperties = 0);

VkResult createVulkanInstance(VkInstance *instance);

uint32_t findGraphicsQueueFamily(VkPhysicalDevice physicalDevice);

// Structure to hold both command pool and queue
struct CommandResources {
    VkCommandPool commandPool;
    VkQueue queue;
    uint32_t queueFamilyIndex;
};

CommandResources createCommandResources(VkDevice device, VkPhysicalDevice physicalDevice);
void readVkImageToBitmap(
    VkPhysicalDevice physicalDevice,
    VkDevice device,
    VkCommandPool commandPool,
    VkQueue queue,
    VkImage sourceImage,
    uint32_t width,
    uint32_t height,
    const char* outputPath
);

VkResult createLogicalDevice(VkInstance instance, VkPhysicalDevice *physicalDevice, VkDevice *device);

void createDeviceWithGraphicsQueue(VkPhysicalDevice physicalDevice, uint32_t& queueFamilyIndex, VkDevice* device);
void fillImageWithColor(
    VkDevice device,
    VkCommandPool commandPool,
    VkQueue queue,
    VkImage image,
    VkFormat format,
    VkImageLayout currentLayout,
    VkExtent3D extent,
    float r, float g, float b, float a
);