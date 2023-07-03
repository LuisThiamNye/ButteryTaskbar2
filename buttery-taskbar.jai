#load "windows-extra.jai";

#import "Basic"()(ENABLE_ASSERT=!RELEASE_MODE);
#import "Windows";
#import "Windows_Utf8";
#import "Thread";
#import "Atomics";

app_name :: "Buttery Taskbar";

is_enabled: = true;
taskbar_hwnds: [..]HWND;
core_windows: [..]HWND;
should_show_taskbar_due_to_focus: = false;
should_stay_visible_before: s64; // measured in milliseconds
is_win_key_down: bool;
taskbar_thread: Thread;
taskbar_thread_sema: Semaphore;
stop_polling: bool;
keyboard_hook: HHOOK;
mouse_hook: HHOOK;
primary_monitor: HMONITOR;
primary_monitor_rect: RECT;
main_hwnd: HWND;


main :: () {
	SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

	log("Initialising %\n", app_name);

	refresh_monitor_rect();

	init(*taskbar_thread_sema, 0);
	signal(*taskbar_thread_sema); // Force the correct taskbar state at program launch

	thread_init(*taskbar_thread, taskbar_thread_proc);
	thread_start(*taskbar_thread);

	keyboard_hook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboard_hook_proc, null, 0);
	defer UnhookWindowsHookEx(keyboard_hook);

	mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, mouse_hook_proc, null, 0);
	defer UnhookWindowsHookEx(mouse_hook);

	setup_window();

	msg: MSG;
	while GetMessageW(*msg, null, 0, 0) {
		if msg.message == WM_CLOSE {
			return;
		}

		TranslateMessage(*msg);
		DispatchMessageW(*msg);
	}
}

// Called immediately before exit
finalise_program :: () {
	UnhookWindowsHookEx(keyboard_hook);
	should_show_taskbar_due_to_focus = true;
	set_taskbar_visibility();
}

exit_program :: () {
	finalise_program();
	exit(0);
}

panic :: (fmt: string, args: ..Any) {
	print(fmt, ..args);
	Debug :: #import "Debug";
	Debug.abort(1);
}

current_millis :: () -> s64 {
	return to_milliseconds(current_time_monotonic());
}

refresh_monitor_rect :: () {
	primary_monitor = MonitorFromPoint(.{0,0}, MONITOR_DEFAULTTOPRIMARY);
	info: MONITORINFO;
	info.cbSize = size_of(MONITORINFO);
	GetMonitorInfoW(primary_monitor, *info);
	primary_monitor_rect = info.rcWork;
}

WM_SHELLHOOKMESSAGE: u32;

setup_window :: () {
	WM_SHELLHOOKMESSAGE = RegisterWindowMessageW(utf8_to_wide("SHELLHOOK"));

	wc: WNDCLASSEXW;
	wc.cbSize = size_of(WNDCLASSEXW);
	wc.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
	wc.lpfnWndProc = xx handle_window_message;
	wc.hInstance = GetModuleHandleW(null);
	wc.hCursor = LoadCursorW(null, IDC_ARROW);
	class_name: = utf8_to_wide("BUTTERY_TASKBAR");
	wc.lpszClassName = class_name;

	if 0 == RegisterClassExW(*wc) {
		panic("failed to register window class");
	}

	main_hwnd = create_window(class_name, 300, 400);

	lib: = LoadLibraryW(utf8_to_wide("User32.dll"));
	if lib==null panic("failed to load User32.dll");
	RegisterShellHookWindow: = cast((HWND) -> BOOL #c_call) GetProcAddress(lib, "RegisterShellHookWindow");
	if RegisterShellHookWindow == null {
		msg: = "failed to load RegisterShellHookWindow\n";
		log(msg);
		panic(msg);
	}
	if !RegisterShellHookWindow(main_hwnd) {
		log("Failed to register window for shell events\n");
		return;
	}
}

create_window :: (class_name: wstring, w0: s32, h0: s32) -> HWND {
	window_name: = utf8_to_wide(app_name);
	x: s32 = 0;
	y: s32 = 0;
	w: s32 = w0;
	h: s32 = h0;
	hwnd: = CreateWindowExW(
		0,
		class_name,
		window_name,
		WS_OVERLAPPEDWINDOW | WS_CAPTION | WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
		x, y, w, h,
		null, null,
		GetModuleHandleW(null),
		null);

	if is_system_app_dark_mode_enabled() {
		set_window_frame_dark_mode(hwnd, true);
	}

	return hwnd;
}

// Dark mode stuff. See https://github.com/microsoft/WindowsAppSDK/issues/41

set_window_frame_dark_mode :: (hwnd: HWND, dark: bool) {
	dark_mode: = cast(BOOL) dark;
	DwmSetWindowAttribute(hwnd, .DWMWA_USE_IMMERSIVE_DARK_MODE, *dark_mode, size_of(BOOL));
}

is_system_app_dark_mode_enabled :: () -> bool {
	// Dynamically link because this API is undocumented
  hUxTheme: = LoadLibraryW(utf8_to_wide("uxtheme.dll"));
  if hUxTheme == null {
      log("error: uxtheme.dll not found.\n");
      return false;
  }
  defer FreeLibrary(hUxTheme);
  prc: = cast(() -> bool #c_call) GetProcAddress(hUxTheme, MAKEINTRESOURCEA(132));
  if prc == null {
      log("error: ShouldAppsUseDarkMode not found.\n");
      return false;
  }

  dark_mode_override: = true; // @Temporary
  return dark_mode_override || prc();
}

notify_icon_data: NOTIFYICONDATAW;

handle_window_message :: (hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT #c_call {
	new_context: Context;
	push_context new_context {
		icon_callback_msg: u32 : WM_APP + 1;

		if msg == {
			case WM_CREATE;
				notify_icon_data.cbSize = size_of(NOTIFYICONDATAW);
				notify_icon_data.hWnd = hwnd;
				notify_icon_data.uID = 1;
				notify_icon_data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
				notify_icon_data.uCallbackMessage = icon_callback_msg;
				notify_icon_data.hIcon = LoadIconW(null, IDI_APPLICATION);
				memcpy(*notify_icon_data.szTip, utf8_to_wide(app_name), app_name.count*2);
				NOTIFYICON_VERSION_4: u32 : 4;
				notify_icon_data.uVersion = NOTIFYICON_VERSION_4;

				Shell_NotifyIconW(NIM_ADD, *notify_icon_data);
				Shell_NotifyIconW(NIM_SETVERSION, *notify_icon_data);

			case icon_callback_msg;
				// NIN_POPUPOPEN: u32 : WM_USER + 6;
				// NIN_POPUPCLOSE: u32 : WM_USER + 7;
				NINF_KEY: u32 : 1;
				NIN_KEYSELECT: u32 : NIN_SELECT | NINF_KEY;
				if lparam & 0xffff == {
					case NIN_SELECT; #through;
					case NIN_KEYSELECT; #through;
					case WM_CONTEXTMENU;
						// x_anchor: = GET_X_LPARAM(int(wparam));
						// y_anchor: = GET_Y_LPARAM(int(wparam));
						// prepare_window_pos(hwnd, x_anchor, y_anchor);
						// ShowWindow(hwnd, SW_RESTORE);
						// SetForegroundWindow(hwnd);

						log("Exit by tray icon\n");
				    PostQuitMessage(0);
				    finalise_program();
				}

			case WM_DESTROY;
				log("WM_DESTROY\n");
				Shell_NotifyIconW(NIM_DELETE, *notify_icon_data);
		    PostQuitMessage(0);
		    finalise_program();
				return 0;

			case;
				if msg == WM_SHELLHOOKMESSAGE && is_enabled {

					get_window_class_name :: (hwnd: HWND, allocator: = temp) -> string {
						class_name: = NewArray(48, u16).data;
						GetClassNameW(hwnd, class_name, 47);
						return wide_to_utf8(class_name, -1, allocator);
					}

					if wparam == {
						// case HSHELL_FLASH; // The orange taskbar icon flash

						case HSHELL_WINDOWACTIVATED;
							log("HSHELL_WINDOWACTIVATED\n");
							refresh_taskbar_state();
							set_taskbar_visibility();

						case HSHELL_RUDEAPPACTIVATED;
							reset_temporary_storage();

							// Note: we are not able to detect alt-tab by this method of activation detection

							activated_window: = cast(HWND) lparam;
							if activated_window == null {
								activated_window = GetForegroundWindow();
								// class TopLevelWindowForOverflowXamlIsland is used for the tray overflow menu
								// class XamlExplorerHostIslandWindow is used for task view
								class_name_str: = get_window_class_name(activated_window);
								log("Activated (null): %\n", class_name_str);
								if class_name_str == "Shell_TrayWnd"
								|| class_name_str == "TopLevelWindowForOverflowXamlIsland"
								|| class_name_str == "XamlExplorerHostIslandWindow"
								|| class_name_str == "Shell_SecondaryTrayWnd" {
									should_show_taskbar_due_to_focus = true;
								} else {
									should_show_taskbar_due_to_focus = false;
								}
							} else {
								// start menu corresponds to window class of Windows.UI.Core.CoreWindow, but is also used for things like notification and action centre
								// Could be more reliably identified as the exe is SearchHost.exe
								class_name_str: = get_window_class_name(activated_window);
								log("Activated: %\n", class_name_str);
								if class_name_str == "Windows.UI.Core.CoreWindow" {
									found: = array_find(core_windows, activated_window);
									if !found array_add(*core_windows, activated_window);
								}
								refresh_taskbar_state();
							}
							set_taskbar_visibility();
					}
				}
		}

		return DefWindowProcW(hwnd, msg, wparam, lparam);
	}
}


// Taskbar stuff

refresh_taskbars :: () {
	h_primary_taskbar: = FindWindowW(utf8_to_wide("Shell_TrayWnd"), null);
	array_reset(*taskbar_hwnds);
	array_add(*taskbar_hwnds, h_primary_taskbar);
	hwnd: HWND = null;
	while 1 {
		hwnd = FindWindowExW(null, hwnd, utf8_to_wide("Shell_SecondaryTrayWnd"), null);
		if hwnd == null break;
		array_add(*taskbar_hwnds, hwnd);
	}
}

set_taskbar_visibility :: () {
	atomic_write(*stop_polling, true);
	signal(*taskbar_thread_sema);
}

taskbar_thread_proc :: (thread: *Thread) -> s64 {
	while 1 {
		wait_for(*taskbar_thread_sema);
		log("Woke up taskbar thread.\n");

		refresh_taskbars();
		refresh_monitor_rect();

		atomic_write(*stop_polling, false);
		n_attempts: = 0;
		while n_attempts<60 && !stop_polling {
			defer n_attempts += 1;
			failed: = false;
			should_show_taskbar: = should_show_taskbar_due_to_focus || is_win_key_down || current_millis() < should_stay_visible_before;
			for hwnd, i: taskbar_hwnds {
				previously_shown: = ShowWindow(hwnd, cast(s32) ifx should_show_taskbar SW_SHOWNOACTIVATE else SW_HIDE);
				actually_shown: = cast(bool) IsWindowVisible(hwnd);
				log("Set taskbar % visibility: % -> % (actual: %; win: %; state: %; n: %)\n",
					i, previously_shown, should_show_taskbar,
					actually_shown, is_win_key_down, should_show_taskbar_due_to_focus, n_attempts);
				failed = should_show_taskbar != actually_shown;
			}
			if current_millis() < should_stay_visible_before {
				// keep polling until the time is up
				n_attempts = 0;
				sleep_milliseconds(100);
			} else if failed {
				// This rarely happens
				sleep_milliseconds(10);
				log("Retry!\n");
			} else if should_show_taskbar {
				break; // making and keeping the taskbar visible usually isn't a problem
			} else {
				// Just to be extra sure, keep setting the taskbar to hidden for a while
				sleep_milliseconds(50);
				n_attempts += 8;
			}
		}
	}
	return 0;
}

refresh_taskbar_state :: () {
	should_show_taskbar: = false;
	active_hwnd: = GetForegroundWindow();
	for hwnd: core_windows {
		// Window info (rect, style etc) does not allow distinguishing between open and closed start menu.
		// IsWindowVisible always returns true.
		// But we can check for whether the window is active
		should_show_taskbar = (hwnd == active_hwnd);
		if should_show_taskbar break;
	}
	should_show_taskbar_due_to_focus = should_show_taskbar;
}


//
// Key listener
//

keyboard_hook_proc :: (ncode: s32, wparam: WPARAM, lparam: LPARAM) -> LRESULT #c_call {
	new_context: Context;
	push_context new_context {
		Modifiers :: enum_flags {shift; control; win; alt;};
		get_mods :: () -> Modifiers {
			mods: Modifiers;
			if GetKeyState(VK_SHIFT)   & 0xf0 > 0  mods += .shift;
			if GetKeyState(VK_CONTROL) & 0xf0 > 0  mods += .control;
			if GetKeyState(VK_MENU)    & 0xf0 > 0  mods += .alt;
			if GetKeyState(VK_LWIN)    & 0xf0 > 0  mods += .win;
			if GetKeyState(VK_RWIN)    & 0xf0 > 0  mods += .win;
			return mods;
		}

		info: = cast(*KBDLLHOOKSTRUCT) lparam;

		if ncode == 0 {
			vk: = info.vkCode;
			// We organise this to minimise the computation per message. Only when we find the rarer trigger
			// keys do we go out to collect further information like modifiers.
			if wparam == {
				case WM_KEYDOWN;
					if vk == {
						case VK_LWIN; #through;
						case VK_RWIN;
							if is_enabled && !is_win_key_down {
								is_win_key_down = true;
								set_taskbar_visibility();
							}

						case VK_F11;
							mods: = get_mods();
							if mods == {
								// Note: If winkey is the only modifier, mouse button keybinding ends up opening the start menu (winkey press leaks through)
								case .win | .control; // enable / disable
									if is_enabled {
										is_enabled = false;
										should_show_taskbar_due_to_focus = true;
									} else {
										is_enabled = true;
										refresh_taskbar_state();
									}
									log("Set enabled state: %\n", is_enabled);
									set_taskbar_visibility();
									return 1;

								case .win | .shift;
									log("Exit by shortcut\n");
									exit_program();
									return 1;
							}
					}
				case WM_KEYUP;
					if (vk == VK_LWIN || vk == VK_RWIN) && is_enabled {
						// GetKeyState may report that the current vkey is still down, so only check the other key.
						is_win_key_down = GetKeyState(cast(s32) ifx vk==VK_LWIN VK_RWIN else VK_LWIN) & 0xf0 > 0;
						// We want the taskbar to stay visible for a short while after the windows key is lifted,
						// as start menu activation might come next and we do not want to hide the taskbar before then.
						should_stay_visible_before = current_millis() + 400;
						set_taskbar_visibility();
					}
			}
		}
		return CallNextHookEx(keyboard_hook, ncode, wparam, lparam);
	}
}



// Mouse scroll listener

mouse_hook_proc :: (ncode: s32, wparam: WPARAM, lparam: LPARAM) -> LRESULT #c_call {
	new_context: Context;
	push_context new_context {
		if ncode == 0 && wparam == WM_MOUSEWHEEL && is_enabled {
			info: = cast(*MSLLHOOKSTRUCT) lparam;
			delta: = info.mouseData >> 16;
			if delta != 0 {
				// When the cursor is at the bottom edge of the primary monitor
				if info.pt.y == primary_monitor_rect.bottom-1
				&& primary_monitor_rect.left <= info.pt.x && info.pt.x < primary_monitor_rect.right {
					log("Focusing taskbar due to scroll action\n");
					ShowWindow(taskbar_hwnds[0], SW_RESTORE);
					SetForegroundWindow(taskbar_hwnds[0]); // Note: conditions may not be satisfied to this to actually be effective; see docs.

					// Open Start Menu to workaround sublime's broken maximised/fullscreen state.
					// We do not send events if the Start menu is already open.
					if !should_show_taskbar_due_to_focus {
						should_show_taskbar_due_to_focus = true;
				    ip: INPUT;
					  ip.type = .KEYBOARD;
					  ip.ki.wVk = VK_LWIN;
					  SendInput(1, *ip, size_of(INPUT));
					  ip.ki.dwFlags = KEYEVENTF_KEYUP;
					  SendInput(1, *ip, size_of(INPUT));
					}

					return 1;
				}
			}
		}
		return CallNextHookEx(keyboard_hook, ncode, wparam, lparam);
	}
}
