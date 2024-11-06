#include <iostream>
#include <thread>
#include <chrono>
#include <vector>
#include <string>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory>
#include <thread>

#include "ThermionWin32.h"

#include "vulkan_context.h"

#include "d3d_texture.h"

#include "filament/backend/platforms/VulkanPlatform.h"
#include "filament/Engine.h"
#include "filament/Renderer.h"
#include "filament/View.h"
#include "filament/Viewport.h"
#include "filament/Scene.h"
#include "filament/SwapChain.h"
#include "filament/Texture.h"
#include "utils/EntityManager.h"

class TVulkanPlatform : public filament::backend::VulkanPlatform {
   public:
      SwapChainPtr createSwapChain(void* nativeWindow, uint64_t flags = 0,
            VkExtent2D extent = {0, 0}) override {
               std::cout << "OVERRIDEN METHOD CALLED" << std::endl;
               _current = filament::backend::VulkanPlatform::createSwapChain(nativeWindow, flags, extent);
               return _current;
            }

      SwapChainPtr _current;

};

int main()
{
   auto ctx = new thermion::windows::vulkan::ThermionVulkanContext();
   uint32_t width = 100;
   uint32_t height = 100;
   ctx->CreateRenderingSurface(width, height, 0, 0);
   auto *platform = new TVulkanPlatform();
   auto *engine = filament::Engine::create(filament::Engine::Backend::VULKAN, platform, nullptr, nullptr);
   auto *swapChain = engine->createSwapChain(width,height, filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT | filament::backend::SWAP_CHAIN_CONFIG_READABLE | filament::SwapChain::CONFIG_HAS_STENCIL_BUFFER);
   engine->flushAndWait();
   
   auto bundle = platform->getSwapChainBundle(platform->_current);

   if(engine->isValid(reinterpret_cast<filament::SwapChain*>(swapChain))) { 
      std::cout << "VALID SWAPCHIAN" << std::endl;
   } else { 
      std::cout << "INVALID SWAPCHIAN" << std::endl;
   }

   auto renderer = engine->createRenderer();
   filament::Renderer::ClearOptions clearOptions;
   clearOptions.clear = true;
   clearOptions.clearColor = { 1.0f, 0.0f, 0.5f, 1.0f };
   renderer->setClearOptions(clearOptions);
   auto scene = engine->createScene();
   auto *view = engine->createView();
   view->setViewport(filament::Viewport {0,0, width,height});
   view->setBlendMode(filament::View::BlendMode::TRANSLUCENT);
   view->setScene(scene);
   
   auto camera = engine->createCamera(utils::EntityManager::get().create());
   view->setCamera(camera);

   engine->flushAndWait();
   size_t pixelBufferSize = width * height * 4;
   auto out = new uint8_t[pixelBufferSize];
   auto pbd = filament::Texture::PixelBufferDescriptor(
        out, pixelBufferSize,
        filament::Texture::Format::RGBA,
        filament::Texture::Type::UBYTE, nullptr, nullptr, nullptr);
   renderer->beginFrame(swapChain);
   renderer->render(view);
   renderer->readPixels(0, 0, width, height, std::move(pbd));
   renderer->endFrame();
   
   engine->flushAndWait();
   std::cout << "FLUSHED" << std::endl;

   if(!thermion::windows::d3d::D3DTexture::SavePixelsAsBMP(out, width, height, width, "savepixels.bmp")) { 
      std::cout << "FAILED TO SAVE PIXELS" << std::endl;
   }

   // ctx->GetTexture()->Flush();
   ctx->BlitFromSwapchain(bundle.colors[0], width,height);
   std::cout << "BLIT COMPLETE" << std::endl;
   // ctx->Flush();
   // std::cout << "DONE" << std::endl;
   
   ctx->GetTexture()->SaveToBMP("vulkan_blit.bmp");

   // std::vector<uint8_t> outPixels(width * height * 4);

   // ctx->readPixelsFromImage(width, height, outPixels);

   // std::cout << "READBACK FROM VULKAN COMPLETE " << std::endl;

   // thermion::windows::d3d::D3DTexture::SavePixelsAsBMP(outPixels.data(), width, height, width, "vulkan_readback.bmp");

}

