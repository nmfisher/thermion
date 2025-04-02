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


int main()
{
   auto ctx = new thermion::windows::vulkan::ThermionVulkanContext();
   uint32_t width = 100;
   uint32_t height = 100;
   auto handle = ctx->CreateRenderingSurface(width, height, 0, 0);
      
   auto *engine = filament::Engine::create(filament::Engine::Backend::VULKAN, ctx->GetPlatform(), nullptr, nullptr);
   auto *swapChain = engine->createSwapChain(width,height, filament::backend::SWAP_CHAIN_CONFIG_TRANSPARENT | filament::backend::SWAP_CHAIN_CONFIG_READABLE | filament::SwapChain::CONFIG_HAS_STENCIL_BUFFER);
   engine->flushAndWait();
   
   if(engine->isValid(reinterpret_cast<filament::SwapChain*>(swapChain))) { 
      std::cout << "VALID SWAPCHIAN" << std::endl;
   } else { 
      std::cout << "INVALID SWAPCHIAN" << std::endl;
   }

   auto renderer = engine->createRenderer();
   filament::Renderer::ClearOptions clearOptions;
   clearOptions.clear = true;
   clearOptions.clearColor = { 0.0f, 1.0f, 0.0f, 1.0f };
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

   if(!SavePixelsAsBMP(out, width, height, width, "savepixels.bmp")) { 
      std::cout << "FAILED TO SAVE PIXELS" << std::endl;
   }

   std::cout << "SAVED PIXELS" << std::endl;

   // ctx->GetTexture()->Flush();
   ctx->BlitFromSwapchain();      

   std::vector<uint8_t> outPixels(width * height * 4);

   ctx->readPixelsFromImage(width, height, outPixels);

   std::cout << "READBACK FROM VULKAN COMPLETE " << std::endl;

   SavePixelsAsBMP(outPixels.data(), width, height, width, "vulkan_readback.bmp");

   std::cout << "CREATED" << std::endl;
   ctx->DestroyRenderingSurface(handle);
   std::cout << "FINISHED" << std::endl;

}

