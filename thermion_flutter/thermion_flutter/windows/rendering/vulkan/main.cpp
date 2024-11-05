#define WIN32_LEAN_AND_MEAN

#include "vulkan_context.h"
#include "d3d_texture.h"
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

int main()
{
   auto ctx = new thermion::windows::vulkan::ThermionVulkanContext();
   ctx->CreateRenderingSurface(100, 100, 0, 0);
}
