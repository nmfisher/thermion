#include <iostream>
#include <chrono>
#include <thread>
#include <cmath>

// Include SDL first to avoid X11 macro conflicts
#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>

#undef Success  // Undefine X11's Success macro

#include "platforms/VulkanPlatformLinux.h"

#include "Engine.h"
#include "Renderer.h"
#include "View.h"
#include "Viewport.h"
#include "Scene.h"
#include "SwapChain.h"
#include "Camera.h"
#include "utils/EntityManager.h"

using namespace filament;

int main(int argc, char* argv[]) {
    std::cout << "=== Thermion SDL2 + Filament Vulkan Test ===" << std::endl;
    std::cout << "Window should show dark blue background" << std::endl;
    std::cout << "ESC to exit" << std::endl;

    // Initialize SDL2
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        std::cerr << "SDL_Init failed: " << SDL_GetError() << std::endl;
        return 1;
    }

    // Create window with Vulkan support
    SDL_Window* window = SDL_CreateWindow(
        "Thermion Filament Vulkan - Dark Blue Background",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        800, 600,
        SDL_WINDOW_VULKAN | SDL_WINDOW_SHOWN
    );

    if (!window) {
        std::cerr << "Failed to create window: " << SDL_GetError() << std::endl;
        SDL_Quit();
        return 1;
    }

    std::cout << "[OK] SDL2 Vulkan window created" << std::endl;

    // Get native window handle
    SDL_SysWMinfo wmInfo;
    SDL_VERSION(&wmInfo.version);
    SDL_GetWindowWMInfo(window, &wmInfo);

    void* nativeWindow = reinterpret_cast<void*>(wmInfo.info.x11.window);

    // Create Filament engine
    backend::VulkanPlatformLinux* platform = new backend::VulkanPlatformLinux();
    Engine* engine = Engine::create(Engine::Backend::VULKAN, platform, nullptr, nullptr);

    if (!engine) {
        std::cerr << "[ERROR] Failed to create engine" << std::endl;
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    std::cout << "[OK] Filament engine created" << std::endl;

    // Create swapchain from native window
    SwapChain* swapChain = engine->createSwapChain(nativeWindow);
    if (!swapChain) {
        std::cerr << "[ERROR] Failed to create swapchain" << std::endl;
        Engine::destroy(&engine);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    std::cout << "[OK] Swapchain created (on-screen rendering)" << std::endl;

    // Setup renderer, scene, view
    Renderer* renderer = engine->createRenderer();
    Scene* scene = engine->createScene();
    View* view = engine->createView();

    view->setScene(scene);
    view->setViewport({0, 0, 800, 600});

    // Set background color (dark blue) via Renderer
    Renderer::ClearOptions clearOptions;
    clearOptions.clearColor = {0.1f, 0.1f, 0.3f, 1.0f};
    clearOptions.clear = true;
    renderer->setClearOptions(clearOptions);

    // Create camera
    utils::Entity cameraEntity = utils::EntityManager::get().create();
    Camera* camera = engine->createCamera(cameraEntity);
    view->setCamera(camera);

    camera->setProjection(45.0, 800.0/600.0, 0.1, 100.0);
    camera->lookAt({0, 0, 5}, {0, 0, 0}, {0, 1, 0});

    std::cout << "[OK] Setup complete - starting render loop" << std::endl;
    std::cout << "\nYou should see a DARK BLUE window!" << std::endl;

    // Render loop
    bool running = true;
    int frameCount = 0;
    auto startTime = std::chrono::steady_clock::now();
    float hue = 0.0f;

    std::cout << "\n=== Rendering started - check window color! ===" << std::endl;

    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT || (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE)) {
                running = false;
            }
        }

        // Animate background color
        hue += 0.002f;
        if (hue > 1.0f) hue -= 1.0f;

        // Convert HSV to RGB for a rainbow effect
        float h = hue * 6.0f;
        float x = (1.0f - std::abs(std::fmod(h, 2.0f) - 1.0f));
        float r, g, b;
        if (h < 1.0f) { r = 1.0f; g = x; b = 0.0f; }
        else if (h < 2.0f) { r = x; g = 1.0f; b = 0.0f; }
        else if (h < 3.0f) { r = 0.0f; g = 1.0f; b = x; }
        else if (h < 4.0f) { r = 0.0f; g = x; b = 1.0f; }
        else if (h < 5.0f) { r = x; g = 0.0f; b = 1.0f; }
        else { r = 1.0f; g = 0.0f; b = x; }

        // Make it more visible (bright colors)
        math::float4 color = {r, g, b, 1.0f};

        // Debug output every 60 frames
        if (frameCount % 60 == 0) {
            std::cout << "Frame " << frameCount << ": clearing to RGB("
                      << color.r << ", " << color.g << ", " << color.b << ")" << std::endl;
        }

        // Update clear color
        Renderer::ClearOptions clearOptions;
        clearOptions.clearColor = color;
        clearOptions.clear = true;
        renderer->setClearOptions(clearOptions);

        // Render
        if (renderer->beginFrame(swapChain)) {
            renderer->render(view);
            renderer->endFrame();
            frameCount++;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }

    float elapsed = std::chrono::duration<float>(
        std::chrono::steady_clock::now() - startTime).count();

    std::cout << "\nRendered " << frameCount << " frames in " << elapsed << "s ("
              << (frameCount/elapsed) << " FPS)" << std::endl;

    // Cleanup - destroy entities first
    engine->destroy(cameraEntity);

    engine->flushAndWait();

    // Destroy engine (this also cleans up renderer, scene, view, swapchain)
    Engine::destroy(&engine);

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
