#include "backing_window.h"

namespace polyvox_filament {

static constexpr auto kClassName = L"FLUTTER_FILAMENT_WINDOW";
static constexpr auto kWindowName = L"flutter_filament_window";
static bool was_window_hidden_due_to_minimize_ = false;
static WPARAM last_wm_size_wparam_ = SIZE_RESTORED;
uint64_t last_thread_time_ = 0;
static constexpr auto kNativeViewPositionAndShowDelay = 300;

LRESULT NativeViewSubclassProc(HWND window, UINT message, WPARAM wparam,
                               LPARAM lparam, UINT_PTR subclass_id,
                               DWORD_PTR ref_data) noexcept {
  switch (message) {
  case WM_ERASEBKGND: {
    // Prevent erasing of |window| when it is unfocused and minimized or
    // moved out of screen etc.
    return 1;
  }
  case WM_SIZE: {
    // Prevent unnecessary maxmize, minimize or restore messages for |window|.
    // Since it is |SetParent|'ed into native view container.
    return 1;
  }
  default:
    break;
  }
  return ::DefSubclassProc(window, message, wparam, lparam);
}

LRESULT CALLBACK FilamentWindowProc(HWND const window, UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
  case WM_MOUSEMOVE: {
    std::cout << "FILAMENT MOUSE MOVE" << std::endl;
    TRACKMOUSEEVENT event;
    event.cbSize = sizeof(event);
    event.hwndTrack = window;
    event.dwFlags = TME_HOVER;
    event.dwHoverTime = 200;
    auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
    if (user_data) {
      std::cout << "setting foreground in filamentwindwoproc" << std::endl;
      HWND flutterRootWindow = reinterpret_cast<HWND>(user_data);
      ::SetForegroundWindow(flutterRootWindow);
      // NativeViewCore::GetInstance()->SetHitTestBehavior(0);
      LONG ex_style = ::GetWindowLong(flutterRootWindow, GWL_EXSTYLE);
      ex_style &= ~(WS_EX_TRANSPARENT | WS_EX_LAYERED);
      ::SetWindowLong(flutterRootWindow, GWL_EXSTYLE, ex_style);
    }
    break;
  }
  case WM_ERASEBKGND: {
    std::cout << "FILAMENT ERASE BKGND" << std::endl;
    // Prevent erasing of |window| when it is unfocused and minimized or
    // moved out of screen etc.
    return 1;
  }
  case WM_SIZE:
  case WM_MOVE:
  case WM_MOVING:
  case WM_ACTIVATE:
  case WM_WINDOWPOSCHANGED: {
    std::cout << "FILAMENT POS CHANGED" << std::endl;
    // NativeViewCore::GetInstance()->SetHitTestBehavior(0);
    auto user_data = ::GetWindowLongPtr(window, GWLP_USERDATA);
    if (user_data) {
      std::cout << "setting foreground in filamentwindwoproc" << std::endl;
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


class BackingWindow {

    BackingWindow::BackingWindow(
        flutter::PluginRegistrarWindows *pluginRegistrar,
        int initialWidth, 
        int initialHeight) { 
        // get the root Flutter window
        HWND flutterWindow = pluginRegistrar->GetView()->GetNativeWindow();
        _flutterRootWindow = ::GetAncestor(flutterWindow, GA_ROOT);

        // set composition to allow transparency
        flutternativeview::SetWindowComposition(_flutterRootWindow, 6, 0);

        // register a top-level WindowProcDelegate to handle window events
        pluginRegistrar->RegisterTopLevelWindowProcDelegate([=](HWND hwnd,
                                                                UINT message,
                                                                WPARAM wparam,
                                                                LPARAM lparam) {
        switch (message) {
            case WM_ACTIVATE: {
            std::cout << "WM_ACTIVATE" << std::endl;
            RECT window_rect;
            ::GetWindowRect(_flutterRootWindow, &window_rect);
            // Position |native_view| such that it's z order is behind |window_| &
            // redraw aswell.
            ::SetWindowPos(_windowHandle, _flutterRootWindow, window_rect.left,
                            window_rect.top, window_rect.right - window_rect.left,
                            window_rect.bottom - window_rect.top, SWP_NOACTIVATE);
            break;
            }
            case WM_SIZE: {
            std::cout << "WM_SIZE" << std::endl;

            // Handle Windows's minimize & maximize animations properly.
            // Since |SetWindowPos| & other Win32 APIs on |native_view_container_|
            // do not re-produce the same DWM animations like  actual user
            // interractions on the |window_| do (though both windows are overlapped
            // tightly but maximize and minimze animations can't be mimiced for the
            // both of them at the same time), the best solution is to make the
            // |window_| opaque & hide |native_view_container_| & alter it's position.
            // After that, finally make |native_view_container_| visible again &
            // |window_| transparent again. This approach is not perfect, but it's the
            // best we can do. The minimize & maximize animations on the |window_|
            // look good with just a slight glitch on the visible native views. In
            // future, maybe replacing the |NativeView| widget (Flutter-side) with
            // equivalent window screenshot will result in a totally seamless
            // experience.
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
                    },
                    last_thread_time_)
                    .detach();
            }
            last_wm_size_wparam_ = wparam;
            break;
            }
            // Keep |native_view_container_| behind the |window_|.
            case WM_MOVE:
            case WM_MOVING:
            case WM_WINDOWPOSCHANGED: {
            std::cout << "FLUTTER WINDOWPOSCHANGED"<< std::endl;
            RECT window_rect;
            ::GetWindowRect(_flutterRootWindow, &window_rect);
            if (window_rect.right - window_rect.left > 0 &&
                window_rect.bottom - window_rect.top > 0) {
                ::SetWindowPos(_windowHandle, _flutterRootWindow, window_rect.left,
                            window_rect.top, window_rect.right - window_rect.left,
                            window_rect.bottom - window_rect.top, SWP_NOACTIVATE);
                // |window_| is minimized.
                if (window_rect.left < 0 && window_rect.top < 0 &&
                    window_rect.right < 0 && window_rect.bottom < 0) {
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
        return NULL;
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
        window_class.hbrBackground = ::CreateSolidBrush(RGB(0, 255, 0));
        ::RegisterClassExW(&window_class);
        _windowHandle =
            ::CreateWindow(kClassName, kWindowName, WS_OVERLAPPEDWINDOW, 0, 0, initialWidth, initialHeight,
                            nullptr, nullptr, GetModuleHandle(nullptr), nullptr);

        // Disable DWM animations
        auto disable_window_transitions = TRUE;
        DwmSetWindowAttribute(_windowHandle, DWMWA_TRANSITIONS_FORCEDISABLED,
                            &disable_window_transitions,
                            sizeof(disable_window_transitions));

        ::SetWindowSubclass(_windowHandle, NativeViewSubclassProc, 69420,
                            NULL); // what does this do?

        auto style = ::GetWindowLongPtr(_windowHandle, GWL_STYLE);
        style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX |
                    WS_EX_APPWINDOW);
        ::SetWindowLongPtr(_windowHandle, GWL_STYLE, style);

        RECT flutterWindowRect;
        ::GetClientRect(_flutterRootWindow, &flutterWindowRect);

        ::SetWindowLongPtr(_windowHandle, GWLP_USERDATA,
                            reinterpret_cast<LONG>(_flutterRootWindow));

        ::SetWindowPos(_windowHandle, _flutterRootWindow, flutterWindowRect.left,
                        flutterWindowRect.top, initialWidth, initialHeight, SWP_SHOWWINDOW);
        //  flutterWindowRect.right - flutterWindowRect.left,
        //  flutterWindowRect.bottom - flutterWindowRect.top, SWP_SHOWWINDOW);
        ::ShowWindow(_windowHandle, SW_SHOW);
        ::ShowWindow(_flutterRootWindow, SW_SHOW);
        ::SetFocus(_flutterRootWindow);
        }
    }

    BackingWindow::GetHandle() { 
      return _windowHandle;
    }

}
