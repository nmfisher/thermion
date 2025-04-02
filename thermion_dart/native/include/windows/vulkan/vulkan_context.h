#pragma once

#include "d3d_context.h"
#include "vulkan_texture.h"
#include "vulkan_platform.h"
#include "utils.h"

#include <chrono>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <Windows.h>

#include "filament/backend/Platform.h"
#include "filament/backend/platforms/VulkanPlatform.h"

#include "import.h"

namespace thermion::windows::vulkan {

  class DLL_EXPORT ThermionVulkanContext {
    public:
        ThermionVulkanContext();
        ~ThermionVulkanContext();
        
        HANDLE CreateRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);        
        
        void DestroyRenderingSurface(HANDLE handle);
        
        void ResizeRenderingSurface(uint32_t width, uint32_t height, uint32_t left, uint32_t top);
        
        void Flush();
      
        filament::backend::VulkanPlatform *GetPlatform();
      
        void BlitFromSwapchain();
      
        void readPixelsFromImage(
          uint32_t width,
          uint32_t height,
          std::vector<uint8_t>& outPixels);
        
    private:
        class Impl; 
        std::unique_ptr<Impl> pImpl;
    };

}
