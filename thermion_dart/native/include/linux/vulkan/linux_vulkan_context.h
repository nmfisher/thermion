#pragma once

#include <cstdint>
#include <memory>
#include <vector>

#include "bluevk/BlueVK.h"
#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

namespace thermion::linux_platform::vulkan {

class ThermionLinuxVulkanContext {
    public:
        ThermionLinuxVulkanContext();
        ~ThermionLinuxVulkanContext();

        int64_t CreateRenderingSurface(uint32_t width, uint32_t height);
        VkImage GetVulkanImageForSurface(int64_t surfaceId);
        int GetDmaBufFd(int64_t surfaceId);
        uint32_t GetDrmFormat(int64_t surfaceId);
        uint32_t GetStride(int64_t surfaceId);
        uint32_t GetOffset(int64_t surfaceId);
        uint32_t GetWidth(int64_t surfaceId);
        uint32_t GetHeight(int64_t surfaceId);
        void DestroyRenderingSurface(int64_t surfaceId);
        void Blit(int64_t surfaceId);
        filament::backend::VulkanPlatform* GetPlatform();
        void* GetSharedContext();

    private:
        class Impl;
        std::unique_ptr<Impl> pImpl;
};

}
