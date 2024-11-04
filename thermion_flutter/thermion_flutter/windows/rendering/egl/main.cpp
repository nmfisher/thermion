#include "egl_context.h"
#include <iostream>
#include <thread>
#include <chrono>

int main() {
    std::cout << "Initializing EGL Context..." << std::endl;
    
    thermion::windows::egl::FlutterEGLContext context;
    
    // Create a rendering surface
    const uint32_t width = 800;
    const uint32_t height = 600;
    
    std::cout << "Creating rendering surface " << width << "x" << height << std::endl;
    context.CreateRenderingSurface(width, height, 0, 0);
    
    void* sharedContext = context.GetSharedContext();
    if (sharedContext) {
        std::cout << "Successfully created shared context" << std::endl;
    } else {
        std::cout << "Failed to create shared context" << std::endl;
        return 1;
    }
    
    // Run a simple render loop
    std::cout << "Starting render loop..." << std::endl;
    for (int i = 0; i < 10; i++) {
        context.RenderCallback();
        std::cout << "Rendered frame " << i + 1 << std::endl;
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    
    std::cout << "EGL Context demo completed" << std::endl;
    return 0;
}