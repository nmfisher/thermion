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

constexpr uint64_t kBlitFenceTimeoutNs = 50'000'000ULL;      // 50 ms per-frame cap
constexpr uint64_t kInitBlitFenceTimeoutNs = 1'000'000'000ULL; // 1 s init/teardown cap

// Blit-fallback queue synchronization.
//
// In blit mode, BlitToExport() runs on Flutter's Dart/platform thread while
// Filament's Vulkan backend submits on its own driver thread. Vulkan requires
// external host synchronization on every VkQueue (and across all device queues
// during vkDeviceWaitIdle). Even on two-queue hardware, waiting on Filament's
// queue 0 before copying renderImage on queue 1 must serialize host access to
// queue 0 and keep Filament from starting a new render pass into renderImage
// while the copy is in flight.
//
// Filament's Vulkan backend and thermion_dart share the same process-wide
// bluevk function-pointer globals in thermion_dart.so, so interposing them here
// funnels both threads through sQueueMutex. On zero-copy surfaces (NeedsBlit ==
// false) this shim is never installed.
std::mutex sQueueMutex;

PFN_vkQueueSubmit      sRealQueueSubmit      = nullptr;
PFN_vkQueueSubmit2     sRealQueueSubmit2     = nullptr;
PFN_vkQueueSubmit2KHR  sRealQueueSubmit2KHR  = nullptr;
PFN_vkQueueWaitIdle    sRealQueueWaitIdle    = nullptr;
PFN_vkQueuePresentKHR  sRealQueuePresentKHR  = nullptr;
PFN_vkQueueBindSparse  sRealQueueBindSparse  = nullptr;
PFN_vkDeviceWaitIdle   sRealDeviceWaitIdle   = nullptr;

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

VKAPI_ATTR VkResult VKAPI_CALL SerializedQueueSubmit2KHR(VkQueue queue, uint32_t submitCount,
                                                         const VkSubmitInfo2* pSubmits, VkFence fence) {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    return sRealQueueSubmit2KHR(queue, submitCount, pSubmits, fence);
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

VKAPI_ATTR VkResult VKAPI_CALL SerializedDeviceWaitIdle(VkDevice dev) {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    return sRealDeviceWaitIdle(dev);
}

// Caller must hold sQueueMutex. Idempotent: safe to call every frame so the
// shim survives Filament re-binding bluevk globals on Engine (re)creation.
void InstallQueueSerializationShimLocked() {
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
    if (bluevk::vkQueueSubmit2KHR && bluevk::vkQueueSubmit2KHR != &SerializedQueueSubmit2KHR) {
        sRealQueueSubmit2KHR = bluevk::vkQueueSubmit2KHR;
        bluevk::vkQueueSubmit2KHR = &SerializedQueueSubmit2KHR;
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
    if (bluevk::vkDeviceWaitIdle && bluevk::vkDeviceWaitIdle != &SerializedDeviceWaitIdle) {
        sRealDeviceWaitIdle = bluevk::vkDeviceWaitIdle;
        bluevk::vkDeviceWaitIdle = &SerializedDeviceWaitIdle;
        swapped = true;
    }

    if (swapped && !sLogged) {
        sLogged = true;
        std::cerr << "[ThermionVk] Queue-submission serialization shim installed" << std::endl;
    }
}

void InstallQueueSerializationShim() {
    std::lock_guard<std::mutex> lock(sQueueMutex);
    InstallQueueSerializationShimLocked();
}

// Helpers invoked while sQueueMutex is already held by the caller.
VkResult SubmitQueueLocked(VkQueue queue, uint32_t submitCount,
                           const VkSubmitInfo* pSubmits, VkFence fence) {
    PFN_vkQueueSubmit fn = (bluevk::vkQueueSubmit == &SerializedQueueSubmit)
        ? sRealQueueSubmit
        : bluevk::vkQueueSubmit;
    return fn ? fn(queue, submitCount, pSubmits, fence) : VK_ERROR_INITIALIZATION_FAILED;
}

VkResult WaitQueueIdleLocked(VkQueue queue) {
    PFN_vkQueueWaitIdle fn = (bluevk::vkQueueWaitIdle == &SerializedQueueWaitIdle)
        ? sRealQueueWaitIdle
        : bluevk::vkQueueWaitIdle;
    return fn ? fn(queue) : VK_ERROR_INITIALIZATION_FAILED;
}

VkResult WaitDeviceIdleLocked(VkDevice dev) {
    PFN_vkDeviceWaitIdle fn = (bluevk::vkDeviceWaitIdle == &SerializedDeviceWaitIdle)
        ? sRealDeviceWaitIdle
        : bluevk::vkDeviceWaitIdle;
    return fn ? fn(dev) : VK_ERROR_INITIALIZATION_FAILED;
}

} // namespace

class LinuxVulkanContext::Impl {
    public:
        ~Impl() {
            std::lock_guard<std::mutex> contextLock(_contextMutex);

            if (device != VK_NULL_HANDLE && (_blitFencePending || !_exportableTextures.empty())) {
                std::lock_guard<std::mutex> queueLock(sQueueMutex);
                InstallQueueSerializationShimLocked();
                WaitDeviceIdleLocked(device);
                _blitFencePending = false;
            }

            // Destroy remaining surfaces before tearing down device-level blit objects.
            _exportableTextures.clear();

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
                instance = VK_NULL_HANDLE;
                return;
            }
            std::cerr << "[ThermionVk:Context] Logical device created OK" << std::endl;

            vkGetDeviceQueue(device, queueFamilyIndex, 0, &_filamentQueue);

            _sharedContext.instance = instance;
            _sharedContext.physicalDevice = physicalDevice;
            _sharedContext.logicalDevice = device;
            _sharedContext.graphicsQueueFamilyIndex = queueFamilyIndex;
            _sharedContext.graphicsQueueIndex = 0;
            _sharedContext.debugUtilsEnabled = false;
            _sharedContext.debugMarkersSupported = false;
            _sharedContext.multiviewSupported = false;

            std::cerr << "[ThermionVk:Context] SharedContext: queueFamily=" << queueFamilyIndex
                      << " queueIndex=0" << std::endl;
        }

        int64_t CreateRenderingSurface(uint32_t width, uint32_t height) {
            std::lock_guard<std::mutex> contextLock(_contextMutex);
            if (device == VK_NULL_HANDLE) {
                LOG_ERROR("Cannot create Vulkan rendering surface: logical device is null");
                return -1;
            }

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
                InstallQueueSerializationShim();
                if (!InitializeBlitSurfaceLocked(*blitTexture)) {
                    LOG_ERROR("Failed to initialize blit fallback surface");
                    _nextSurfaceId--;
                    return -1;
                }
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
            std::lock_guard<std::mutex> contextLock(_contextMutex);
            auto it = _exportableTextures.find(surfaceId);
            if (it == _exportableTextures.end()) {
                return;
            }
            if (it->second->NeedsBlit()) {
                WaitPendingBlitFenceLocked(kInitBlitFenceTimeoutNs);
                InstallQueueSerializationShim();
            }
            _exportableTextures.erase(it);
        }

        VkImage GetVulkanImageForSurface(int64_t surfaceId) {
            std::lock_guard<std::mutex> contextLock(_contextMutex);
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->GetImage();
            }
            return VK_NULL_HANDLE;
        }

        SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId) {
            std::lock_guard<std::mutex> contextLock(_contextMutex);
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
            std::lock_guard<std::mutex> contextLock(_contextMutex);
            auto it = _exportableTextures.find(surfaceId);
            if (it != _exportableTextures.end()) {
                return it->second->NeedsBlit() ? 1 : 0;
            }
            return 0;
        }

        void BlitToExport(int64_t surfaceId) {
            std::lock_guard<std::mutex> contextLock(_contextMutex);
            auto it = _exportableTextures.find(surfaceId);
            if (it == _exportableTextures.end() || !it->second->NeedsBlit()) {
                return;
            }

            if (!EnsureBlitResourcesLocked()) {
                return;
            }

            // If a previous blit timed out, _blitCmdBuffer is still in flight on
            // the GPU. Wait before resetting it; skip this frame if still busy.
            if (!WaitPendingBlitFenceLocked(kBlitFenceTimeoutNs)) {
                std::cerr << "[ThermionVk:Context] WARNING: Previous blit still in flight after 50ms; "
                             "skipping frame" << std::endl;
                return;
            }

            auto& texture = it->second;
            VkImage renderImage = texture->GetRenderImage();
            VkImage exportImage = texture->GetImage();  // base _image is the export image
            uint32_t width = texture->GetWidth();
            uint32_t height = texture->GetHeight();

            // Reset and record command buffer
            VkResult result = vkResetCommandBuffer(_blitCmdBuffer, 0);
            if (result != VK_SUCCESS) {
                std::cerr << "[ThermionVk:Context] ERROR: vkResetCommandBuffer failed: "
                          << VkResultToString(result) << std::endl;
                return;
            }

            VkCommandBufferBeginInfo beginInfo = {
                .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
                .pNext = nullptr,
                .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
                .pInheritanceInfo = nullptr
            };
            result = vkBeginCommandBuffer(_blitCmdBuffer, &beginInfo);
            if (result != VK_SUCCESS) {
                std::cerr << "[ThermionVk:Context] ERROR: vkBeginCommandBuffer failed: "
                          << VkResultToString(result) << std::endl;
                return;
            }

            // Barrier: render image → TRANSFER_SRC_OPTIMAL.
            // Thermion imports surface color targets with SAMPLEABLE | COLOR_ATTACHMENT,
            // so Filament's VulkanTexture default layout between render passes is
            // VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL.
            VkImageMemoryBarrier renderBarrier = {
                .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                .pNext = nullptr,
                .srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT |
                                 VK_ACCESS_SHADER_READ_BIT,
                .dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT,
                .oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
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
                VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT,
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
            // Render image → SHADER_READ_ONLY_OPTIMAL (matches Filament's
            // default layout expected at the start of its next render pass)
            VkImageMemoryBarrier renderPostBarrier = {
                .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                .pNext = nullptr,
                .srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT,
                .dstAccessMask = VK_ACCESS_SHADER_READ_BIT |
                                 VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                 VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                .oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                .newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
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
                VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                0, 0, nullptr, 0, nullptr,
                2, postBarriers);

            result = vkEndCommandBuffer(_blitCmdBuffer);
            if (result != VK_SUCCESS) {
                std::cerr << "[ThermionVk:Context] ERROR: vkEndCommandBuffer failed: "
                          << VkResultToString(result) << std::endl;
                return;
            }

            SubmitAndWaitBlitCommandBufferLocked(/*waitForFilamentQueue=*/true, kBlitFenceTimeoutNs);
        }

        void* GetSharedContext() {
            return &_sharedContext;
        }

        void* GetPlatform() {
            return _platform.get();
        }

        void* CreateExternalImageForSurface(int64_t surfaceId) {
            std::lock_guard<std::mutex> contextLock(_contextMutex);
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
            ext->usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT |
                         VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                         VK_IMAGE_USAGE_TRANSFER_DST_BIT |
                         VK_IMAGE_USAGE_SAMPLED_BIT;
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
        bool EnsureBlitResourcesLocked() {
            if (_blitResources.commandPool != VK_NULL_HANDLE) {
                return true;
            }

            _blitResources = createCommandResources(device, physicalDevice);

            VkFenceCreateInfo fenceInfo = {
                .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                .pNext = nullptr,
                .flags = 0
            };
            VkResult result = vkCreateFence(device, &fenceInfo, nullptr, &_blitFence);
            if (result != VK_SUCCESS) {
                LOG_ERROR("Failed to create blit fence: %s", VkResultToString(result));
                vkDestroyCommandPool(device, _blitResources.commandPool, nullptr);
                _blitResources = {};
                return false;
            }

            VkCommandBufferAllocateInfo cmdAllocInfo = {
                .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .pNext = nullptr,
                .commandPool = _blitResources.commandPool,
                .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                .commandBufferCount = 1
            };
            result = vkAllocateCommandBuffers(device, &cmdAllocInfo, &_blitCmdBuffer);
            if (result != VK_SUCCESS) {
                LOG_ERROR("Failed to allocate blit command buffer: %s", VkResultToString(result));
                vkDestroyFence(device, _blitFence, nullptr);
                _blitFence = VK_NULL_HANDLE;
                vkDestroyCommandPool(device, _blitResources.commandPool, nullptr);
                _blitResources = {};
                return false;
            }

            _blitFencePending = false;
            std::cerr << "[ThermionVk:Context] Blit resources initialized" << std::endl;
            return true;
        }

        bool WaitPendingBlitFenceLocked(uint64_t timeoutNs) {
            if (!_blitFencePending) {
                return true;
            }
            VkResult result = vkWaitForFences(device, 1, &_blitFence, VK_TRUE, timeoutNs);
            if (result == VK_TIMEOUT) {
                return false;
            }
            if (result != VK_SUCCESS) {
                std::cerr << "[ThermionVk:Context] ERROR: vkWaitForFences failed: "
                          << VkResultToString(result) << std::endl;
                return false;
            }
            vkResetFences(device, 1, &_blitFence);
            _blitFencePending = false;
            return true;
        }

        bool SubmitAndWaitBlitCommandBufferLocked(bool waitForFilamentQueue, uint64_t timeoutNs) {
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

            // Hold sQueueMutex across queue 0 drain + blit submit + bounded
            // fence wait so host VkQueue access is externally synchronized and
            // Filament cannot start a new render pass into renderImage while
            // the ~0.1 ms copy is executing on queue 1.
            std::lock_guard<std::mutex> queueLock(sQueueMutex);
            InstallQueueSerializationShimLocked();

            if (waitForFilamentQueue && _filamentQueue != VK_NULL_HANDLE) {
                VkResult idleResult = WaitQueueIdleLocked(_filamentQueue);
                if (idleResult != VK_SUCCESS) {
                    std::cerr << "[ThermionVk:Context] ERROR: Filament queue wait idle failed: "
                              << VkResultToString(idleResult) << std::endl;
                    return false;
                }
            }

            VkResult result = SubmitQueueLocked(_blitResources.queue, 1, &submitInfo, _blitFence);
            if (result != VK_SUCCESS) {
                std::cerr << "[ThermionVk:Context] ERROR: Blit vkQueueSubmit failed: "
                          << VkResultToString(result) << std::endl;
                return false;
            }
            _blitFencePending = true;

            if (!WaitPendingBlitFenceLocked(timeoutNs)) {
                std::cerr << "[ThermionVk:Context] WARNING: Blit fence timed out; "
                             "next blit will synchronize before resetting command buffer"
                          << std::endl;
                return false;
            }
            return true;
        }

        // Clears both images to transparent black and transitions renderImage
        // into SHADER_READ_ONLY_OPTIMAL (Filament's default layout for
        // SAMPLEABLE | COLOR_ATTACHMENT targets) and exportImage into GENERAL
        // so a notification arriving before Filament's first render pass never
        // hits VK_IMAGE_LAYOUT_UNDEFINED or exposes uninitialized memory.
        bool InitializeBlitSurfaceLocked(LinuxVulkanTexture& texture) {
            if (!EnsureBlitResourcesLocked()) {
                return false;
            }
            if (!WaitPendingBlitFenceLocked(kInitBlitFenceTimeoutNs)) {
                std::cerr << "[ThermionVk:Context] ERROR: Timed out waiting on prior blit before "
                             "initializing new blit surface" << std::endl;
                return false;
            }

            VkResult result = vkResetCommandBuffer(_blitCmdBuffer, 0);
            if (result != VK_SUCCESS) {
                return false;
            }

            VkCommandBufferBeginInfo beginInfo = {
                .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
                .pNext = nullptr,
                .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
                .pInheritanceInfo = nullptr
            };
            result = vkBeginCommandBuffer(_blitCmdBuffer, &beginInfo);
            if (result != VK_SUCCESS) {
                return false;
            }

            VkImage renderImage = texture.GetRenderImage();
            VkImage exportImage = texture.GetImage();
            VkImageSubresourceRange colorRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};

            VkImageMemoryBarrier toTransferDst[] = {
                {
                    .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                    .pNext = nullptr,
                    .srcAccessMask = 0,
                    .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                    .oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                    .newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .image = renderImage,
                    .subresourceRange = colorRange
                },
                {
                    .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                    .pNext = nullptr,
                    .srcAccessMask = 0,
                    .dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                    .oldLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                    .newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .image = exportImage,
                    .subresourceRange = colorRange
                }
            };
            vkCmdPipelineBarrier(_blitCmdBuffer,
                VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                0, 0, nullptr, 0, nullptr,
                2, toTransferDst);

            VkClearColorValue clearColor = {};
            vkCmdClearColorImage(_blitCmdBuffer, renderImage,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &clearColor, 1, &colorRange);
            vkCmdClearColorImage(_blitCmdBuffer, exportImage,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &clearColor, 1, &colorRange);

            VkImageMemoryBarrier postInitBarriers[] = {
                {
                    .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                    .pNext = nullptr,
                    .srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                    .dstAccessMask = VK_ACCESS_SHADER_READ_BIT |
                                     VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                                     VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT |
                                     VK_ACCESS_TRANSFER_READ_BIT,
                    .oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    .newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .image = renderImage,
                    .subresourceRange = colorRange
                },
                {
                    .sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                    .pNext = nullptr,
                    .srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT,
                    .dstAccessMask = VK_ACCESS_MEMORY_READ_BIT,
                    .oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    .newLayout = VK_IMAGE_LAYOUT_GENERAL,
                    .srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED,
                    .image = exportImage,
                    .subresourceRange = colorRange
                }
            };
            vkCmdPipelineBarrier(_blitCmdBuffer,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                0, 0, nullptr, 0, nullptr,
                2, postInitBarriers);

            result = vkEndCommandBuffer(_blitCmdBuffer);
            if (result != VK_SUCCESS) {
                return false;
            }

            return SubmitAndWaitBlitCommandBufferLocked(
                /*waitForFilamentQueue=*/false, kInitBlitFenceTimeoutNs);
        }

        std::mutex _contextMutex;

        VkInstance instance = VK_NULL_HANDLE;
        VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
        VkDevice device = VK_NULL_HANDLE;
        VkQueue _filamentQueue = VK_NULL_HANDLE;

        std::unordered_map<int64_t, std::unique_ptr<LinuxVulkanTexture>> _exportableTextures;

        filament::backend::VulkanPlatform::VulkanSharedContext _sharedContext{};

        std::unique_ptr<thermion::vulkan::VulkanPlatform> _platform =
            std::make_unique<thermion::vulkan::VulkanPlatform>();

        int64_t _nextSurfaceId = 1;

        // Blit resources (shared across all surfaces, lazy-initialized)
        CommandResources _blitResources{};
        VkFence _blitFence = VK_NULL_HANDLE;
        VkCommandBuffer _blitCmdBuffer = VK_NULL_HANDLE;
        bool _blitFencePending = false;
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
