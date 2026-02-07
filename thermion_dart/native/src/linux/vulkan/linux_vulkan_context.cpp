#include "linux_vulkan_context.h"
#include "linux_vulkan_context_api.h"
#include "linux_vulkan_texture.h"
#include "linux_vulkan_platform.h"
#include "linux_vulkan_utils.h"

#include <iostream>
#include <vector>
#include <memory>
#include <unordered_map>

#include "filament/backend/platforms/VulkanPlatform.h"
#include "Log.hpp"

namespace thermion::linux_platform::vulkan {

using namespace bluevk;

class ThermionLinuxVulkanContext::Impl {
    public:
        ~Impl() {
            std::cerr << "ThermionLinuxVulkanContext destructor: "
                      << _exportableTextures.size() << " exportable textures remain" << std::endl;
            if (blitFence != VK_NULL_HANDLE) {
                bluevk::vkDestroyFence(device, blitFence, nullptr);
            }
            if (blitCommandBuffer != VK_NULL_HANDLE) {
                bluevk::vkFreeCommandBuffers(device, commandPool, 1, &blitCommandBuffer);
            }
            if (commandPool != VK_NULL_HANDLE) {
                bluevk::vkDestroyCommandPool(device, commandPool, nullptr);
            }
        }

        Impl() {
            bluevk::initialize();

            // Create Vulkan instance
            VkResult result = createVulkanInstance(&instance);
            if (result != VK_SUCCESS)
            {
                std::cout << "[ERROR] Failed to create Vulkan instance! Error: " << VkResultToString(result) << std::endl;
                return;
            }
            bluevk::bindInstance(instance);

            uint32_t queueFamilyIndex = 0;
            result = createLogicalDevice(instance, &physicalDevice, &device, &queueFamilyIndex);
            if (result != VK_SUCCESS)
            {
                std::cout << "[ERROR] Failed to create logical device! Error: " << VkResultToString(result) << std::endl;
                vkDestroyInstance(instance, nullptr);
                return;
            }
            _sharedContext.instance = instance;
            _sharedContext.physicalDevice = physicalDevice;
            _sharedContext.logicalDevice = device;
            _sharedContext.graphicsQueueFamilyIndex = queueFamilyIndex;
            _sharedContext.graphicsQueueIndex = 0;
            _sharedContext.debugUtilsSupported = false;
            _sharedContext.debugMarkersSupported = false;
            _sharedContext.multiviewSupported = false;

            std::cout << "[INFO] Vulkan logical device created with queue family index "
                      << queueFamilyIndex << std::endl;

            CommandResources cmdResources = createCommandResources(device, physicalDevice);
            commandPool = cmdResources.commandPool;
            queue = cmdResources.queue;
            std::cout << "[INFO] Vulkan command resources using queue family index "
                      << cmdResources.queueFamilyIndex << std::endl;

            _platform = std::make_unique<TVulkanPlatform>();

            // Command buffer allocation
            VkCommandBufferAllocateInfo cmdBufInfo{};
            cmdBufInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
            cmdBufInfo.commandPool = commandPool;
            cmdBufInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            cmdBufInfo.commandBufferCount = 1;

            vkAllocateCommandBuffers(device, &cmdBufInfo, &blitCommandBuffer);

            // Create blit fence
            VkFenceCreateInfo fenceInfo{};
            fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
            fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
            VkResult fenceResult = bluevk::vkCreateFence(device, &fenceInfo, nullptr, &blitFence);
            if (fenceResult != VK_SUCCESS) {
                std::cout << "[ERROR] Failed to create blit fence" << std::endl;
            }
        }

        int64_t CreateRenderingSurface(uint32_t width, uint32_t height) {
            std::cout << "[ThermionLinux] Creating rendering surface " << width << "x" << height << std::endl;

            // Create exportable dmabuf-backed texture (the only texture needed now)
            auto exportableTexture = LinuxVulkanTexture::createExportable(device, physicalDevice, width, height);
            if (!exportableTexture) {
                std::cerr << "Failed to create exportable dmabuf texture" << std::endl;
                return -1;
            }

            int64_t surfaceId = _nextSurfaceId++;
            _exportableTextures[surfaceId] = std::move(exportableTexture);

            std::cout << "[ThermionLinux] Created rendering surface ID " << surfaceId << std::endl;
            return surfaceId;
        }

        void DestroyRenderingSurface(int64_t surfaceId) {
            std::cerr << "Destroying rendering surface " << surfaceId << std::endl;
            // Wait for any in-flight blit to complete before destroying the texture
            if (blitFence != VK_NULL_HANDLE) {
                bluevk::vkWaitForFences(device, 1, &blitFence, VK_TRUE, UINT64_MAX);
            }
            _exportableTextures.erase(surfaceId);
            std::cerr << "Rendering surface destroyed, "
                      << _exportableTextures.size() << " exportable textures remain" << std::endl;
        }

        VkImage GetVulkanImageForSurface(int64_t surfaceId) {
            // Vulkan backend does not support Texture::Builder::import(),
            // so we return VK_NULL_HANDLE (0). The Dart side will detect this
            // and use a headless swapchain instead of a RenderTarget.
            return VK_NULL_HANDLE;
        }

        int GetDmaBufFd(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetDmaBufFd();
            }
            return -1;
        }

        uint32_t GetDrmFormat(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetDrmFormat();
            }
            return 0;
        }

        uint32_t GetStride(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetStride();
            }
            return 0;
        }

        uint32_t GetOffset(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetOffset();
            }
            return 0;
        }

        uint32_t GetWidth(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetWidth();
            }
            return 0;
        }

        uint32_t GetHeight(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetHeight();
            }
            return 0;
        }

        void Blit(int64_t surfaceId) {
            static int blitCount = 0;
            blitCount++;

            auto exIt = _exportableTextures.find(surfaceId);

            if (exIt == _exportableTextures.end()) {
                std::cerr << "Surface ID " << surfaceId << " not found for blit" << std::endl;
                return;
            }

            // Source from the swapchain image that Filament just rendered to
            auto srcImage = _platform->getLastRenderedImage();
            if (srcImage == VK_NULL_HANDLE) {
                std::cerr << "No swapchain image available for blit (not rendered yet?)" << std::endl;
                return;
            }

            auto dstImage = exIt->second->GetImage();
            auto width = exIt->second->GetWidth();
            auto height = exIt->second->GetHeight();

            if (blitCount <= 3 || blitCount % 60 == 0) {
                std::cout << "[Blit #" << blitCount << "] src=" << (uint64_t)srcImage
                          << " dst=" << (uint64_t)dstImage
                          << " " << width << "x" << height << std::endl;
            }

            // Wait for all submitted GPU work to complete before recording blit commands.
            // By this point, flushAndWait() in RenderManager::render() has ensured
            // Filament's backend thread is idle, so this call is thread-safe.
            bluevk::vkQueueWaitIdle(queue);

            VkResult result = bluevk::vkResetCommandBuffer(blitCommandBuffer, 0);
            if (result != VK_SUCCESS) {
                std::cout << "Failed to reset command buffer: " << result << std::endl;
                return;
            }

            // Begin command buffer
            VkCommandBufferBeginInfo beginInfo{};
            beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
            beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

            result = bluevk::vkBeginCommandBuffer(blitCommandBuffer, &beginInfo);
            if (result != VK_SUCCESS) {
                std::cout << "Failed to begin command buffer: " << result << std::endl;
                return;
            }

            // Source barrier: swapchain image (COLOR_ATTACHMENT_OPTIMAL -> TRANSFER_SRC_OPTIMAL)
            // transitionSwapChainImageLayoutForPresent is false, so the image stays in
            // COLOR_ATTACHMENT_OPTIMAL after Filament's render pass.
            VkImageMemoryBarrier srcBarrier{};
            srcBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            srcBarrier.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            srcBarrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            srcBarrier.oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            srcBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
            srcBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            srcBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            srcBarrier.image = srcImage;
            srcBarrier.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};

            // Destination barrier: exportable texture (UNDEFINED -> TRANSFER_DST_OPTIMAL)
            VkImageMemoryBarrier dstBarrier{};
            dstBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            dstBarrier.srcAccessMask = 0;
            dstBarrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            dstBarrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
            dstBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            dstBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            dstBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            dstBarrier.image = dstImage;
            dstBarrier.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};

            // Pre-blit barriers
            VkImageMemoryBarrier preBlitBarriers[] = {srcBarrier, dstBarrier};
            vkCmdPipelineBarrier(
                blitCommandBuffer,
                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                0,
                0, nullptr,
                0, nullptr,
                2, preBlitBarriers
            );

            // Define copy region (same dimensions, no scaling needed)
            VkImageCopy region{};
            region.srcSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
            region.srcOffset = {0, 0, 0};
            region.dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
            region.dstOffset = {0, 0, 0};
            region.extent = {width, height, 1};

            // Use vkCmdCopyImage instead of vkCmdBlitImage because the destination
            // uses VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT which may not support
            // VK_FORMAT_FEATURE_BLIT_DST_BIT.
            bluevk::vkCmdCopyImage(
                blitCommandBuffer,
                srcImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                dstImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                1, &region
            );

            // Post-blit barriers
            // Source: transition back to COLOR_ATTACHMENT_OPTIMAL for next render
            srcBarrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            srcBarrier.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            srcBarrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
            srcBarrier.newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

            // Destination: transition to SHADER_READ_ONLY_OPTIMAL for EGL sampling
            dstBarrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
            dstBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
            dstBarrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
            dstBarrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

            VkImageMemoryBarrier postBlitBarriers[] = {srcBarrier, dstBarrier};
            bluevk::vkCmdPipelineBarrier(
                blitCommandBuffer,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                0,
                0, nullptr,
                0, nullptr,
                2, postBlitBarriers
            );

            // End command buffer
            result = bluevk::vkEndCommandBuffer(blitCommandBuffer);
            if (result != VK_SUCCESS) {
                std::cout << "Failed to end command buffer: " << result << std::endl;
                return;
            }

            // Submit
            VkSubmitInfo submitInfo{};
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &blitCommandBuffer;

            bluevk::vkResetFences(device, 1, &blitFence);

            result = bluevk::vkQueueSubmit(queue, 1, &submitInfo, blitFence);
            if (result != VK_SUCCESS) {
                std::cout << "Failed to submit queue: " << result << std::endl;
                return;
            }

            // Wait for blit to complete before returning
            result = bluevk::vkWaitForFences(device, 1, &blitFence, VK_TRUE, UINT64_MAX);
            if (result != VK_SUCCESS) {
                std::cout << "Failed to wait for blit fence: " << result << std::endl;
            }
        }

        filament::backend::VulkanPlatform *GetPlatform() {
            return _platform.get();
        }

        void* GetSharedContext() {
            return &_sharedContext;
        }

    private:
        VkInstance instance = VK_NULL_HANDLE;
        VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
        VkDevice device = VK_NULL_HANDLE;
        VkCommandPool commandPool = VK_NULL_HANDLE;
        VkCommandBuffer blitCommandBuffer = VK_NULL_HANDLE;
        VkFence blitFence = VK_NULL_HANDLE;
        VkQueue queue = VK_NULL_HANDLE;

        std::unordered_map<int64_t, std::unique_ptr<LinuxVulkanTexture>> _exportableTextures;

        std::unique_ptr<TVulkanPlatform> _platform;
        filament::backend::VulkanPlatform::VulkanSharedContext _sharedContext{};

        int64_t _nextSurfaceId = 1;
};

int64_t ThermionLinuxVulkanContext::CreateRenderingSurface(uint32_t width, uint32_t height) {
    return pImpl->CreateRenderingSurface(width, height);
}

VkImage ThermionLinuxVulkanContext::GetVulkanImageForSurface(int64_t surfaceId) {
    return pImpl->GetVulkanImageForSurface(surfaceId);
}

int ThermionLinuxVulkanContext::GetDmaBufFd(int64_t surfaceId) {
    return pImpl->GetDmaBufFd(surfaceId);
}

uint32_t ThermionLinuxVulkanContext::GetDrmFormat(int64_t surfaceId) {
    return pImpl->GetDrmFormat(surfaceId);
}

uint32_t ThermionLinuxVulkanContext::GetStride(int64_t surfaceId) {
    return pImpl->GetStride(surfaceId);
}

uint32_t ThermionLinuxVulkanContext::GetOffset(int64_t surfaceId) {
    return pImpl->GetOffset(surfaceId);
}

uint32_t ThermionLinuxVulkanContext::GetWidth(int64_t surfaceId) {
    return pImpl->GetWidth(surfaceId);
}

uint32_t ThermionLinuxVulkanContext::GetHeight(int64_t surfaceId) {
    return pImpl->GetHeight(surfaceId);
}

void ThermionLinuxVulkanContext::DestroyRenderingSurface(int64_t surfaceId) {
    pImpl->DestroyRenderingSurface(surfaceId);
}

void ThermionLinuxVulkanContext::Blit(int64_t surfaceId) {
    pImpl->Blit(surfaceId);
}

filament::backend::VulkanPlatform *ThermionLinuxVulkanContext::GetPlatform() {
    return pImpl->GetPlatform();
}

void* ThermionLinuxVulkanContext::GetSharedContext() {
    return pImpl->GetSharedContext();
}

ThermionLinuxVulkanContext::ThermionLinuxVulkanContext() : pImpl(std::make_unique<ThermionLinuxVulkanContext::Impl>()) {}

ThermionLinuxVulkanContext::~ThermionLinuxVulkanContext() = default;

} // namespace thermion::linux_platform::vulkan

// C API implementation
using Context = thermion::linux_platform::vulkan::ThermionLinuxVulkanContext;

extern "C" {

ThermionLinuxVulkanContextHandle ThermionLinuxVulkanContext_Create() {
    return reinterpret_cast<ThermionLinuxVulkanContextHandle>(new Context());
}

void ThermionLinuxVulkanContext_Destroy(ThermionLinuxVulkanContextHandle ctx) {
    delete reinterpret_cast<Context*>(ctx);
}

int64_t ThermionLinuxVulkanContext_CreateRenderingSurface(
    ThermionLinuxVulkanContextHandle ctx, uint32_t width, uint32_t height) {
    return reinterpret_cast<Context*>(ctx)->CreateRenderingSurface(width, height);
}

void ThermionLinuxVulkanContext_DestroyRenderingSurface(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    reinterpret_cast<Context*>(ctx)->DestroyRenderingSurface(surfaceId);
}

int64_t ThermionLinuxVulkanContext_GetVulkanImage(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    auto img = reinterpret_cast<Context*>(ctx)->GetVulkanImageForSurface(surfaceId);
    return static_cast<int64_t>(reinterpret_cast<intptr_t>(img));
}

int ThermionLinuxVulkanContext_GetDmaBufFd(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    return reinterpret_cast<Context*>(ctx)->GetDmaBufFd(surfaceId);
}

uint32_t ThermionLinuxVulkanContext_GetDrmFormat(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    return reinterpret_cast<Context*>(ctx)->GetDrmFormat(surfaceId);
}

uint32_t ThermionLinuxVulkanContext_GetStride(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    return reinterpret_cast<Context*>(ctx)->GetStride(surfaceId);
}

uint32_t ThermionLinuxVulkanContext_GetOffset(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    return reinterpret_cast<Context*>(ctx)->GetOffset(surfaceId);
}

uint32_t ThermionLinuxVulkanContext_GetWidth(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    return reinterpret_cast<Context*>(ctx)->GetWidth(surfaceId);
}

uint32_t ThermionLinuxVulkanContext_GetHeight(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    return reinterpret_cast<Context*>(ctx)->GetHeight(surfaceId);
}

void ThermionLinuxVulkanContext_Blit(
    ThermionLinuxVulkanContextHandle ctx, int64_t surfaceId) {
    reinterpret_cast<Context*>(ctx)->Blit(surfaceId);
}

int64_t ThermionLinuxVulkanContext_GetPlatform(
    ThermionLinuxVulkanContextHandle ctx) {
    return reinterpret_cast<int64_t>(reinterpret_cast<Context*>(ctx)->GetPlatform());
}

int64_t ThermionLinuxVulkanContext_GetSharedContext(
    ThermionLinuxVulkanContextHandle ctx) {
    return reinterpret_cast<int64_t>(reinterpret_cast<Context*>(ctx)->GetSharedContext());
}

} // extern "C"
