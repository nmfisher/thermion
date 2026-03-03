#pragma once

#include "d3d_context.h"
#include "vulkan_texture.h"
#include "vulkan_platform.h"
#include "vulkan_utils.h"

#include <chrono>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

#include <Windows.h>

#include "import.h"

namespace thermion::windows::vulkan {

  class DLL_EXPORT ThermionVulkanContext {
    public:
        ThermionVulkanContext();
        ~ThermionVulkanContext();
        
        HANDLE CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);

        VkImage GetVulkanImageForSurface(HANDLE d3dTextureHandle);

        void* CreateExternalImageForSurface(HANDLE d3dTextureHandle);

        void DestroyRenderingSurface(HANDLE handle);
                      
        filament::backend::VulkanPlatform *GetPlatform();
      
        // Blits the contents of the paired Vulkan texture to the specified D3D texture handle
        void Blit(HANDLE d3dTextureHandle);

        // Clear the pending-first-blit flag for a handle.
        // Used during resize swap: by the time the swap fires, Filament
        // has already rendered into the new render target, so the first
        // Blit should not be skipped.
        void ClearPendingFirstBlit(HANDLE d3dTextureHandle);

        void* GetSharedContext();
      
        void readPixelsFromImage(
          uint32_t width,
          uint32_t height,
          std::vector<uint8_t>& outPixels);
        
    private:
        class Impl; 
        std::unique_ptr<Impl> pImpl;
        
    };

}
