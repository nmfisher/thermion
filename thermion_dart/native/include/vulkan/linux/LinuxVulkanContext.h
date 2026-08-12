#pragma once

#include <cstdint>
#include <memory>
#include <vector>

#include "SurfaceExportInfo.h"
#include "bluevk/BlueVK.h"
#include "backend/Platform.h"
#include "backend/platforms/VulkanPlatform.h"

namespace thermion::vulkan::linux_platform {

class LinuxVulkanContext {
    public:
        LinuxVulkanContext();
        ~LinuxVulkanContext();

        int64_t CreateRenderingSurface(uint32_t width, uint32_t height);
        VkImage GetVulkanImageForSurface(int64_t surfaceId);
        SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId);
        int NeedsBlit(int64_t surfaceId);
        void BlitToExport(int64_t surfaceId);
        void DestroyRenderingSurface(int64_t surfaceId);
        void* GetSharedContext();
        void* GetPlatform();
        void* CreateExternalImageForSurface(int64_t surfaceId);

    private:
        class Impl;
        std::unique_ptr<Impl> pImpl;
};

} // namespace thermion::vulkan::linux_platform
