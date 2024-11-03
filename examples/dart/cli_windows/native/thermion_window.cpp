#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "opengl32.lib")
#pragma comment(lib, "Gdi32.lib")
#pragma comment(lib, "User32.lib")
#pragma comment(lib, "dxgi.lib")

#include <dxgi.h>
#include <cstdint>
#include <chrono> 
#include <thread>
#include <algorithm>
#include <Windows.h>
#include <dwmapi.h>
#include <ShObjIdl.h>

#include <iostream>
#include <Windows.h>

#include "thermion_window.h"

namespace thermion {

void PrintDefaultGPU() {
    IDXGIFactory* factory = nullptr;
    CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&factory);
    
    IDXGIAdapter* adapter = nullptr;
    factory->EnumAdapters(0, &adapter); // 0 is the default adapter

    DXGI_ADAPTER_DESC desc;
    adapter->GetDesc(&desc);
    
    std::wcout << L"GPU: " << desc.Description << std::endl;

    adapter->Release();
    factory->Release();
}

  ///
/// Instantiating a ThermionWindow creates a HWND that can be passed 
/// to Filament to create a swapchain.
///
///
class ThermionWindow {
    public:
    ThermionWindow(
        int width, 
        int height, 
        int left,
        int top);
    HWND GetHandle();
    void Resize(int width, int height, int left, int top);
    uint32_t _width = 0;
    uint32_t _height = 0;
    uint32_t _left = 0;
    uint32_t _top = 0;
    private:
        HWND _windowHandle;

};

static ThermionWindow* _window;


static bool _running = false;
static std::thread _renderThread;

// Add these for timing and stats
static int _frameCount = 0;
static std::chrono::time_point<std::chrono::steady_clock> _lastFpsLog;

static void RenderLoop() {
    _lastFpsLog = std::chrono::steady_clock::now();
    auto lastFrame = std::chrono::steady_clock::now();

    while (_running) {
        auto now = std::chrono::steady_clock::now();
        auto frameDuration = std::chrono::duration_cast<std::chrono::microseconds>(now - lastFrame).count();
        
        // Force a redraw
        InvalidateRect(_window->GetHandle(), NULL, FALSE);

        // Process any pending messages
        MSG msg;
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                _running = false;
                break;
            }
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }

        // Wait for vsync
        DwmFlush();

        // Update timing stats
        lastFrame = now;
        _frameCount++;

        // Log FPS every second
        auto timeSinceLastLog = std::chrono::duration_cast<std::chrono::milliseconds>(now - _lastFpsLog).count();
        if (timeSinceLastLog >= 1000) {  // Every second
            float fps = (_frameCount * 1000.0f) / timeSinceLastLog;
            float avgFrameTime = timeSinceLastLog / (float)_frameCount;
            std::cout << "FPS: " << fps << " Frame Time: " << avgFrameTime << "ms" 
                     << " Last Frame: " << frameDuration / 1000.0f << "ms" << std::endl;
            
            _frameCount = 0;
            _lastFpsLog = now;
        }
    }
}

extern "C" {
  
 EMSCRIPTEN_KEEPALIVE intptr_t create_thermion_window(int width, int height, int left, int top) { 
                _window = new ThermionWindow(width, height, left, top);
        
        // Start the render thread
        _running = true;
        _renderThread = std::thread(RenderLoop);
        
        return (intptr_t)_window->GetHandle();
    }

     // Update function can now be simplified or removed since rendering happens in the thread
    EMSCRIPTEN_KEEPALIVE void update() {     
        // This could be used to trigger specific updates if needed
        InvalidateRect(_window->GetHandle(), NULL, FALSE);
    }

       // Add a cleanup function
    EMSCRIPTEN_KEEPALIVE void cleanup() {
        _running = false;
        if (_renderThread.joinable()) {
            _renderThread.join();
        }
        if (_window) {
            delete _window;
            _window = nullptr;
        }
    }
}

static constexpr auto kClassName = L"THERMION_WINDOW";
static constexpr auto kWindowName = L"thermion_window";
static bool was_window_hidden_due_to_minimize_ = false;
static WPARAM last_wm_size_wparam_ = SIZE_RESTORED;
uint64_t last_thread_time_ = 0;
static constexpr auto kNativeViewPositionAndShowDelay = 300;

typedef enum _WINDOWCOMPOSITIONATTRIB {
  WCA_UNDEFINED = 0,
  WCA_NCRENDERING_ENABLED = 1,
  WCA_NCRENDERING_POLICY = 2,
  WCA_TRANSITIONS_FORCEDISABLED = 3,
  WCA_ALLOW_NCPAINT = 4,
  WCA_CAPTION_BUTTON_BOUNDS = 5,
  WCA_NONCLIENT_RTL_LAYOUT = 6,
  WCA_FORCE_ICONIC_REPRESENTATION = 7,
  WCA_EXTENDED_FRAME_BOUNDS = 8,
  WCA_HAS_ICONIC_BITMAP = 9,
  WCA_THEME_ATTRIBUTES = 10,
  WCA_NCRENDERING_EXILED = 11,
  WCA_NCADORNMENTINFO = 12,
  WCA_EXCLUDED_FROM_LIVEPREVIEW = 13,
  WCA_VIDEO_OVERLAY_ACTIVE = 14,
  WCA_FORCE_ACTIVEWINDOW_APPEARANCE = 15,
  WCA_DISALLOW_PEEK = 16,
  WCA_CLOAK = 17,
  WCA_CLOAKED = 18,
  WCA_ACCENT_POLICY = 19,
  WCA_FREEZE_REPRESENTATION = 20,
  WCA_EVER_UNCLOAKED = 21,
  WCA_VISUAL_OWNER = 22,
  WCA_HOLOGRAPHIC = 23,
  WCA_EXCLUDED_FROM_DDA = 24,
  WCA_PASSIVEUPDATEMODE = 25,
  WCA_USEDARKMODECOLORS = 26,
  WCA_LAST = 27
} WINDOWCOMPOSITIONATTRIB;

typedef struct _WINDOWCOMPOSITIONATTRIBDATA {
  WINDOWCOMPOSITIONATTRIB Attrib;
  PVOID pvData;
  SIZE_T cbData;
} WINDOWCOMPOSITIONATTRIBDATA;

typedef enum _ACCENT_STATE {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_ENABLE_HOSTBACKDROP = 5,
  ACCENT_INVALID_STATE = 6
} ACCENT_STATE;

typedef struct _ACCENT_POLICY {
  ACCENT_STATE AccentState;
  DWORD AccentFlags;
  DWORD GradientColor;
  DWORD AnimationId;
} ACCENT_POLICY;

typedef BOOL(WINAPI* _GetWindowCompositionAttribute)(
    HWND, WINDOWCOMPOSITIONATTRIBDATA*);
typedef BOOL(WINAPI* _SetWindowCompositionAttribute)(
    HWND, WINDOWCOMPOSITIONATTRIBDATA*);

static _SetWindowCompositionAttribute g_set_window_composition_attribute = NULL;
static bool g_set_window_composition_attribute_initialized = false;

typedef LONG NTSTATUS, *PNTSTATUS;
#define STATUS_SUCCESS (0x00000000)

typedef NTSTATUS(WINAPI* RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

RTL_OSVERSIONINFOW GetWindowsVersion() {
  HMODULE hmodule = ::GetModuleHandleW(L"ntdll.dll");
  if (hmodule) {
    RtlGetVersionPtr rtl_get_version_ptr =
        (RtlGetVersionPtr)::GetProcAddress(hmodule, "RtlGetVersion");
    if (rtl_get_version_ptr != nullptr) {
      RTL_OSVERSIONINFOW rovi = {0};
      rovi.dwOSVersionInfoSize = sizeof(rovi);
      if (STATUS_SUCCESS == rtl_get_version_ptr(&rovi)) {
        return rovi;
      }
    }
  }
  RTL_OSVERSIONINFOW rovi = {0};
  return rovi;
}

void SetWindowComposition(HWND window, int32_t accent_state,
                          int32_t gradient_color) {
  // TODO: Look for a better available API.
  if (GetWindowsVersion().dwBuildNumber >= 18362) {
    if (!g_set_window_composition_attribute_initialized) {
      auto user32 = ::GetModuleHandleA("user32.dll");
      if (user32) {
        g_set_window_composition_attribute =
            reinterpret_cast<_SetWindowCompositionAttribute>(
                ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
        if (g_set_window_composition_attribute) {
          g_set_window_composition_attribute_initialized = true;
        }
      }
    }
    ACCENT_POLICY accent = {static_cast<ACCENT_STATE>(accent_state), 2,
                            static_cast<DWORD>(gradient_color), 0};
    WINDOWCOMPOSITIONATTRIBDATA data;
    data.Attrib = WCA_ACCENT_POLICY;
    data.pvData = &accent;
    data.cbData = sizeof(accent);
    g_set_window_composition_attribute(window, &data);
  }
}


// Add tracking for drag state
static bool isDragging = false;
static POINT dragStart = {0, 0};
static POINT windowStart = {0, 0};


LRESULT CALLBACK FilamentWindowProc(HWND const window, UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
    switch (message) {
        case WM_DESTROY: {
            PostQuitMessage(0);
            return 0;
        }
        case WM_NCHITTEST: {
            POINT pt = { LOWORD(lparam), HIWORD(lparam) };
            ScreenToClient(window, &pt);
            return HTCAPTION;
        }
        
        case WM_MOUSEMOVE: {
            TRACKMOUSEEVENT event;
            event.cbSize = sizeof(event);
            event.hwndTrack = window;
            event.dwFlags = TME_HOVER;
            event.dwHoverTime = 200;
            auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
            if (user_data) {
                HWND flutterRootWindow = reinterpret_cast<HWND>(user_data);
                LONG ex_style = ::GetWindowLong(flutterRootWindow, GWL_EXSTYLE);
                ex_style &= ~(WS_EX_TRANSPARENT | WS_EX_LAYERED);
                ::SetWindowLong(flutterRootWindow, GWL_EXSTYLE, ex_style);
            }
            break;
        }

        case WM_ERASEBKGND: {
            HDC hdc = (HDC)wparam;
            RECT rect;
            GetClientRect(window, &rect);
            
            ThermionWindow* thermionWindow = reinterpret_cast<ThermionWindow*>(
                GetWindowLongPtr(window, GWLP_USERDATA));
            
            if (thermionWindow) {
                HBRUSH brush = CreateSolidBrush(RGB(0, 0, 255));
                FillRect(hdc, &rect, brush);
                DeleteObject(brush);
            }
            return TRUE;
        }

        case WM_SIZE:
        case WM_MOVE:
        case WM_MOVING:
        case WM_WINDOWPOSCHANGED: {
            auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
            if (user_data) {
                HWND flutterRootWindow = reinterpret_cast<HWND>(user_data);
                LONG ex_style = ::GetWindowLong(flutterRootWindow, GWL_EXSTYLE);
                ex_style &= ~(WS_EX_TRANSPARENT | WS_EX_LAYERED);
                ::SetWindowLong(flutterRootWindow, GWL_EXSTYLE, ex_style);
            }
            break;
        }

        default:
            return ::DefWindowProc(window, message, wparam, lparam);
    }
    return 0;
}

ThermionWindow::ThermionWindow(int width, 
                            int height,
                            int left,
                            int top) : _width(width), _height(height), _left(left), _top(top) {

                              PrintDefaultGPU();

    auto window_class = WNDCLASSEX{};
    ::SecureZeroMemory(&window_class, sizeof(window_class));
    window_class.cbSize = sizeof(window_class);
    window_class.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    window_class.lpfnWndProc = FilamentWindowProc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.lpszClassName = L"THERMION_WINDOW";
    window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
    window_class.hbrBackground = ::CreateSolidBrush(RGB(0,255,0));
    ::RegisterClassExW(&window_class);

    // Create a normal popup window without forcing it to be topmost
    _windowHandle = ::CreateWindowW(
        L"THERMION_WINDOW", 
        L"thermion_window",
        WS_OVERLAPPEDWINDOW,
        left, top, width, height,
        nullptr, nullptr,
        GetModuleHandle(nullptr), 
        nullptr
    );

    // Store the this pointer for use in window procedure
    ::SetWindowLongPtr(_windowHandle, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));

    // Disable DWM animations
    auto disable_window_transitions = TRUE;
    DwmSetWindowAttribute(_windowHandle, DWMWA_TRANSITIONS_FORCEDISABLED,
                        &disable_window_transitions,
                        sizeof(disable_window_transitions));

    ::ShowWindow(_windowHandle, SW_SHOW);
    UpdateWindow(_windowHandle);
}

void ThermionWindow::Resize(int width, int height, int left, int top) {
    _width = width;
    _height = height;
    _left = left;
    _top = top;
    ::SetWindowPos(_windowHandle, nullptr, left, top, width, height,
                   SWP_NOZORDER | SWP_NOACTIVATE);
}

HWND ThermionWindow::GetHandle() { return _windowHandle; }

} // namespace thermion