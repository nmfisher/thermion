#include <utils/Panic.h>

#include "d3d/D3DContext.h"

#include "vulkan/ExternalVulkanImage.h"
#include "vulkan/windows/WindowsVulkanPlatform.h"
#include "vulkan/windows/WindowsVulkanContext.h"
#include "vulkan/windows/WindowsVulkanTexture.h"

#include "ThermionWin32.h"

#include <cstring>
#include <iostream>
#include <memory>
#include <vector>

#include "backend/platforms/VulkanPlatform.h"
#include "Log.hpp"

namespace thermion::vulkan::windows {

using namespace bluevk;

class WindowsVulkanContext::Impl {
    public:
        ~Impl() {
            std::cerr << "WindowsVulkanContext destructor " << _surfaces.size()
                      << " surfaces remain" << std::endl;
            _surfaces.clear();
            if (commandPool != VK_NULL_HANDLE && device != VK_NULL_HANDLE) {
                bluevk::vkDestroyCommandPool(device, commandPool, nullptr);
                commandPool = VK_NULL_HANDLE;
            }
            _d3dContext = std::nullptr_t();
        }

        Impl() {
            std::cerr << "Initializing WindowsVulkanContext" << std::endl;
            if (!bluevk::initialize()) {
                std::cerr << "Failed to initialize BlueVK, this means the Vulkan drivers were not found." << std::endl;
                return;
            }

            VkResult result = createVulkanInstance(&instance);
            if (result != VK_SUCCESS) {
                std::cout << "[ERROR] Failed to create Vulkan instance! Error: " << VkResultToString(result) << std::endl;
                return;
            }
            bluevk::bindInstance(instance);

            uint32_t queueFamilyIndex = 0;
            result = createLogicalDevice(instance, &physicalDevice, &device, &queueFamilyIndex);
            if (result != VK_SUCCESS) {
                std::cout << "[ERROR] Failed to create logical device! Error: " << VkResultToString(result) << std::endl;
                vkDestroyInstance(instance, nullptr);
                return;
            }
            _sharedContext.instance = instance;
            _sharedContext.physicalDevice = physicalDevice;
            _sharedContext.logicalDevice = device;
            _sharedContext.graphicsQueueFamilyIndex = queueFamilyIndex;
            _sharedContext.graphicsQueueIndex = 0;
            _sharedContext.debugUtilsEnabled = false;
            _sharedContext.debugMarkersSupported = false;
            _sharedContext.multiviewSupported = false;

            Log("[INFO] Vulkan logical device created with queue family index %d",
                (int)queueFamilyIndex);

            VkPhysicalDeviceExternalImageFormatInfo externFormatInfo = {
                .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
                .pNext = nullptr,
                .handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT
            };

            VkPhysicalDeviceImageFormatInfo2 formatInfo = {
                .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
                .pNext = &externFormatInfo,
                .format = VK_FORMAT_R8G8B8A8_UNORM,
                .type = VK_IMAGE_TYPE_2D,
                .tiling = VK_IMAGE_TILING_OPTIMAL,
                .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                         VK_IMAGE_USAGE_TRANSFER_DST_BIT |
                         VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                         VK_IMAGE_USAGE_SAMPLED_BIT,
                .flags = 0
            };

            VkExternalImageFormatProperties externFormatProps = {
                .sType = VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES
            };

            VkImageFormatProperties2 formatProps = {
                .sType = VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2,
                .pNext = &externFormatProps
            };

            result = vkGetPhysicalDeviceImageFormatProperties2(
                physicalDevice,
                &formatInfo,
                &formatProps);

            if (result != VK_SUCCESS ||
                !(externFormatProps.externalMemoryProperties.externalMemoryFeatures &
                  VK_EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT)) {
                std::cout << "Vulkan/D3D11 driver does not support importable RGBA8 color attachment textures" << std::endl;
                return;
            }

            VkPhysicalDeviceIDProperties idProps{};
            idProps.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ID_PROPERTIES;
            idProps.pNext = nullptr;

            VkPhysicalDeviceProperties2 props{};
            props.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
            props.pNext = &idProps;

            bluevk::vkGetPhysicalDeviceProperties2(physicalDevice, &props);

            if (idProps.deviceLUIDValid == VK_TRUE) {
                Log("Using Vulkan Device LUID %d", idProps.deviceLUID);
                _d3dContext = std::make_unique<thermion::windows::d3d::D3DContext>(idProps.deviceLUID);
            }

            if (!_d3dContext || !_d3dContext->IsValid()) {
                ERROR("Could not resolve Vulkan Device LUID");
                return;
            }

            _platform = std::make_unique<WindowsVulkanPlatform>();
        }

        HANDLE CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {
            (void)left;
            (void)top;
            if (!_d3dContext || device == VK_NULL_HANDLE) {
                ERROR("WindowsVulkanContext is not initialized");
                return NULL;
            }

            Log("Creating shared D3D11/Vulkan RGBA8 surface %dx%d", width, height);

            auto d3dTexture = _d3dContext->CreateTexture(width, height);
            if (!d3dTexture) {
                ERROR("Failed to create shared D3D11 RGBA8 texture");
                return NULL;
            }

            auto d3dTextureHandle = d3dTexture->GetTextureHandle();
            auto vkTexture = WindowsVulkanTexture::create(
                device, physicalDevice, width, height, d3dTextureHandle);
            if (!vkTexture) {
                ERROR("Failed to import D3D11 RGBA8 texture into Vulkan");
                return NULL;
            }

            VkImage vkImage = vkTexture->GetImage();
            VkDeviceMemory vkMemory = vkTexture->GetMemory();

            auto* ext = new ExternalVulkanImage();
            ext->device = device;
            ext->image = vkImage;
            ext->memory = vkMemory;
            ext->ownsResourcesUntilClaimed = true;
            ext->format = VK_FORMAT_R8G8B8A8_UNORM;
            ext->width = width;
            ext->height = height;
            ext->layers = 1;
            ext->usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                         VK_IMAGE_USAGE_TRANSFER_DST_BIT |
                         VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                         VK_IMAGE_USAGE_SAMPLED_BIT;

            VkMemoryRequirements memReqs{};
            bluevk::vkGetImageMemoryRequirements(device, vkImage, &memReqs);
            ext->allocationSize = memReqs.size;
            ext->memoryTypeBits = memReqs.memoryTypeBits;

            ext->filamentFormat = filament::backend::TextureFormat::RGBA8;
            ext->filamentUsage = filament::backend::TextureUsage::COLOR_ATTACHMENT |
                                 filament::backend::TextureUsage::BLIT_SRC |
                                 filament::backend::TextureUsage::SAMPLEABLE;

            // Transfer VkImage + VkDeviceMemory lifetime to ExternalVulkanImage.
            // Once Filament imports the image via createVkImageFromExternal(),
            // Filament's Vulkan backend destroys both on its own render thread
            // when the Filament Texture is destroyed; if Dart never binds it,
            // ~ExternalVulkanImage() frees both directly.
            vkTexture->releaseOwnership();

            _surfaces.push_back(Surface{
                d3dTextureHandle,
                vkImage,
                std::move(d3dTexture),
                filament::backend::Platform::ExternalImageHandle(ext),
            });
            return d3dTextureHandle;
        }

        void DestroyRenderingSurface(HANDLE handle) {
            std::cerr << "Destroying rendering surface " << handle << std::endl;
            for (auto it = _surfaces.begin(); it != _surfaces.end(); ++it) {
                if (it->d3dHandle == handle) {
                    _surfaces.erase(it);
                    return;
                }
            }
            std::cerr << "D3D texture not found for handle " << handle << std::endl;
        }

        VkImage GetVulkanImageForSurface(HANDLE handle) {
            for (const auto& surface : _surfaces) {
                if (surface.d3dHandle == handle) {
                    return surface.vkImage;
                }
            }
            return VK_NULL_HANDLE;
        }

        void* CreateExternalImageForSurface(HANDLE handle) {
            for (auto& surface : _surfaces) {
                if (surface.d3dHandle == handle) {
                    return surface.externalImage.get();
                }
            }
            ERROR("D3D texture not found for handle in CreateExternalImageForSurface");
            return nullptr;
        }

        void readPixelsFromImage(
            uint32_t width,
            uint32_t height,
            std::vector<uint8_t>& outPixels) {
            if (_surfaces.empty()) {
                return;
            }
            if (commandPool == VK_NULL_HANDLE) {
                CommandResources cmdResources = createCommandResources(device, physicalDevice);
                commandPool = cmdResources.commandPool;
                queue = cmdResources.queue;
            }

            auto image = _surfaces.back().vkImage;
            VkDeviceSize bufferSize = width * height * 4;

            VkBuffer stagingBuffer;
            VkDeviceMemory stagingBufferMemory;

            VkBufferCreateInfo bufferInfo{};
            bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
            bufferInfo.size = bufferSize;
            bufferInfo.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
            bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

            VkResult result = bluevk::vkCreateBuffer(device, &bufferInfo, nullptr, &stagingBuffer);
            if (result != VK_SUCCESS) {
                PANIC_POSTCONDITION("Failed to create staging buffer");
            }

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
                PANIC_POSTCONDITION("Failed to allocate staging buffer memory");
            }

            result = bluevk::vkBindBufferMemory(device, stagingBuffer, stagingBufferMemory, 0);
            if (result != VK_SUCCESS) {
                vkFreeMemory(device, stagingBufferMemory, nullptr);
                vkDestroyBuffer(device, stagingBuffer, nullptr);
                PANIC_POSTCONDITION("Failed to bind buffer memory");
            }

            VkCommandBufferAllocateInfo cmdBufAllocInfo{};
            cmdBufAllocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
            cmdBufAllocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            cmdBufAllocInfo.commandPool = commandPool;
            cmdBufAllocInfo.commandBufferCount = 1;

            VkCommandBuffer commandBuffer;
            result = bluevk::vkAllocateCommandBuffers(device, &cmdBufAllocInfo, &commandBuffer);
            if (result != VK_SUCCESS) {
                PANIC_POSTCONDITION("Failed to allocate command buffer");
            }

            VkCommandBufferBeginInfo beginInfo{};
            beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
            beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

            result = bluevk::vkBeginCommandBuffer(commandBuffer, &beginInfo);
            if (result != VK_SUCCESS) {
                PANIC_POSTCONDITION("Failed to begin command buffer");
            }

            VkImageMemoryBarrier barrier{};
            barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            barrier.srcAccessMask = VK_ACCESS_MEMORY_READ_BIT;
            barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            barrier.oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
            barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
            barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            barrier.image = image;
            barrier.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};

            bluevk::vkCmdPipelineBarrier(
                commandBuffer,
                VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                0,
                0, nullptr,
                0, nullptr,
                1, &barrier
            );

            VkBufferImageCopy region{};
            region.bufferOffset = 0;
            region.bufferRowLength = 0;
            region.bufferImageHeight = 0;
            region.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
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
                PANIC_POSTCONDITION("Failed to end command buffer");
            }

            VkFenceCreateInfo fenceInfo{};
            fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;

            VkFence fence;
            result = bluevk::vkCreateFence(device, &fenceInfo, nullptr, &fence);
            if (result != VK_SUCCESS) {
                PANIC_POSTCONDITION("Failed to create fence");
            }

            VkSubmitInfo submitInfo{};
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &commandBuffer;

            result = bluevk::vkQueueSubmit(queue, 1, &submitInfo, fence);
            if (result != VK_SUCCESS) {
                bluevk::vkDestroyFence(device, fence, nullptr);
                PANIC_POSTCONDITION("Failed to submit queue");
            }

            result = bluevk::vkWaitForFences(device, 1, &fence, VK_TRUE, 5000000000ULL);
            if (result != VK_SUCCESS) {
                bluevk::vkDestroyFence(device, fence, nullptr);
                PANIC_POSTCONDITION("Failed to wait for fence");
            }

            void* data;
            result = bluevk::vkMapMemory(device, stagingBufferMemory, 0, bufferSize, 0, &data);
            if (result != VK_SUCCESS) {
                PANIC_POSTCONDITION("Failed to map memory");
            }

            outPixels.resize(bufferSize);
            memcpy(outPixels.data(), data, bufferSize);
            bluevk::vkUnmapMemory(device, stagingBufferMemory);

            bluevk::vkDestroyFence(device, fence, nullptr);
            vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer);
            vkDestroyBuffer(device, stagingBuffer, nullptr);
            vkFreeMemory(device, stagingBufferMemory, nullptr);

            std::cout << "Successfully completed readPixelsFromImage" << std::endl;
        }

        void* GetSharedContext() {
            return &_sharedContext;
        }

        filament::backend::Platform *GetPlatform() {
            return _platform.get();
        }

    private:
        struct Surface {
            HANDLE d3dHandle = nullptr;
            VkImage vkImage = VK_NULL_HANDLE;
            std::unique_ptr<thermion::windows::d3d::D3DTexture> d3dTexture;
            filament::backend::Platform::ExternalImageHandle externalImage;
        };

        VkInstance instance = VK_NULL_HANDLE;
        VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
        VkDevice device = VK_NULL_HANDLE;
        VkCommandPool commandPool = VK_NULL_HANDLE;
        VkQueue queue = VK_NULL_HANDLE;

        std::unique_ptr<thermion::windows::d3d::D3DContext> _d3dContext;
        std::vector<Surface> _surfaces;
        std::unique_ptr<WindowsVulkanPlatform> _platform;

        filament::backend::VulkanPlatform::VulkanSharedContext _sharedContext{};
};

HANDLE WindowsVulkanContext::CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {
    return pImpl->CreateRenderingSurface(width, height, left, top);
}

VkImage WindowsVulkanContext::GetVulkanImageForSurface(HANDLE handle) {
    return pImpl->GetVulkanImageForSurface(handle);
}

void* WindowsVulkanContext::CreateExternalImageForSurface(HANDLE handle) {
    return pImpl->CreateExternalImageForSurface(handle);
}

void WindowsVulkanContext::DestroyRenderingSurface(HANDLE handle) {
    pImpl->DestroyRenderingSurface(handle);
}

void* WindowsVulkanContext::GetSharedContext() {
    return pImpl->GetSharedContext();
}

void WindowsVulkanContext::readPixelsFromImage(
    uint32_t width,
    uint32_t height,
    std::vector<uint8_t>& outPixels
) {
    pImpl->readPixelsFromImage(width, height, outPixels);
}

filament::backend::Platform *WindowsVulkanContext::GetPlatform() {
    return pImpl->GetPlatform();
}

WindowsVulkanContext::WindowsVulkanContext() : pImpl(std::make_unique<WindowsVulkanContext::Impl>()) {}

WindowsVulkanContext::~WindowsVulkanContext() = default;

}
