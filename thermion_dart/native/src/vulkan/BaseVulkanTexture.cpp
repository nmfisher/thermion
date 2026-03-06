#include "vulkan/BaseVulkanTexture.h"
#include "bluevk/BlueVK.h"
#include <iostream>

namespace thermion::vulkan {

BaseVulkanTexture::BaseVulkanTexture(VkImage image, VkDevice device, VkDeviceMemory imageMemory,
                                     uint32_t width, uint32_t height)
    : _image(image), _device(device), _imageMemory(imageMemory), _width(width), _height(height) {}

BaseVulkanTexture::~BaseVulkanTexture() {
    // Base destructor - subclasses should call destroyResources() with appropriate flags
    // This is a safety net but subclasses handle their own cleanup
}

void BaseVulkanTexture::destroyResources(bool freeMemory) {
    if (_device == VK_NULL_HANDLE) {
        return;
    }

    bluevk::vkDeviceWaitIdle(_device);

    if (_image != VK_NULL_HANDLE) {
        bluevk::vkDestroyImage(_device, _image, nullptr);
        _image = VK_NULL_HANDLE;
    }

    if (freeMemory && _imageMemory != VK_NULL_HANDLE) {
        bluevk::vkFreeMemory(_device, _imageMemory, nullptr);
        _imageMemory = VK_NULL_HANDLE;
    }
}

} // namespace thermion::vulkan
