#include "backing_window.h"

#include <cstdint>
#include <iostream>
#include <chrono> 
#include <thread>

#include <Windows.h>
#include <dwmapi.h>
#include <ShObjIdl.h>

#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comctl32.lib")

namespace thermion_filament {

static constexpr auto kClassName = L"FLUTTER_FILAMENT_WINDOW";
static constexpr auto kWindowName = L"thermion_flutter_window";
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
    // Prevent erasing of |window| when it is unfocused and minimized or
    // moved out of screen etc.
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

BackingWindow::BackingWindow(flutter::PluginRegistrarWindows *pluginRegistrar,
                            int width, 
                            int height,
                            int left,
                            int top) : _width(width), _height(height), _left(left), _top(top) {
  // a Flutter application actually has two windows - the innner window contains the FlutterView.
  // although we will use the outer window for various events,  we always position things relative to the inner window.
  _flutterViewWindow = pluginRegistrar->GetView()->GetNativeWindow();
  _flutterRootWindow = ::GetAncestor(_flutterViewWindow, GA_ROOT);

  RECT flutterChildRect;
  ::GetWindowRect(_flutterViewWindow, &flutterChildRect);

  // set composition to allow transparency
  SetWindowComposition(_flutterRootWindow, 6, 0);

  // register a top-level WindowProcDelegate to handle window events
  pluginRegistrar->RegisterTopLevelWindowProcDelegate([=](HWND hwnd,
                                                          UINT message,
                                                          WPARAM wparam,
                                                          LPARAM lparam) {
    switch (message) {
    case WM_MOUSEMOVE: {
        break;
      }
    case WM_ACTIVATE: {
      RECT rootWindowRect;
      ::GetWindowRect(_flutterViewWindow, &rootWindowRect);
      // Position |native_view| such that it's z order is behind |window_| &
      // redraw aswell.
      ::SetWindowPos(_windowHandle, _flutterRootWindow, rootWindowRect.left + _left,
                     rootWindowRect.top + _top, _width,
                     _height, SWP_NOACTIVATE);
      break;
    }
    case WM_SIZE: {
      if (wparam != SIZE_RESTORED || last_wm_size_wparam_ == SIZE_MINIMIZED ||
          last_wm_size_wparam_ == SIZE_MAXIMIZED ||
          was_window_hidden_due_to_minimize_) {
        was_window_hidden_due_to_minimize_ = false;
        // Minimize condition is handled separately inside |WM_WINDOWPOSCHANGED|
        // case, since we don't want to cause unnecessary redraws (& show/hide)
        // when user is resizing the window by dragging the window border.
        SetWindowComposition(_flutterRootWindow, 0, 0);
        ::ShowWindow(_windowHandle, SW_HIDE);
        last_thread_time_ =
            std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch())
                .count();
        std::thread(
            [=](uint64_t time) {
              if (time < last_thread_time_) {
                return;
              }
              std::this_thread::sleep_for(
                  std::chrono::milliseconds(kNativeViewPositionAndShowDelay));
              SetWindowComposition(_flutterRootWindow, 6, 0);
              // Handling SIZE_MINIMIZED separately.
              if (wparam != SIZE_MINIMIZED) {
                ::ShowWindow(_windowHandle, SW_SHOWNOACTIVATE);
              }

              RECT flutterViewRect;
              ::GetWindowRect(_flutterViewWindow, &flutterViewRect);
              ::SetWindowPos(_windowHandle, _flutterRootWindow, flutterViewRect.left + _left,
                            flutterViewRect.top + _top, _width, _height,
                            SWP_NOACTIVATE);
            },
            last_thread_time_)
            .detach();
      }
      last_wm_size_wparam_ = wparam;
      break;
    }
    case WM_MOVE:
    case WM_MOVING:
    case WM_WINDOWPOSCHANGED: {
      RECT rootWindowRect;
      ::GetWindowRect(_flutterViewWindow, &rootWindowRect);
      if (rootWindowRect.right - rootWindowRect.left > 0 &&
          rootWindowRect.bottom - rootWindowRect.top > 0) {
        ::SetWindowPos(_windowHandle, _flutterRootWindow, rootWindowRect.left + _left,
                       rootWindowRect.top + _top, _width,
                       _height, SWP_NOACTIVATE);
        // |window_| is minimized.
        if (rootWindowRect.left < 0 && rootWindowRect.top < 0 &&
            rootWindowRect.right < 0 && rootWindowRect.bottom < 0) {
          // Hide |native_view_container_| to prevent showing
          // |native_view_container_| before |window_| placement
          // i.e when restoring window after clicking the taskbar icon.
          SetWindowComposition(_flutterRootWindow, 0, 0);
          ::ShowWindow(_windowHandle, SW_HIDE);
          was_window_hidden_due_to_minimize_ = true;
        }
      }
      break;
    }
    case WM_CLOSE: {
      // close
      break;
    }
    default:
      break;
    }
    return std::nullopt;
  });

  // create the HWND for Filament
  auto window_class = WNDCLASSEX{};
  ::SecureZeroMemory(&window_class, sizeof(window_class));
  window_class.cbSize = sizeof(window_class);
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.lpfnWndProc = FilamentWindowProc;
  window_class.hInstance = 0;
  window_class.lpszClassName = kClassName;
  window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  window_class.hbrBackground = ::CreateSolidBrush(0);
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
  
  ::SetWindowLongPtr(_windowHandle, GWLP_USERDATA,
                     reinterpret_cast<LONG>(_flutterRootWindow));

  RECT flutterViewRect;
  ::GetWindowRect(_flutterViewWindow, &flutterViewRect);

  ::SetWindowPos(_windowHandle, _flutterRootWindow, flutterViewRect.left + _left,
                 flutterViewRect.top + _top, _width, _height,
                 SWP_NOACTIVATE);

  // remove taskbar entry for the window we created
  ITaskbarList3* taskbar = nullptr;
  ::CoCreateInstance(CLSID_TaskbarList, 0, CLSCTX_INPROC_SERVER,
                     IID_PPV_ARGS(&taskbar));
  taskbar->DeleteTab(_windowHandle);
  taskbar->Release();

  ::ShowWindow(_windowHandle, SW_SHOW);
  ::ShowWindow(_flutterViewWindow, SW_SHOW);
  ::SetForegroundWindow(_flutterViewWindow);
  ::SetFocus(_flutterViewWindow);
  LONG ex_style = ::GetWindowLong(_flutterRootWindow, GWL_EXSTYLE);
  ex_style &= ~(WS_EX_TRANSPARENT | WS_EX_LAYERED);
  ::SetWindowLong(_flutterRootWindow, GWL_EXSTYLE, ex_style);
}

void BackingWindow::Resize(int width, int height, int left, int top) {
  _width = width;
  _height = height;
  _left = left;
  _top = top;
  RECT flutterViewRect;
  ::GetWindowRect(_flutterViewWindow, &flutterViewRect);
    std::cout << "Resizing to " << _width << " x " << _height << " with LT" << _left << " " << _top << " flutter view rect" << flutterViewRect.left << " " << flutterViewRect.top  << " " << flutterViewRect.right << " " << flutterViewRect.bottom << std::endl;

  ::SetWindowPos(_windowHandle, _flutterRootWindow, flutterViewRect.left + _left,
                 flutterViewRect.top + _top, _width, _height,
                 SWP_NOACTIVATE);
}

HWND BackingWindow::GetHandle() { return _windowHandle; }
} // namespace thermion_filament
