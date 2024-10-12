#include "thermion_window.h"

#include <cstdint>
#include <iostream>
#include <chrono> 
#include <thread>

#include <Windows.h>
#include <dwmapi.h>
#include <ShObjIdl.h>

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comctl32.lib")

namespace thermion {

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


LRESULT CALLBACK FilamentWindowProc(HWND const window, UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
    std::cout << message <<std::endl;
  case WM_MOUSEMOVE: {
    TRACKMOUSEEVENT event;
    event.cbSize = sizeof(event);
    event.hwndTrack = window;
    event.dwFlags = TME_HOVER;
    event.dwHoverTime = 200;
    auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
    if (user_data) {
      HWND flutterRootWindow = reinterpret_cast<HWND>(user_data);
      ::SetForegroundWindow(flutterRootWindow);
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
      
      // Get the ThermionWindow instance associated with this window
      ThermionWindow* thermionWindow = reinterpret_cast<ThermionWindow*>(
          GetWindowLongPtr(window, GWLP_USERDATA));
      
      if (thermionWindow) {
        HBRUSH brush = CreateSolidBrush(RGB(0, 0, 255));
        FillRect(hdc, &rect, brush);
        DeleteObject(brush);
      }
    
    break;
  }
  case WM_SIZE:
    break;
  case WM_MOVE:
  case WM_MOVING:
  case WM_ACTIVATE:
  case WM_WINDOWPOSCHANGED: {
    // NativeViewCore::GetInstance()->SetHitTestBehavior(0);
    auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
    if (user_data) {
      HWND flutterRootWindow = reinterpret_cast<HWND>(user_data);
      ::SetForegroundWindow(flutterRootWindow);
      // NativeViewCore::GetInstance()->SetHitTestBehavior(0);
      LONG ex_style = ::GetWindowLong(flutterRootWindow, GWL_EXSTYLE);
      ex_style &= ~(WS_EX_TRANSPARENT | WS_EX_LAYERED);
      ::SetWindowLong(flutterRootWindow, GWL_EXSTYLE, ex_style);
    }
    break;
  }
  default:
    break;
  }
  return ::DefWindowProc(window, message, wparam, lparam);
}

ThermionWindow::ThermionWindow(int width, 
                            int height,
                            int left,
                            int top) : _width(width), _height(height), _left(left), _top(top) {
  // create the HWND for Filament
  auto window_class = WNDCLASSEX{};
  ::SecureZeroMemory(&window_class, sizeof(window_class));
  window_class.cbSize = sizeof(window_class);
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.lpfnWndProc = FilamentWindowProc;
  window_class.hInstance = 0;
  window_class.lpszClassName = kClassName;
  window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  window_class.hbrBackground = ::CreateSolidBrush(RGB(0,255,0));
  ::RegisterClassExW(&window_class);
  _windowHandle = ::CreateWindow(kClassName, kWindowName, WS_OVERLAPPEDWINDOW,
                                 0, 0, _width, _height, nullptr,
                                 nullptr, GetModuleHandle(nullptr), nullptr);

  // Disable DWM animations
  auto disable_window_transitions = TRUE;
  DwmSetWindowAttribute(_windowHandle, DWMWA_TRANSITIONS_FORCEDISABLED,
                        &disable_window_transitions,
                        sizeof(disable_window_transitions));

  auto style = ::GetWindowLong(_windowHandle, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX |
             WS_EX_APPWINDOW);
  ::SetWindowLong(_windowHandle, GWL_STYLE, style);
  
  // // remove taskbar entry for the window we created
  // ITaskbarList3* taskbar = nullptr;
  // ::CoCreateInstance(CLSID_TaskbarList, 0, CLSCTX_INPROC_SERVER,
  //                    IID_PPV_ARGS(&taskbar));
  // taskbar->DeleteTab(_windowHandle);
  // taskbar->Release();
  ::ShowWindow(_windowHandle, SW_SHOW);
  UpdateWindow(_windowHandle);
}

void ThermionWindow::Resize(int width, int height, int left, int top) {
  _width = width;
  _height = height;
  _left = left;
  _top = top;
}

HWND ThermionWindow::GetHandle() { return _windowHandle; }
} // namespace thermion_flutter
