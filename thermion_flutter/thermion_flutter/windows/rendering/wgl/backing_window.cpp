#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comctl32.lib")


#include "backing_window.h"
#include <cstdint>
#include <iostream>
#include <chrono>
#include <thread>
#include <Windows.h>
#include <dwmapi.h>
#include <ShObjIdl.h>
#include <dxgi.h>


namespace thermion_flutter {

static constexpr auto kClassName = L"FLUTTER_FILAMENT_WINDOW";
static constexpr auto kWindowName = L"thermion_flutter_window";
static WPARAM last_wm_size_wparam_ = SIZE_RESTORED;
uint64_t last_thread_time_ = 0;

LRESULT CALLBACK FilamentWindowProc(HWND const window, UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CREATE: {
      // Set initial background color
      SetClassLongPtr(window, GCLP_HBRBACKGROUND, 
                     (LONG_PTR)CreateSolidBrush(RGB(0, 255, 0)));
      break;
    }

    case WM_PAINT: {
      // PAINTSTRUCT ps;
      // HDC hdc = BeginPaint(window, &ps);
      
      RECT rect;
      GetClientRect(window, &rect);
      
      // // Create a solid green brush and fill the window
      // HBRUSH brush = CreateSolidBrush(RGB(0, 255, 0));
      // FillRect(hdc, &rect, brush);
      // DeleteObject(brush);
      
      // EndPaint(window, &ps);
      return 0;
    }

    case WM_ERASEBKGND: {
      // HDC hdc = (HDC)wparam;
      // RECT rect;
      // GetClientRect(window, &rect);
      
      // HBRUSH brush = CreateSolidBrush(RGB(0, 255, 0));
      // FillRect(hdc, &rect, brush);
      // DeleteObject(brush);
      
      return TRUE;
    }

    case WM_NCHITTEST:
      return HTTRANSPARENT;

    default:
      break;
  }
    // Initial paint
  InvalidateRect(window, NULL, TRUE);
  UpdateWindow(window);
  return ::DefWindowProc(window, message, wparam, lparam);
}

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

BackingWindow::BackingWindow(flutter::PluginRegistrarWindows *pluginRegistrar,
                           int width, 
                           int height,
                           int left,
                           int top) : _width(width), _height(height), _left(left), _top(top) {
  PrintDefaultGPU();
  _flutterViewWindow = pluginRegistrar->GetView()->GetNativeWindow();
  _flutterRootWindow = ::GetAncestor(_flutterViewWindow, GA_ROOT);

  auto window_class = WNDCLASSEX{};
  ::SecureZeroMemory(&window_class, sizeof(window_class));
  window_class.cbSize = sizeof(window_class);
  window_class.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
  window_class.lpfnWndProc = FilamentWindowProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kClassName;
  window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  window_class.hbrBackground = CreateSolidBrush(RGB(0, 255, 0));
  ::RegisterClassExW(&window_class);

  // Create window with updated styles
  _windowHandle = ::CreateWindowEx(
    WS_EX_LAYERED | WS_EX_TRANSPARENT,  // Removed WS_EX_NOREDIRECTIONBITMAP
    kClassName,
    kWindowName,
    WS_POPUP,
    _left,
    _top,
    _width,
    _height,
    nullptr,
    nullptr,
    GetModuleHandle(nullptr),
    nullptr);

  if (!_windowHandle) {
    // DWORD error = GetLastError();
    // Handle error
    return;
  }

  // Store backing window pointer
  ::SetWindowLongPtr(_windowHandle, GWLP_USERDATA,
                    reinterpret_cast<LONG_PTR>(this));

  // Set window position
  ::SetWindowPos(_windowHandle, 
                 HWND_TOPMOST,
                 _left,
                 _top,
                 _width,
                 _height,
                 SWP_NOACTIVATE | SWP_SHOWWINDOW);

  // Remove taskbar entry
  ITaskbarList3* taskbar = nullptr;
  if (SUCCEEDED(::CoCreateInstance(CLSID_TaskbarList, 0, CLSCTX_INPROC_SERVER,
                                 IID_PPV_ARGS(&taskbar)))) {
    taskbar->DeleteTab(_windowHandle);
    taskbar->Release();
  }

  // Set up transparency - key changes here
  COLORREF transparentColor = RGB(0, 0, 0);  // Black is transparent
  BYTE alpha = 255;  // Fully opaque for non-transparent colors
  
  // Use both color keying and alpha blending
  SetLayeredWindowAttributes(_windowHandle, transparentColor, alpha, 
                           LWA_COLORKEY | LWA_ALPHA);

  // Register for Flutter window events
  pluginRegistrar->RegisterTopLevelWindowProcDelegate(
    [=](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
      switch (message) {
        case WM_MOVE:
        case WM_MOVING:
        case WM_WINDOWPOSCHANGED: {
          RECT flutterRect;
          ::GetWindowRect(_flutterRootWindow, &flutterRect);
          ::SetWindowPos(_windowHandle,
                        HWND_TOPMOST,
                        flutterRect.left + _left,
                        flutterRect.top + _top,
                        _width,
                        _height,
                        SWP_NOACTIVATE | SWP_SHOWWINDOW);
          UpdateWindow(_windowHandle);
          break;
        }
      }
      // Force a redraw
      InvalidateRect(_windowHandle, NULL, TRUE);
      return std::nullopt;
    });

  // Initial paint
  InvalidateRect(_windowHandle, NULL, TRUE);
  UpdateWindow(_windowHandle);
}


void BackingWindow::Destroy() {
  if (_windowHandle) {
    ::ShowWindow(_windowHandle, SW_HIDE);
    
    ITaskbarList3* taskbar = nullptr;
    if (SUCCEEDED(::CoCreateInstance(CLSID_TaskbarList, 0, CLSCTX_INPROC_SERVER,
                                   IID_PPV_ARGS(&taskbar)))) {
      taskbar->DeleteTab(_windowHandle);
      taskbar->Release();
    }
    
    ::SetWindowLongPtr(_windowHandle, GWLP_USERDATA, 0);
    ::DestroyWindow(_windowHandle);
    _windowHandle = nullptr;
  }

  ::UnregisterClass(kClassName, GetModuleHandle(nullptr));
  
  _flutterViewWindow = nullptr;
  _flutterRootWindow = nullptr;
  _width = 0;
  _height = 0;
  _left = 0;
  _top = 0;
}

void BackingWindow::Resize(int width, int height, int left, int top) {
  _width = width;
  _height = height;
  _left = left;
  _top = top;

  RECT flutterRect;
  ::GetWindowRect(_flutterRootWindow, &flutterRect);
  ::SetWindowPos(_windowHandle,
                 HWND_TOPMOST,
                 flutterRect.left + _left,
                 flutterRect.top + _top,
                 _width,
                 _height,
                 SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

HWND BackingWindow::GetHandle() {
  return _windowHandle;
}

} // namespace thermion_flutter