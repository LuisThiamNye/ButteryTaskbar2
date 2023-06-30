package buttery_taskbar

// TODO listen to taskbar window event by window subclassing

// Note: the popup menu given by CreatePopupMenu is rubbish. Do not use it. If the start menu is open, it appears beneath the taskbar and does not go away when you click somewhere else. I observed PowerToys and simplewall also using this, with the same issues.

import "core:fmt"
import "core:mem"
import "core:runtime"
import win "core:sys/windows"

WM_SHELLHOOKMESSAGE: u32

setup_window :: proc(state: ^State) {
	using win

	SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

	WM_SHELLHOOKMESSAGE = win.RegisterWindowMessageW(utf8_to_wstring("SHELLHOOK"))

	wc: WNDCLASSEXW
	hInstance := GetModuleHandleW(nil)
	wc.cbSize = size_of(wc)
	wc.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW
	wc.lpfnWndProc = handle_window_message
	wc.hInstance = HINSTANCE(hInstance)
	wc.hCursor = LoadCursorW(nil, auto_cast _IDC_ARROW)
	class_name := utf8_to_wstring("BUTTERY_TASKBAR")
	wc.lpszClassName = class_name

	if 0 == RegisterClassExW(&wc) {
		panic("failed to register window class")
	}

	hwnd := create_window(state, class_name, 300, 400)

	lib := LoadLibraryW(win.utf8_to_wstring("User32.dll"))
	if lib==nil {panic("failed to load User32.dll")}
	RegisterShellHookWindow := cast(proc(win.HWND) -> b32) GetProcAddress(lib, "RegisterShellHookWindow")
	if RegisterShellHookWindow == nil {
		msg := "failed to load RegisterShellHookWindow"
		log(msg)
		panic(msg)
	}
	if !RegisterShellHookWindow(hwnd) {
		log("Failed to register window for shell events")
		return
	}
}


do_message_loop :: proc() {
	using win
	msg: MSG
	for ;GetMessageW(&msg, nil, 0, 0); {
		if msg.message == WM_CLOSE {
			return
		}

		TranslateMessage(&msg)
		DispatchMessageW(&msg)
	}
}

create_window :: proc(state: ^State, class_name: win.wstring, w0, h0: int) -> win.HWND {
	using win
	window_name := utf8_to_wstring(app_name)
	x : i32 = 0
	y : i32 = 0
	w : i32 = i32(w0)
	h : i32 = i32(h0)
	hwnd := CreateWindowExW(
		0,
		class_name,
		window_name,
		WS_OVERLAPPEDWINDOW | WS_CAPTION | WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
		x, y, w, h,
		nil, nil,
		auto_cast GetModuleHandleW(nil),
		nil)

	if is_system_app_dark_mode_enabled() {
		set_window_frame_dark_mode(hwnd, true)
	}

	if hwnd==nil {return nil}

	SetWindowLongPtrW(hwnd, GWLP_USERDATA, int(uintptr(state)))
	return hwnd
}

// Dark mode stuff; see https://github.com/microsoft/WindowsAppSDK/issues/41

set_window_frame_dark_mode :: proc(hwnd: win.HWND, dark: bool) {
	using win
	dark_mode := b32(dark)
	DwmSetWindowAttribute(hwnd, u32(DWMWINDOWATTRIBUTE.DWMWA_USE_IMMERSIVE_DARK_MODE), &dark_mode, size_of(dark_mode))
}

is_system_app_dark_mode_enabled :: proc() -> bool {
	using win
	// Dynamically link because this API is undocumented
  hUxTheme := LoadLibraryW(utf8_to_wstring("uxtheme.dll"))
  if hUxTheme == nil {
      log("error: uxtheme.dll not found.")
      return false
  }
  defer FreeLibrary(hUxTheme)
  MAKEINTRESOURCEA :: #force_inline proc "contextless" (#any_int i: int) -> win.LPSTR {
		return cast(LPSTR)uintptr(WORD(i))
	}
  prc := (proc "stdcall" () -> bool)(GetProcAddress(hUxTheme, cstring(MAKEINTRESOURCEA(132))))
  if prc == nil {
      log("error: ShouldAppsUseDarkMode not found.")
      return false;
  }

  dark_mode_override := true
  return dark_mode_override || prc()
}

notify_icon_data: win.NOTIFYICONDATAW

handle_window_message :: proc "stdcall" (hwnd: win.HWND, msg: win.UINT,
	wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	context = runtime.default_context()
	using win

	state := cast(^State) uintptr(GetWindowLongPtrW(hwnd, GWLP_USERDATA))

	icon_callback_msg : u32 : win.WM_APP + 1

	switch msg {
	case WM_CREATE:
		notify_icon_data.cbSize = size_of(notify_icon_data)
		notify_icon_data.hWnd = hwnd
		notify_icon_data.uID = 1
		notify_icon_data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP
		notify_icon_data.uCallbackMessage = icon_callback_msg
		notify_icon_data.hIcon = LoadIconW(nil, MAKEINTRESOURCEW(uintptr(rawptr(IDI_APPLICATION))))
		tip_str := "Buttery Taskbar"
		mem.copy(&notify_icon_data.szTip, utf8_to_wstring(tip_str), len(tip_str)*2)
		NOTIFYICON_VERSION_4 : u32 : 4
		notify_icon_data.uVersion = NOTIFYICON_VERSION_4

		Shell_NotifyIconW(NIM_ADD, &notify_icon_data)
		Shell_NotifyIconW(NIM_SETVERSION, &notify_icon_data)

	case icon_callback_msg:
		// NIN_POPUPOPEN : u32 : WM_USER + 6
		// NIN_POPUPCLOSE : u32 : WM_USER + 7
		NINF_KEY : u32 : 1
		NIN_KEYSELECT : u32 : win.NIN_SELECT | NINF_KEY
		switch u32(LOWORD(u32(lparam))) {
		case WM_CONTEXTMENU, NIN_SELECT, NIN_KEYSELECT:
			// x_anchor := GET_X_LPARAM(int(wparam))
			// y_anchor := GET_Y_LPARAM(int(wparam))
			// prepare_window_pos(hwnd, x_anchor, y_anchor)
			// ShowWindow(hwnd, SW_RESTORE)
			// SetForegroundWindow(hwnd)

			log("Exit by tray icon")
	    PostQuitMessage(0)
	    cleanup_program(state)
		}

	case WM_DESTROY:
		log("WM_DESTROY")
		Shell_NotifyIconW(NIM_DELETE, &notify_icon_data)
    PostQuitMessage(0)
    cleanup_program(state)
		return 0

	case:
		if msg == WM_SHELLHOOKMESSAGE && state.is_enabled {
			switch wparam {
			// case HSHELL_FLASH: // The orange taskbar icon flash

			case HSHELL_WINDOWACTIVATED:
				log("HSHELL_WINDOWACTIVATED")
				refresh_taskbar_state(state)
				set_taskbar_visibility(state)

			case HSHELL_RUDEAPPACTIVATED:
				mem.free_all(context.temp_allocator)

				// Note: we are not able to detect alt-tab by this method of activation detection

				activated_window := win.HWND(uintptr(lparam))
				if activated_window == nil {
					activated_window = GetForegroundWindow()
					// class TopLevelWindowForOverflowXamlIsland is used for the tray overflow menu
					// class XamlExplorerHostIslandWindow is used for task view
					class_name_str, _ := get_window_class_name(activated_window)
					log("Activated (nil):", class_name_str)
					if (
						class_name_str == "Shell_TrayWnd" ||
						class_name_str == "TopLevelWindowForOverflowXamlIsland" ||
						class_name_str == "XamlExplorerHostIslandWindow" ||
						class_name_str == "Shell_SecondaryTrayWnd") {
						state.should_show_taskbar = true
					} else {
						state.should_show_taskbar = false
					}
				} else {
					// start menu corresponds to window class of Windows.UI.Core.CoreWindow, but is also used for things like notification and action centre
					// Could be more reliably identified as the exe is SearchHost.exe
					class_name_str, _ := get_window_class_name(activated_window)
					log("Activated:", class_name_str)
					if class_name_str == "Windows.UI.Core.CoreWindow" {
						state.core_windows[activated_window] = nil
					}
					refresh_taskbar_state(state)
				}
				set_taskbar_visibility(state)
			}

			get_window_class_name :: proc(hwnd: win.HWND, allocator := context.temp_allocator) -> (string, mem.Allocator_Error) {
				class_name := make(wstring, 48)
				GetClassNameW(hwnd, class_name, 47)
				return wstring_to_utf8(class_name, -1, allocator)
			}
		}
	}

	return DefWindowProcW(hwnd, msg, wparam, lparam)
}

prepare_window_pos :: proc(hwnd: win.HWND, x: i32, y: i32) {
	using win

}