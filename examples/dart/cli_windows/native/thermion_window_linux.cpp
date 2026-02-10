#include <iostream>
#include <chrono>
#include <thread>
#include <atomic>

#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>

#include "thermion_window.h"

static SDL_Window* _window = nullptr;
static std::atomic<bool> _running{false};
static std::thread _eventThread;

static void EventLoop() {
    while (_running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT ||
                (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE)) {
                _running = false;
                return;
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(4));
    }
}

extern "C" {

intptr_t create_thermion_window(int width, int height, int left, int top) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        std::cerr << "SDL_Init failed: " << SDL_GetError() << std::endl;
        return 0;
    }

    _window = SDL_CreateWindow(
        "thermion_window",
        (left == 0) ? SDL_WINDOWPOS_CENTERED : left,
        (top == 0) ? SDL_WINDOWPOS_CENTERED : top,
        width, height,
        SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN
    );

    if (!_window) {
        std::cerr << "Failed to create window: " << SDL_GetError() << std::endl;
        SDL_Quit();
        return 0;
    }

    SDL_SysWMinfo wmInfo;
    SDL_VERSION(&wmInfo.version);
    if (!SDL_GetWindowWMInfo(_window, &wmInfo)) {
        std::cerr << "SDL_GetWindowWMInfo failed: " << SDL_GetError() << std::endl;
        SDL_DestroyWindow(_window);
        SDL_Quit();
        return 0;
    }

    intptr_t handle = static_cast<intptr_t>(wmInfo.info.x11.window);
    std::cout << "Created SDL2 OpenGL window, X11 handle: " << handle << std::endl;

    _running = true;
    _eventThread = std::thread(EventLoop);

    return handle;
}

void update() {
    // No-op: event loop runs in background thread
}

void cleanup() {
    _running = false;
    if (_eventThread.joinable()) {
        _eventThread.join();
    }
    if (_window) {
        SDL_DestroyWindow(_window);
        _window = nullptr;
    }
    SDL_Quit();
}

}
