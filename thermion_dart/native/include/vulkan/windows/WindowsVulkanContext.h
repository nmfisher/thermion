#pragma once

#include "vulkan/VulkanUtils.h"

#include <chrono>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "backend/Platform.h"
#include "backend/platforms/VulkanPlatform.h"

#include "windows/import.h"

namespace thermion::vulkan::windows {

  class DLL_EXPORT WindowsVulkanContext {
    public:
        WindowsVulkanContext();
        ~WindowsVulkanContext();

        HANDLE CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);

        VkImage GetVulkanImageForSurface(HANDLE surfaceHandle);

        void* CreateExternalImageForSurface(HANDLE surfaceHandle);

        void DestroyRenderingSurface(HANDLE handle);

        void* GetSharedContext();

        void readPixelsFromImage(
          uint32_t width,
          uint32_t height,
          std::vector<uint8_t>& outPixels
        );

        filament::backend::Platform* GetPlatform();

    private:
        class Impl;
        std::unique_ptr<Impl> pImpl;

  };

}
