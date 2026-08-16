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

        // Blits the contents of the paired Vulkan texture to the specified surface handle
        void Blit(HANDLE surfaceHandle);

        // Clear the pending-first-blit flag for a handle.
        // Used during resize swap: by the time the swap fires, Filament
        // has already rendered into the new render target, so the first
        // Blit should not be skipped.
        void ClearPendingFirstBlit(HANDLE d3dTextureHandle);

        void* GetSharedContext();

        void readPixelsFromImage(
          uint32_t width,
          uint32_t height,
          std::vector<uint8_t>& outPixels
        );

        // The first engine's platform (creating it if the context has none).
        filament::backend::Platform* GetPlatform();

        // A platform for one engine. A Platform instance belongs to a single
        // filament Engine, and each engine also needs its own VkQueue index.
        // The VkInstance/VkPhysicalDevice/VkDevice behind them stay shared.
        // Owned by the context, never freed.
        filament::backend::Platform* CreatePlatform();

        // The VulkanSharedContext paired with a platform from CreatePlatform
        // — same device, engine-specific queue index. Pass this to
        // Engine::create alongside the platform. Null if unrecognised.
        void* GetSharedContextForPlatform(filament::backend::Platform* platform);

        // Marks a platform (and its queue) reusable because its engine is gone.
        void ReleasePlatform(filament::backend::Platform* platform);

    private:
        class Impl;
        std::unique_ptr<Impl> pImpl;

  };

}
