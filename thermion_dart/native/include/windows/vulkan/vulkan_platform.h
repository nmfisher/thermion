#pragma once

#include "d3d_context.h"
#include "vulkan_texture.h"
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

class TVulkanPlatform : public filament::backend::VulkanPlatform {
    public:
 
       TVulkanPlatform();
       ~TVulkanPlatform();
 
       virtual VulkanPlatform::Customization getCustomization() const noexcept;
 
       SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags,
             VkExtent2D extent = {0, 0}) override;
       
       void destroy(SwapChainPtr handle) override;
 
       VkResult present(SwapChainPtr handle, uint32_t index, VkSemaphore finishedDrawing) override;
       
       SwapChainPtr current;
       std::mutex mutex;
       uint32_t currentColorIndex = 0;
     
      private:  
       filament::backend::VulkanPlatform::Customization _customization;
 
 };
}