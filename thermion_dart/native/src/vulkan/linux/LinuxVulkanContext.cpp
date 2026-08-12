#include "vulkan/linux/LinuxVulkanContext.h"
#include "vulkan/linux/LinuxVulkanTexture.h"
#include "vulkan/linux/LinuxVulkanUtils.h"
#include "vulkan/linux/LinuxVulkanPlatform.h"
#include "vulkan/ExternalVulkanImage.h"

#include <vector>
#include <memory>
#include <mutex>
#include <iostream>
#include <unordered_map>

#include "backend/platforms/VulkanPlatform.h"
#include "Log.hpp"

namespace thermion::vulkan::linux_platform {

using namespace bluevk;

namespace {

// Single-queue-hardware fallback. When the graphics family exposes only one
// queue, the blit worker and Filament's render thread both submit to queue 0.
// Vulkan requires external synchronization of every queue-level call, so we
// interpose the process-wide bluevk function-pointer globals with wrappers
// that serialize on this mutex. Filament's Vulkan backend (backend) and this
// blit worker are statically linked into the same thermion_dart.so and
// therefore dereference the SAME bluevk globals (declared extern in
// BlueVK.h), so interposing them here funnels both threads' submissions
// through one lock. On multi-queue HW this shim is never installed.
std::mutex sQueueMutex;

PFN_vkQueueSubmit     sRealQueueSubmit     = nullptr;
PFN_vkQueueSubmit2    sRealQueueSubmit2    = nullptr;
PFN_vkQueueWaitIdle   sRealQueueWaitIdle   = nullptr;
PFN_vkQueuePresentKHR sRealQueuePresentKHR = nullptr;
PFN_vkQueueBindSparse sRealQueueBindSparse = nullptr;

VKAPI_ATTR VkResult VKAPI_CALL SerializedQueueSubmit(VkQueue queue, uint32_t submitCount,
                                                     const VkSubmitInfo* pSubmits, VkFence fence) {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    return sRealQueueSubmit(queue, submitCount, pSubmits, fence);
}

VKAPI_ATTR VkResult VKAPI_CALL SerializedQueueSubmit2(VkQueue queue, uint32_t submitCount,
                                                      const VkSubmitInfo2* pSubmits, VkFence fence) {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    return sRealQueueSubmit2(queue, submitCount, pSubmits, fence);
}

VKAPI_ATTR VkResult VKAPI_CALL SerializedQueueWaitIdle(VkQueue queue) {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    return sRealQueueWaitIdle(queue);
}

VKAPI_ATTR VkResult VKAPI_CALL SerializedQueuePresentKHR(VkQueue queue,
                                                         const VkPresentInfoKHR* pPresentInfo) {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    return sRealQueuePresentKHR(queue, pPresentInfo);
}

VKAPI_ATTR VkResult VKAPI_CALL SerializedQueueBindSparse(VkQueue queue, uint32_t bindInfoCount,
                                                         const VkBindSparseInfo* pBindInfo, VkFence fence) {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    return sRealQueueBindSparse(queue, bindInfoCount, pBindInfo, fence);
}

// Idempotent: safe to call every frame. For each global, capture the current
// (real) pointer and reassign the global to our wrapper — but only when it is
// not already pointing at the wrapper, which prevents infinite recursion on
// re-install (Filament re-binds these globals on Engine (re)creation, dropping
// our shim, so BlitToExport re-calls this).
void InstallQueueSerializationShim() {
    static bool sLogged = false;
    bool swapped = false;

    if (bluevk::vkQueueSubmit && bluevk::vkQueueSubmit != &SerializedQueueSubmit) {
        sRealQueueSubmit = bluevk::vkQueueSubmit;
        bluevk::vkQueueSubmit = &SerializedQueueSubmit;
        swapped = true;
    }
    if (bluevk::vkQueueSubmit2 && bluevk::vkQueueSubmit2 != &SerializedQueueSubmit2) {
        sRealQueueSubmit2 = bluevk::vkQueueSubmit2;
        bluevk::vkQueueSubmit2 = &SerializedQueueSubmit2;
        swapped = true;
    }
    if (bluevk::vkQueueWaitIdle && bluevk::vkQueueWaitIdle != &SerializedQueueWaitIdle) {
        sRealQueueWaitIdle = bluevk::vkQueueWaitIdle;
        bluevk::vkQueueWaitIdle = &SerializedQueueWaitIdle;
        swapped = true;
    }
    if (bluevk::vkQueuePresentKHR && bluevk::vkQueuePresentKHR != &SerializedQueuePresentKHR) {
        sRealQueuePresentKHR = bluevk::vkQueuePresentKHR;
        bluevk::vkQueuePresentKHR = &SerializedQueuePresentKHR;
        swapped = true;
    }
    if (bluevk::vkQueueBindSparse && bluevk::vkQueueBindSparse != &SerializedQueueBindSparse) {
        sRealQueueBindSparse = bluevk::vkQueueBindSparse;
        bluevk::vkQueueBindSparse = &SerializedQueueBindSparse;
        swapped = true;
    }

    if (swapped && !sLogged) {
        sLogged = true;
        std::cerr << "[ThermionVk] Queue-submission serialization shim installed" << std::endl;
    }
}

} // namespace

class LinuxVulkanContext::Impl {
    public:
        ~Impl() {
            // Clean up blit resources
            if (_blitCmdBuffer != VK_NULL_HANDLE && _blitResources.commandPool != VK_NULL_HANDLE) {
                vkFreeCommandBuffers(device, _blitResources.commandPool, 1, &_blitCmdBuffer);
                _blitCmdBuffer = VK_NULL_HANDLE;
            }
            if (_blitFence != VK_NULL_HANDLE) {
                vkDestroyFence(device, _blitFence, nullptr);
                _blitFence = VK_NULL_HANDLE;
            }
            if (_blitResources.commandPool != VK_NULL_HANDLE) {
                vkDestroyCommandPool(device, _blitResources.commandPool, nullptr);
                _blitResources.commandPool = VK_NULL_HANDLE;
            }
        }

        Impl() {
            std::cerr << "[ThermionVk:Context] Initializing BluevK..." << std::endl;
            bluevk::initialize();

            // Create Vulkan instance
            VkResult result = createVulkanInstance(&instance);
            if (result != VK_SUCCESS)
            {
                LOG_ERROR("Failed to create Vulkan instance: %s", VkResultToString(result));
                return;
            }
            bluevk::bindInstance(instance);
            std::cerr << "[ThermionVk:Context] Vulkan instance created OK" << std::endl;

            uint32_t queueFamilyIndex = 0;
            result = createLogicalDevice(instance, &physicalDevice, &device, &queueFamilyIndex);
            if (result != VK_SUCCESS)
            {
                LOG_ERROR("Failed to create logical device: %s", VkResultToString(result));
                vkDestroyInstance(instance, nullptr);
                return;
            }
            std::cerr << "[ThermionVk:Context] Logical device created OK" << std::endl;

            _sharedContext.instance = instance;
            _sharedContext.physicalDevice = physicalDevice;
            _sharedContext.logicalDevice = device;
            _sharedContext.graphicsQueueFamilyIndex = queueFamilyIndex;
            _sharedContext.graphicsQueueIndex = 0;
            _sharedContext.debugUtilsSupported = false;
            _sharedContext.debugMarkersSupported = false;
            _sharedContext.multiviewSupported = false;

            std::cerr << "[ThermionVk:Context] SharedContext: queueFamily=" << queueFamilyIndex
                      << " queueIndex=0" << std::endl;
        }

        int64_t CreateRenderingSurface(uint32_t width, uint32_t height) {
            int64_t surfaceId = _nextSurfaceId++;

            // Try block-linear first (zero-copy path)
            auto exportableTexture = LinuxVulkanTexture::createExportable(device, physicalDevice, width, height);
            if (exportableTexture) {
                std::cerr << "[ThermionVk:Context] Surface " << surfaceId
                          << ": using block-linear path (modifier=0x"
                          << std::hex << exportableTexture->GetDrmModifier() << std::dec << ")"
                          << std::endl;
                _exportableTextures[surfaceId] = std::move(exportableTexture);
                return surfaceId;
            }

            // Fall back to blit mode
            std::cerr << "[ThermionVk:Context] Surface " << surfaceId
                      << ": block-linear failed, trying blit fallback" << std::endl;
            auto blitTexture = LinuxVulkanTexture::createWithBlit(device, physicalDevice, width, height);
            if (blitTexture) {
                std::cerr << "[ThermionVk:Context] Surface " << surfaceId
                          << ": using blit fallback path" << std::endl;
                _exportableTextures[surfaceId] = std::move(blitTexture);
                return surfaceId;
            }

            LOG_ERROR("Failed to create rendering surface (both block-linear and blit failed)");
            _nextSurfaceId--;
            return -1;
        }

        void DestroyRenderingSurface(int64_t surfaceId) {
            _exportableTextures.erase(surfaceId);
        }

        VkImage GetVulkanImageForSurface(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetImage();
            }
            return VK_NULL_HANDLE;
        }

        SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it == _exportableTextures.end()) {
                return {-1, 0, 0, 0, 0, 0, 0};
            }
            auto& s = it->second;
            return {
                s->GetDmaBufFd(),
                s->GetStride(),
                s->GetOffset(),
                s->GetDrmFormat(),
                s->GetDrmModifier(),
                s->GetWidth(),
                s->GetHeight()
            };
        }

        int NeedsBlit(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->NeedsBlit() ? 1 : 0;
            }
            return 0;
        }

        void BlitToExport(int64_t surfaceId) {
            auto it = _exportableTextures.find(surfaceId);
            if (it == _exportableTextures.end() || !it->second->NeedsBlit()) {
                return;
            }

            auto& texture = it->second;
            VkImage renderImage = texture->GetRenderImage();
            VkImage exportImage = texture->GetImage();  // base _image is the export image
            uint32_t width = texture->GetWidth();
            uint32_t height = texture->GetHeight();

            // Lazy-init blit command resources
            if (_blitResources.commandPool == VK_NULL_HANDLE) {
                _blitResources = createCommandResources(device, physicalDevice);

                VkFenceCreateInfo fenceInfo = {
                    .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                    .pNext = nullptr,
                    .flags = 0
                };
                vkCreateFence(device, &fenceInfo, nullptr, &_blitFence);

                VkCommandBufferAllocateInfo cmdAllocInfo = {
                    .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                    .pNext = nullptr,
                    .commandPool = _blitResources.commandPool,
                    .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                    .commandBufferCount = 1
                };
                vkAllocateCommandBuffers(device, &cmdAllocInfo, &_blitCmdBuffer);

                std::cerr << "[ThermionVk:Context] Blit resources initialized" << std::endl;
            }

            // Single-queue HW: the blit shares Filament's queue 0, so serialize
            // queue calls. Re-installed per frame (idempotent) to survive
            // Filament re-binding the bluevk globals on Engine (re)creation.
            if (_blitResources.queueSharedWithFilament) {
                InstallQueueSerializationShim();
            }

            // Wait for Filament's GPU work to finish
            vkDeviceWaitIdle(device);

            // Reset and record command buffer
            vkResetCommandBuffer(_blitCmdBuffer, 0);

            VkCommandBufferBeginInfo beginInfo = {
                .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
                .pNext = nullptr,
                .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
                .pInheritanceInfo = nullptr
            };
            vkBeginCommandBuffer(_blitCmdBuffer, &beginInfo);

            // Barrier: render image → TRANSFER_SRC_OPTIMAL
            VkImageMemoryBarrier renderBarrier = {
                .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                .pNext = nullptr,
                .srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                .dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT,
                .oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                .newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .image = renderImage,
                .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}
            };

            // Barrier: export image → TRANSFER_DST_OPTIMAL
            VkImageMemoryBarrier exportBarrier = {
                .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                .pNext = nullptr,
                .srcAccessMask = 0,
                .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                .oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                .newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .image = exportImage,
                .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}
            };

            VkImageMemoryBarrier preBarriers[] = {renderBarrier, exportBarrier};
            vkCmdPipelineBarrier(_blitCmdBuffer,
                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                0, 0, nullptr, 0, nullptr,
                2, preBarriers);

            // Copy render → export
            VkImageCopy copyRegion = {
                .srcSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1},
                .srcOffset = {0, 0, 0},
                .dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1},
                .dstOffset = {0, 0, 0},
                .extent = {width, height, 1}
            };
            vkCmdCopyImage(_blitCmdBuffer,
                renderImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                exportImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                1, &copyRegion);

            // Post-blit barriers
            // Render image → COLOR_ATTACHMENT_OPTIMAL (ready for next frame)
            VkImageMemoryBarrier renderPostBarrier = {
                .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                .pNext = nullptr,
                .srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT,
                .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                .oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                .newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .image = renderImage,
                .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}
            };

            // Export image → GENERAL (ready for EGL to read)
            VkImageMemoryBarrier exportPostBarrier = {
                .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                .pNext = nullptr,
                .srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                .dstAccessMask = VK_ACCESS_MEMORY_READ_BIT,
                .oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                .newLayout = VK_IMAGE_LAYOUT_GENERAL,
                .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                .image = exportImage,
                .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}
            };

            VkImageMemoryBarrier postBarriers[] = {renderPostBarrier, exportPostBarrier};
            vkCmdPipelineBarrier(_blitCmdBuffer,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                0, 0, nullptr, 0, nullptr,
                2, postBarriers);

            vkEndCommandBuffer(_blitCmdBuffer);

            // Submit and wait
            vkResetFences(device, 1, &_blitFence);

            VkSubmitInfo submitInfo = {
                .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
                .pNext = nullptr,
                .waitSemaphoreCount = 0,
                .pWaitSemaphores = nullptr,
                .pWaitDstStageMask = nullptr,
                .commandBufferCount = 1,
                .pCommandBuffers = &_blitCmdBuffer,
                .signalSemaphoreCount = 0,
                .pSignalSemaphores = nullptr
            };

            VkResult result = vkQueueSubmit(_blitResources.queue, 1, &submitInfo, _blitFence);
            if (result != VK_SUCCESS) {
                std::cerr << "[ThermionVk:Context] ERROR: Blit vkQueueSubmit failed: "
                          << VkResultToString(result) << std::endl;
                return;
            }

            vkWaitForFences(device, 1, &_blitFence, VK_TRUE, UINT64_MAX);
        }

        void* GetSharedContext() {
            return &_sharedContext;
        }

        void* GetPlatform() {
            return _platform.get();
        }

        void* CreateExternalImageForSurface(int64_t surfaceId) {
            std::cerr << "[ThermionVk:Context] CreateExternalImageForSurface surfaceId=" << surfaceId << std::endl;

            auto it = _exportableTextures.find(surfaceId);
            if (it == _exportableTextures.end()) {
                std::cerr << "[ThermionVk:Context] ERROR: surfaceId " << surfaceId << " not found" << std::endl;
                return nullptr;
            }

            auto& texture = it->second;
            auto* ext = new thermion::vulkan::ExternalVulkanImage();

            // In blit mode, Filament renders to the render image
            // In block-linear mode, Filament renders to the main image
            ext->image = texture->GetRenderImage();
            ext->memory = texture->GetRenderMemory();
            ext->format = VK_FORMAT_R8G8B8A8_UNORM;
            ext->width = texture->GetWidth();
            ext->height = texture->GetHeight();
            ext->layers = 1;
            ext->usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
            if (!texture->NeedsBlit()) {
                ext->usage |= VK_IMAGE_USAGE_TRANSFER_DST_BIT;
            }
            ext->allocationSize = texture->GetAllocationSize();
            ext->memoryTypeBits = texture->GetMemoryTypeBits();
            ext->filamentFormat = filament::backend::TextureFormat::RGBA8;
            ext->filamentUsage = filament::backend::TextureUsage::COLOR_ATTACHMENT;

            std::cerr << "[ThermionVk:Context] ExternalVulkanImage created:"
                      << " image=0x" << std::hex << reinterpret_cast<uintptr_t>(ext->image)
                      << " memory=0x" << reinterpret_cast<uintptr_t>(ext->memory) << std::dec
                      << " format=R8G8B8A8_UNORM"
                      << " " << ext->width << "x" << ext->height
                      << " usage=0x" << std::hex << ext->usage << std::dec
                      << " blit=" << (texture->NeedsBlit() ? "YES" : "NO")
                      << std::endl;

            return ext;
        }

    private:
        VkInstance instance = VK_NULL_HANDLE;
        VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
        VkDevice device = VK_NULL_HANDLE;

        std::unordered_map<int64_t, std::unique_ptr<LinuxVulkanTexture>> _exportableTextures;

        filament::backend::VulkanPlatform::VulkanSharedContext _sharedContext{};

        std::unique_ptr<thermion::vulkan::VulkanPlatform> _platform =
            std::make_unique<thermion::vulkan::VulkanPlatform>();

        int64_t _nextSurfaceId = 1;

        // Blit resources (shared across all surfaces, lazy-initialized)
        CommandResources _blitResources{};
        VkFence _blitFence = VK_NULL_HANDLE;
        VkCommandBuffer _blitCmdBuffer = VK_NULL_HANDLE;
};

int64_t LinuxVulkanContext::CreateRenderingSurface(uint32_t width, uint32_t height) {
    return pImpl->CreateRenderingSurface(width, height);
}

VkImage LinuxVulkanContext::GetVulkanImageForSurface(int64_t surfaceId) {
    return pImpl->GetVulkanImageForSurface(surfaceId);
}

SurfaceExportInfo LinuxVulkanContext::GetSurfaceExportInfo(int64_t surfaceId) {
    return pImpl->GetSurfaceExportInfo(surfaceId);
}

int LinuxVulkanContext::NeedsBlit(int64_t surfaceId) {
    return pImpl->NeedsBlit(surfaceId);
}

void LinuxVulkanContext::BlitToExport(int64_t surfaceId) {
    pImpl->BlitToExport(surfaceId);
}

void LinuxVulkanContext::DestroyRenderingSurface(int64_t surfaceId) {
    pImpl->DestroyRenderingSurface(surfaceId);
}

void* LinuxVulkanContext::GetSharedContext() {
    return pImpl->GetSharedContext();
}

void* LinuxVulkanContext::GetPlatform() {
    return pImpl->GetPlatform();
}

void* LinuxVulkanContext::CreateExternalImageForSurface(int64_t surfaceId) {
    return pImpl->CreateExternalImageForSurface(surfaceId);
}

LinuxVulkanContext::LinuxVulkanContext() : pImpl(std::make_unique<LinuxVulkanContext::Impl>()) {}

LinuxVulkanContext::~LinuxVulkanContext() = default;

} // namespace thermion::vulkan::linux
