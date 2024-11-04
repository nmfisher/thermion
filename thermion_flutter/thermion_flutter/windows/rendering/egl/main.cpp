#include "egl_context.h"
#include <iostream>
#include <thread>
#include <chrono>

int main() {
    std::cout << "Initializing EGL Context..." << std::endl;
    
    thermion::windows::egl::ThermionEGLContext context;
    
    // Create a rendering surface
    const uint32_t width = 800;
    const uint32_t height = 600;
    
    std::cout << "Creating rendering surface " << width << "x" << height << std::endl;
    auto *texture = context.CreateRenderingSurface(width, height, 0, 0);
    
    void* sharedContext = context.GetSharedContext();
    if (sharedContext) {
        std::cout << "Successfully created shared context" << std::endl;
    } else {
        std::cout << "Failed to create shared context" << std::endl;
        return 1;
    }
    
    // Fill with blue and save
    texture->FillBlueAndSaveToBMP("output.bmp");
    
    std::cout << "Saved blue texture to output.bmp" << std::endl;
    
    std::cout << "EGL Context demo completed" << std::endl;
    return 0;
}