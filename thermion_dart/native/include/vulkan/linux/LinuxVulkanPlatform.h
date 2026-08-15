#pragma once

#include <iostream>
#include <backend/platforms/VulkanPlatformLinux.h>

#include "vulkan/ExternalVulkanImage.h"

namespace thermion::vulkan {

// Custom VulkanPlatform that handles ExternalVulkanImage for external texture import.
// Inherits from VulkanPlatformLinux to get proper Linux implementations.
class VulkanPlatform : public filament::backend::VulkanPlatformLinux {
public:
    VulkanPlatform() = default;
    ~VulkanPlatform() override = default;

    ExternalImageMetadata extractExternalImageMetadata(
            Platform::ExternalImageHandleRef image) const override {
        std::cerr << "[ThermionVk:Platform] extractExternalImageMetadata called" << std::endl;

        const auto* extImg = static_cast<const thermion::vulkan::ExternalVulkanImage*>(image.get());
        if (!extImg) {
            std::cerr << "[ThermionVk:Platform] ERROR: null ExternalVulkanImage" << std::endl;
            return {};
        }

        std::cerr << "[ThermionVk:Platform] Metadata: "
                  << extImg->width << "x" << extImg->height
                  << " format=" << extImg->format
                  << " usage=0x" << std::hex << extImg->usage << std::dec
                  << " allocSize=" << extImg->allocationSize
                  << " memTypeBits=0x" << std::hex << extImg->memoryTypeBits << std::dec
                  << std::endl;

        ExternalImageMetadata metadata;
        metadata.filamentFormat = extImg->filamentFormat;
        metadata.filamentUsage = extImg->filamentUsage;
        metadata.width = extImg->width;
        metadata.height = extImg->height;
        metadata.layers = extImg->layers;
        metadata.samples = VK_SAMPLE_COUNT_1_BIT;
        metadata.format = extImg->format;
        metadata.externalFormat = 0;
        metadata.usage = extImg->usage;
        metadata.allocationSize = extImg->allocationSize;
        metadata.memoryTypeBits = extImg->memoryTypeBits;
        metadata.ycbcrConversionComponents = {VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY,
                                               VK_COMPONENT_SWIZZLE_IDENTITY, VK_COMPONENT_SWIZZLE_IDENTITY};
        metadata.ycbcrModel = VK_SAMPLER_YCBCR_MODEL_CONVERSION_RGB_IDENTITY;
        metadata.ycbcrRange = VK_SAMPLER_YCBCR_RANGE_ITU_FULL;
        metadata.xChromaOffset = VK_CHROMA_LOCATION_COSITED_EVEN;
        metadata.yChromaOffset = VK_CHROMA_LOCATION_COSITED_EVEN;

        return metadata;
    }

    ImageData createVkImageFromExternal(
            Platform::ExternalImageHandleRef image,
            uint32_t logicalWidth, uint32_t logicalHeight) const override {
        std::cerr << "[ThermionVk:Platform] createVkImageFromExternal called" << std::endl;

        const auto* extImg = static_cast<const thermion::vulkan::ExternalVulkanImage*>(image.get());
        if (!extImg) {
            std::cerr << "[ThermionVk:Platform] ERROR: null ExternalVulkanImage" << std::endl;
            return {};
        }

        std::cerr << "[ThermionVk:Platform] Returning VkImage=0x"
                  << std::hex << reinterpret_cast<uintptr_t>(extImg->image)
                  << " VkDeviceMemory=VK_NULL_HANDLE (LinuxVulkanTexture owns memory)"
                  << std::dec << std::endl;

        ImageData data;
        data.internal.image = extImg->image;
        // Pass VK_NULL_HANDLE for memory: LinuxVulkanTexture is the sole owner.
        // Filament's ~VulkanTextureState checks memory != VK_NULL_HANDLE before
        // destroying, so this prevents double-free of both image and memory.
        data.internal.memory = VK_NULL_HANDLE;
        return data;
    }

    Platform::Sync* createSync(
            std::shared_ptr<filament::backend::VulkanCmdFence> fenceStatus) noexcept override {
        // v1.74.0: VulkanSync has no default ctor / no `fence` member; construct directly.
        return new VulkanSync(fenceStatus);
    }
};

} // namespace thermion::vulkan
