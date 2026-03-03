
#include "vulkan_context.h"
#include "ThermionWin32.h"

#include <functional>
#include <vector>
#include <set>
#include <chrono>
#include <string>
#include <fstream>
#include <iostream>
#include <memory>
#include <thread>

#include "filament/backend/platforms/VulkanPlatform.h"
#include "filament/Engine.h"
#include "filament/Renderer.h"
#include "filament/View.h"
#include "filament/Viewport.h"
#include "filament/Scene.h"
#include "filament/SwapChain.h"
#include "filament/Texture.h"

#include "Log.hpp"

namespace thermion::windows::vulkan {
   
using namespace bluevk;
  
class ThermionVulkanContext::Impl {
    public:

        ~Impl() {
            std::cerr << "ThermionVulkanContext destructor " << _vulkanTextures.size() << " Vulkan textures / "
                      << _d3dTextures.size() << " D3D textures / " << _renderTargetTextures.size() << " render targets remain" << std::endl;
            if (blitFence != VK_NULL_HANDLE) {
                bluevk::vkDestroyFence(device, blitFence, nullptr);
            }
            _d3dContext = std::nullptr_t();
        }
        
        Impl() {
            std::cerr << "Initializing ThermionVulkanContext" << std::endl;
            if(!bluevk::initialize()) { 
                std::cerr << "Failed to initialize BlueVK, this means the Vulkan drivers were not found." << std::endl;
                return;
            }

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
                .usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT, 
                .flags = 0
            };

            VkExternalImageFormatProperties externFormatProps = {
                .sType = VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES
            };

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
                return;
            }

            _platform = std::make_unique<TVulkanPlatform>();

            VkPhysicalDeviceIDProperties idProps{};
            idProps.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ID_PROPERTIES;
            idProps.pNext = nullptr;

            VkPhysicalDeviceProperties2 props{};
            props.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
            props.pNext = &idProps;

            // requires Vulkan instance version 1.1+ OR VK_KHR_get_physical_device_properties2 
            bluevk::vkGetPhysicalDeviceProperties2(physicalDevice, &props);

            if (idProps.deviceLUIDValid == VK_TRUE) {
                Log("Using Vulkan Device LUID %d", idProps.deviceLUID);
                _d3dContext = std::make_unique<thermion::windows::d3d::D3DContext>(idProps.deviceLUID);
            } 

            if(!_d3dContext || !_d3dContext->IsValid()) {
                ERROR("Could not resolve Vulkan Device LUID");
                return;
            }

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
            fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;  // Start signaled so first reset works
            VkResult fenceResult = bluevk::vkCreateFence(device, &fenceInfo, nullptr, &blitFence);
            if (fenceResult != VK_SUCCESS) {
                std::cout << "[ERROR] Failed to create blit fence" << std::endl;
            }

        }

        HANDLE CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {

            Log("Creating Vulkan texture %dx%d", width, height);

            // 1. Create pure Vulkan texture for render target (returned to Flutter as hardware texture ID)
            auto renderTargetTexture = VulkanTexture::createPure(device, physicalDevice, width, height);
            if(!renderTargetTexture) {
                ERROR("Failed to create pure Vulkan render target texture");
                return NULL;
            }

            // 2. Create D3D texture and D3D-interop Vulkan texture (for Flutter display)
            auto d3dTexture = _d3dContext->CreateTexture(width, height);
            auto d3dTextureHandle = d3dTexture->GetTextureHandle();
            auto vkTexture = VulkanTexture::create(device, physicalDevice, width, height, d3dTextureHandle);

            if(!vkTexture) {
                return NULL;
            }

            _renderTargetTextures.push_back(std::move(renderTargetTexture));
            _d3dTextures.push_back(std::move(d3dTexture));
            _vulkanTextures.push_back(std::move(vkTexture));
            _pendingFirstBlit.insert(d3dTextureHandle);
            return d3dTextureHandle;
        }
    
        void DestroyRenderingSurface(HANDLE handle) {
            for (size_t i = 0; i < _d3dTextures.size(); i++) {
                if (_d3dTextures[i]->GetTextureHandle() == handle) {
                    // Release ownership of the render target VkImage.
                    // Filament imports this image via setExternalImage and
                    // frees it when its texture is destroyed.  If we also
                    // free it, we get a double-free that corrupts the GPU.
                    _renderTargetTextures[i]->releaseOwnership();
                    _graveyardRT.push_back(std::move(_renderTargetTextures[i]));
                    _renderTargetTextures.erase(_renderTargetTextures.begin() + i);

                    // The D3D-interop textures are not imported by Filament,
                    // so we still own them.  Defer their cleanup to avoid
                    // freeing resources while the driver still references them.
                    _graveyardVk.push_back(std::move(_vulkanTextures[i]));
                    _vulkanTextures.erase(_vulkanTextures.begin() + i);
                    _graveyardD3D.push_back(std::move(_d3dTextures[i]));
                    _d3dTextures.erase(_d3dTextures.begin() + i);
                    _graveyardFrames = 0;
                    return;
                }
            }
            std::cerr << "Warning: D3D texture not found for handle " << handle << std::endl;
        }

        VkImage GetVulkanImageForSurface(HANDLE handle) {
            // Find the index of the D3D texture with this handle and return the corresponding render target VkImage
            for (size_t i = 0; i < _d3dTextures.size(); i++) {
                if (_d3dTextures[i]->GetTextureHandle() == handle) {
                    // Return the corresponding render target texture's VkImage (not the D3D-interop one)
                    return _renderTargetTextures[i]->GetImage();
                }
            }
            return VK_NULL_HANDLE;
        }

        void* CreateExternalImageForSurface(HANDLE handle) {
            for (size_t i = 0; i < _d3dTextures.size(); i++) {
                if (_d3dTextures[i]->GetTextureHandle() == handle) {
                    auto& rt = _renderTargetTextures[i];
                    auto* ext = new ExternalVulkanImage();
                    ext->image = rt->GetImage();
                    ext->memory = rt->GetMemory();
                    ext->format = VK_FORMAT_R8G8B8A8_UNORM;
                    ext->width = rt->GetWidth();
                    ext->height = rt->GetHeight();
                    ext->layers = 1;
                    ext->usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;

                    // Get memory requirements for allocationSize and memoryTypeBits
                    VkMemoryRequirements memReqs;
                    bluevk::vkGetImageMemoryRequirements(device, ext->image, &memReqs);
                    ext->allocationSize = memReqs.size;
                    ext->memoryTypeBits = memReqs.memoryTypeBits;

                    ext->filamentFormat = filament::backend::TextureFormat::RGBA8;
                    ext->filamentUsage = filament::backend::TextureUsage::COLOR_ATTACHMENT
                        | filament::backend::TextureUsage::BLIT_SRC
                        | filament::backend::TextureUsage::SAMPLEABLE;
                    return ext;
                }
            }
            ERROR("D3D texture not found for handle in CreateExternalImageForSurface");
            return nullptr;
        }

        void ClearPendingFirstBlit(HANDLE d3dTextureHandle) {
            _pendingFirstBlit.erase(d3dTextureHandle);
        }

        void Blit(HANDLE d3dTextureHandle) {
            // Skip the first Blit after texture creation.  The render
            // target has uninitialized contents until Filament renders
            // into it; blitting garbage produces visible jank.
            if (_pendingFirstBlit.erase(d3dTextureHandle)) {
                return;
            }

            // Find the texture index for this handle
            size_t textureIndex = SIZE_MAX;
            for (size_t i = 0; i < _d3dTextures.size(); i++) {
                if (_d3dTextures[i]->GetTextureHandle() == d3dTextureHandle) {
                    textureIndex = i;
                    break;
                }
            }

            if (textureIndex == SIZE_MAX) {
                ERROR("Texture handle not found");
                return;
            }

            if (textureIndex >= _renderTargetTextures.size() || textureIndex >= _vulkanTextures.size()) {
                ERROR("Texture index out of bounds");
                return;
            }

            auto srcImage = _renderTargetTextures[textureIndex]->GetImage();
            auto dstImage = _vulkanTextures[textureIndex]->GetImage();
            auto width = _d3dTextures[textureIndex]->GetWidth();
            auto height = _d3dTextures[textureIndex]->GetHeight();

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

            // Blit only the specific texture pair
            {

                // Source barrier: render target texture (COLOR_ATTACHMENT_OPTIMAL -> TRANSFER_SRC_OPTIMAL)
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

                // Destination barrier: D3D-interop texture (UNDEFINED -> TRANSFER_DST_OPTIMAL)
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

                // Define blit region
                VkImageBlit blit{};
                blit.srcSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
                blit.srcOffsets[0] = {0, 0, 0};
                blit.srcOffsets[1] = {static_cast<int32_t>(width), static_cast<int32_t>(height), 1};
                blit.dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
                blit.dstOffsets[0] = {0, 0, 0};
                blit.dstOffsets[1] = {static_cast<int32_t>(width), static_cast<int32_t>(height), 1};

                // Perform blit (handles RGBA->BGRA format conversion automatically)
                bluevk::vkCmdBlitImage(
                    blitCommandBuffer,
                    srcImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                    dstImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                    1, &blit,
                    VK_FILTER_NEAREST
                );

                // Post-blit barriers
                // Source: transition back to COLOR_ATTACHMENT_OPTIMAL for next render
                srcBarrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
                srcBarrier.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
                srcBarrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
                srcBarrier.newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

                // Destination: transition to SHADER_READ_ONLY_OPTIMAL for D3D sampling
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
            }

            // End command buffer
            result = bluevk::vkEndCommandBuffer(blitCommandBuffer);
            if (result != VK_SUCCESS) {
                std::cout << "Failed to end command buffer: " << result << std::endl;
                return;
            }

            // Setup Standard Submit Info
            VkSubmitInfo submitInfo{};
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
            // submitInfo.pNext = &timelineInfo;
            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &blitCommandBuffer;
            // submitInfo.signalSemaphoreCount = 1;
            // submitInfo.pSignalSemaphores = &sharedSemaphore;

            // Wait for any previous blit to complete and reset fence
            result = bluevk::vkWaitForFences(device, 1, &blitFence, VK_TRUE, UINT64_MAX);
            if (result != VK_SUCCESS) {
                std::cerr << "vkWaitForFences failed: " << result << std::endl;
                return;
            }
            bluevk::vkResetFences(device, 1, &blitFence);

            result = bluevk::vkQueueSubmit(queue, 1, &submitInfo, blitFence);
            if (result != VK_SUCCESS) {
                std::cerr << "vkQueueSubmit failed: " << result << std::endl;
                return;
            }

            // Wait for blit to complete before returning
            result = bluevk::vkWaitForFences(device, 1, &blitFence, VK_TRUE, UINT64_MAX);
            if (result != VK_SUCCESS) {
                std::cerr << "vkWaitForFences (post-blit) failed: " << result << std::endl;
            }

            // Drain the graveyard after enough Blit cycles.
            // The render target VkImages have released ownership (Filament
            // owns them), so clearing _graveyardRT just frees the wrapper.
            // The D3D and interop textures are freed here after the driver
            // has retired all references.
            if (!_graveyardD3D.empty()) {
                _graveyardFrames++;
                if (_graveyardFrames >= GRAVEYARD_DRAIN_FRAMES) {
                    bluevk::vkDeviceWaitIdle(device);
                    _graveyardRT.clear();
                    _graveyardVk.clear();
                    _graveyardD3D.clear();
                }
            }
        }

        void readPixelsFromImage(
            uint32_t width,
            uint32_t height,
            std::vector<uint8_t>& outPixels) {

            auto&& vkTexture = _vulkanTextures.back();
            auto image = vkTexture->GetImage();
        
            VkDeviceSize bufferSize = width * height * 4; // RGBA8 format
            
            // Create staging buffer
            VkBuffer stagingBuffer;
            VkDeviceMemory stagingBufferMemory;
            
            VkBufferCreateInfo bufferInfo{};
            bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
            bufferInfo.size = bufferSize;
            bufferInfo.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
            bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
            
            VkResult result = bluevk::vkCreateBuffer(device, &bufferInfo, nullptr, &stagingBuffer);
            if (result != VK_SUCCESS) {
                throw std::runtime_error("Failed to create staging buffer");
            }
            
            // Get memory requirements and allocate
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
                throw std::runtime_error("Failed to allocate staging buffer memory");
            }
            
            result = bluevk::vkBindBufferMemory(device, stagingBuffer, stagingBufferMemory, 0);
            if (result != VK_SUCCESS) {
                vkFreeMemory(device, stagingBufferMemory, nullptr);
                vkDestroyBuffer(device, stagingBuffer, nullptr);
                throw std::runtime_error("Failed to bind buffer memory");
            }
            
            // Create command buffer
            VkCommandBufferAllocateInfo cmdBufAllocInfo{};
            cmdBufAllocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
            cmdBufAllocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            cmdBufAllocInfo.commandPool = commandPool;
            cmdBufAllocInfo.commandBufferCount = 1;
            
            VkCommandBuffer commandBuffer;
            result = bluevk::vkAllocateCommandBuffers(device, &cmdBufAllocInfo, &commandBuffer);
            if (result != VK_SUCCESS) {
                throw std::runtime_error("Failed to allocate command buffer");
            }
            
            // Begin command buffer
            VkCommandBufferBeginInfo beginInfo{};
            beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
            beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
            
            result = bluevk::vkBeginCommandBuffer(commandBuffer, &beginInfo);
            if (result != VK_SUCCESS) {
                throw std::runtime_error("Failed to begin command buffer");
            }
            
            // Transition image layout for transfer with proper sync
            VkImageMemoryBarrier barrier{};
            barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            barrier.srcAccessMask = VK_ACCESS_MEMORY_READ_BIT;
            barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
            barrier.oldLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL; // Assuming this is the current layout
            barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
            barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            barrier.image = image;
            barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            barrier.subresourceRange.baseMipLevel = 0;
            barrier.subresourceRange.levelCount = 1;
            barrier.subresourceRange.baseArrayLayer = 0;
            barrier.subresourceRange.layerCount = 1;
            
            bluevk::vkCmdPipelineBarrier(
                commandBuffer,
                VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                VK_PIPELINE_STAGE_TRANSFER_BIT,
                0,
                0, nullptr,
                0, nullptr,
                1, &barrier
            );
            
            // Copy image to buffer
            VkBufferImageCopy region{};
            region.bufferOffset = 0;
            region.bufferRowLength = 0;
            region.bufferImageHeight = 0;
            region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            region.imageSubresource.mipLevel = 0;
            region.imageSubresource.baseArrayLayer = 0;
            region.imageSubresource.layerCount = 1;
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
            
            // Transition image layout back
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
                throw std::runtime_error("Failed to end command buffer");
            }
            
            // Submit command buffer with fence for synchronization
            VkFenceCreateInfo fenceInfo{};
            fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
            
            VkFence fence;
            result = bluevk::vkCreateFence(device, &fenceInfo, nullptr, &fence);
            if (result != VK_SUCCESS) {
                throw std::runtime_error("Failed to create fence");
            }
            
            VkSubmitInfo submitInfo{};
            submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
            submitInfo.commandBufferCount = 1;
            submitInfo.pCommandBuffers = &commandBuffer;
            
            result = bluevk::vkQueueSubmit(queue, 1, &submitInfo, fence);
            if (result != VK_SUCCESS) {
                bluevk::vkDestroyFence(device, fence, nullptr);
                throw std::runtime_error("Failed to submit queue");
            }
            
            // Wait for the command buffer to complete with timeout
            result = bluevk::vkWaitForFences(device, 1, &fence, VK_TRUE, 5000000000); // 5 second timeout
            if (result != VK_SUCCESS) {
                bluevk::vkDestroyFence(device, fence, nullptr);
                throw std::runtime_error("Failed to wait for fence");
            }
            
            // Map memory and copy data
            void* data;
            result = bluevk::vkMapMemory(device, stagingBufferMemory, 0, bufferSize, 0, &data);
            if (result != VK_SUCCESS) {
                throw std::runtime_error("Failed to map memory");
            }
            
            outPixels.resize(bufferSize);
            memcpy(outPixels.data(), data, bufferSize);
            bluevk::vkUnmapMemory(device, stagingBufferMemory);
            
            // Cleanup
            bluevk::vkDestroyFence(device, fence, nullptr);
            vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer);
            vkDestroyBuffer(device, stagingBuffer, nullptr);
            vkFreeMemory(device, stagingBufferMemory, nullptr);
            
            std::cout << "Successfully completed readPixelsFromImage" << std::endl;
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
        
        std::unique_ptr<thermion::windows::d3d::D3DContext> _d3dContext;
    
        std::vector<std::unique_ptr<thermion::windows::d3d::D3DTexture>> _d3dTextures;
        std::vector<std::unique_ptr<thermion::windows::vulkan::VulkanTexture>> _vulkanTextures;
        std::vector<std::unique_ptr<thermion::windows::vulkan::VulkanTexture>> _renderTargetTextures;  // Pure Vulkan textures for render targets
        std::set<HANDLE> _pendingFirstBlit;  // Skip first Blit until Filament renders

        // Graveyard: holds old textures after DestroyRenderingSurface.
        // The render target VkImage ownership is released to Filament
        // (which frees it via setExternalImage).  The D3D-interop
        // textures are deferred here and freed after GRAVEYARD_DRAIN_FRAMES
        // Blit cycles with a vkDeviceWaitIdle fence.
        static constexpr int GRAVEYARD_DRAIN_FRAMES = 5;
        std::vector<std::unique_ptr<thermion::windows::vulkan::VulkanTexture>> _graveyardRT;
        std::vector<std::unique_ptr<thermion::windows::vulkan::VulkanTexture>> _graveyardVk;
        std::vector<std::unique_ptr<thermion::windows::d3d::D3DTexture>> _graveyardD3D;
        int _graveyardFrames = 0;
        
        std::unique_ptr<TVulkanPlatform> _platform;
        filament::backend::VulkanPlatform::VulkanSharedContext _sharedContext{};



};

HANDLE ThermionVulkanContext::CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top) {
    return pImpl->CreateRenderingSurface(width, height, left, top);
}

VkImage ThermionVulkanContext::GetVulkanImageForSurface(HANDLE handle) {
    return pImpl->GetVulkanImageForSurface(handle);
}

void* ThermionVulkanContext::CreateExternalImageForSurface(HANDLE handle) {
    return pImpl->CreateExternalImageForSurface(handle);
}

void ThermionVulkanContext::DestroyRenderingSurface(HANDLE handle) {
    pImpl->DestroyRenderingSurface(handle);
}

filament::backend::VulkanPlatform *ThermionVulkanContext::GetPlatform() { 
return pImpl->GetPlatform();
}

void* ThermionVulkanContext::GetSharedContext() {
    return pImpl->GetSharedContext();
}

void ThermionVulkanContext::Blit(HANDLE d3dTextureHandle) {
    pImpl->Blit(d3dTextureHandle);
}

void ThermionVulkanContext::ClearPendingFirstBlit(HANDLE d3dTextureHandle) {
    pImpl->ClearPendingFirstBlit(d3dTextureHandle);
}

void ThermionVulkanContext::readPixelsFromImage(
    uint32_t width,
    uint32_t height,
    std::vector<uint8_t>& outPixels
) {
    pImpl->readPixelsFromImage(width, height, outPixels);
}

ThermionVulkanContext::ThermionVulkanContext() : pImpl(std::make_unique<ThermionVulkanContext::Impl>()) {}

ThermionVulkanContext::~ThermionVulkanContext() = default;  

}
