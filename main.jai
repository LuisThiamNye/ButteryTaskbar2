#load "config.jai";
#load "shared.jai";
#load "windows-extra.jai";
#load "winhttp.jai";

Basic :: #import "Basic"()(MEMORY_DEBUGGER = !RELEASE_MODE, ENABLE_ASSERT=!RELEASE_MODE, TEMP_ALLOCATOR_POISON_FREED_MEMORY=!RELEASE_MODE);
#if RELEASE_MODE { // :nullify_print_and_log_statements
	using,except(log, log_error, print) Basic;
	log :: (_: ..Any, flags: Log_Flags = 0) #expand {}
	log_error :: (_: ..Any) #expand {}
	print :: (_: ..Any) #expand {}
} else {
	using Basic;
}
#import "Windows";
#import "Windows_Utf8";
#import "Windows_Registry";
#import "System";
#import "File";
#import "Thread";
#import "Atomics";
#import "Math";
#import "String";
Input :: #import "Input";
Simp :: #import "Simp";
GetRect :: #import "GetRect";

is_finalising:= false;
taskbar_hwnds: [..]HWND;
core_windows: [..]HWND;
should_show_taskbar_due_to_focus:= true;
should_stay_visible_before: s64; // measured in milliseconds
is_win_key_down: bool;
win_key_press_requested:= false;
taskbar_thread: Thread;
taskbar_thread_sema: Semaphore;
stop_polling: bool;
keyboard_hook: HHOOK;
mouse_hook: HHOOK;
primary_monitor: HMONITOR;
primary_monitor_rect: RECT;
main_hwnd: HWND;
is_menu_active: bool;
exe_path: string;
registry_value_exe_path: string;
update_check_thread: Thread;
update_check_thread_initialised:= false;
is_up_to_date:= true;
newer_version_buffer: [128]u8; // The idea of this statically allocated buffer is to avoid memory access violations due to multithreading and freeing string pointers.
newer_version: string;


main :: () {
	SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2); // TODO Use manifest instead.

	log("Initialising %", app_name);
	exe_path = get_path_of_running_executable();
	registry_value_exe_path = join("\"", replace(exe_path, "/", "\\"), "\"");

	refresh_monitor_rect();

	init(*taskbar_thread_sema, 0);
	signal(*taskbar_thread_sema); // Force the correct taskbar state at program launch

	load_config();

	thread_init(*taskbar_thread, taskbar_thread_proc);
	thread_start(*taskbar_thread);

	// Could instead use Raw Input, maybe. Docs advise that Raw Input is generally better, with a difference being that it does not receive synthetic keystrokes.
	// Also seems like Raw Input requires continuous polling, while presumably with the hooks the threads can sleep while there is no input.
	// -- UPDATE: I think this is false. Use WM_INPUT and there's a flag to receive system-wide events even when the window is not focused.
	//
	// For global shortcuts, could use RegisterHotKey which I think would mean the unprivileged program can still get the event when a privileged app is activated.
	//
	// TODO have a dedicated thread for the hooks, as recommended by the Docs. Hooks should return quickly.
	// This could allow the hooks to be active at the same time as the menu UI.
	set_windows_hooks_appropriately();
	defer UnhookWindowsHookEx(keyboard_hook);
	defer UnhookWindowsHookEx(mouse_hook);

	if !setup_hidden_window() terminate_program();

	while main_loop:= 1 {
		msg: MSG;
		while GetMessageW(*msg, null, 0, 0) {
			TranslateMessage(*msg);
			DispatchMessageW(*msg);
			if is_finalising break main_loop;
			if is_menu_active break;
		}
		menu_loop();
		if is_finalising break;
	}
	log("Done.");
}

terminate_program :: () {
	is_finalising = true;
	close_menu();
	UnhookWindowsHookEx(keyboard_hook);
	UnhookWindowsHookEx(mouse_hook);
	should_show_taskbar_due_to_focus = true;
	set_taskbar_visibility();
	PostQuitMessage(0);
	log("Waiting for taskbar thread to shut down...");
	thread_is_done(*taskbar_thread, -1);
	log("Terminating.");
	exit(0);
}

perf_ticks_per_millisecond: s64;

current_millis :: () -> s64 {
	if !perf_ticks_per_millisecond {
		perf_ticks_per_second: s64;
		QueryPerformanceFrequency(*perf_ticks_per_second);
		perf_ticks_per_millisecond = perf_ticks_per_second/1000;
	}

	perf_ticks: s64;
	QueryPerformanceCounter(*perf_ticks);
	return perf_ticks / perf_ticks_per_millisecond;
}

refresh_monitor_rect :: () {
	primary_monitor = MonitorFromPoint(.{0,0}, MONITOR_DEFAULTTOPRIMARY);
	info: MONITORINFO;
	info.cbSize = size_of(MONITORINFO);
	GetMonitorInfoW(primary_monitor, *info);
	primary_monitor_rect = info.rcWork;
}

WM_SHELLHOOKMESSAGE: u32;
taskbar_restart_window_message: u32;

setup_hidden_window :: () -> bool {
	WM_SHELLHOOKMESSAGE = RegisterWindowMessageW(utf8_to_wide("SHELLHOOK"));
	taskbar_restart_window_message = RegisterWindowMessageW(utf8_to_wide("TaskbarCreated"));

	wc: WNDCLASSEXW;
	wc.cbSize = size_of(WNDCLASSEXW);
	wc.style = CS_NOCLOSE;
	wc.lpfnWndProc = xx handle_window_message;
	wc.hInstance = GetModuleHandleW(null);
	wc.hCursor = LoadCursorW(null, IDC_ARROW);
	class_name:= utf8_to_wide("BUTTERY_TASKBAR");
	wc.lpszClassName = class_name;

	if 0 == RegisterClassExW(*wc) {
		log_error("failed to register window class");
		return false;
	}

	main_hwnd = CreateWindowExW(
		0,
		class_name,
		utf8_to_wide(app_name),
		0,
		0, 0, 0, 0,
		null, null,
		GetModuleHandleW(null),
		null);

	lib:= LoadLibraryW(utf8_to_wide("User32.dll"));
	if lib==null {
		log_error("Failed to load User32.dll");
		return false;
	}
	RegisterShellHookWindow:= cast((HWND) -> BOOL #c_call) GetProcAddress(lib, "RegisterShellHookWindow");
	if RegisterShellHookWindow == null {
		log_error("Failed to load RegisterShellHookWindow");
		return false;
	}
	if !RegisterShellHookWindow(main_hwnd) {
		log_error("Failed to register window for shell events");
		return false;
	}
	return true;
}

notify_icon_data: NOTIFYICONDATAW;

handle_window_message_context: Context;
handle_window_message :: (hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT #c_call {
	handle_window_message_context.stack_trace = null;
	push_context,defer_pop handle_window_message_context;

	icon_callback_msg: u32 : WM_APP + 1;

	add_notification_icon :: no_inline (hwnd: HWND) {
		notify_icon_data.cbSize = size_of(NOTIFYICONDATAW);
		notify_icon_data.hWnd = hwnd;
		notify_icon_data.uID = 1;
		notify_icon_data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
		notify_icon_data.uCallbackMessage = icon_callback_msg;
		#if USE_DEFAULT_ICON {
			notify_icon_data.hIcon = LoadImageW(null, IDI_APPLICATION, IMAGE_ICON, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
		} else {
			notify_icon_data.hIcon = LoadImageW(GetModuleHandleW(null), xx ICON_RESOURCE_ID, IMAGE_ICON, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
		}
		memcpy(*notify_icon_data.szTip, utf8_to_wide(app_name), app_name.count*2);
		NOTIFYICON_VERSION_4: u32 : 4;
		notify_icon_data.uVersion = NOTIFYICON_VERSION_4;

		Shell_NotifyIconW(NIM_ADD, *notify_icon_data);
		Shell_NotifyIconW(NIM_SETVERSION, *notify_icon_data);
	}

	if msg == {
		case WM_CREATE;
			add_notification_icon(hwnd);

		case icon_callback_msg;
			// NIN_POPUPOPEN: u32 : WM_USER + 6;
			// NIN_POPUPCLOSE: u32 : WM_USER + 7;
			NINF_KEY: u32 : 1;
			NIN_KEYSELECT: u32 : NIN_SELECT | NINF_KEY;
			if lparam & 0xffff == {
				case NIN_SELECT; #through; // primary action
				case NIN_KEYSELECT; #through; // primary action
				case WM_CONTEXTMENU; // right click
					x_anchor:= cast(s32) wparam & 0xffff;
					y_anchor:= cast(s32) (wparam >> 16);
					open_menu_window(x_anchor, y_anchor);
			}

		case WM_DESTROY;
			log("WM_DESTROY");
			Shell_NotifyIconW(NIM_DELETE, *notify_icon_data);
			terminate_program();
			return 0;

		case;
			// We listen for window activation for two purposes:
			// 1. Set the taskbar state.
			// 2. Hide the menu popup.
			if msg == WM_SHELLHOOKMESSAGE {
				get_window_class_name :: (hwnd: HWND, allocator:= temp) -> string {
					class_name:= NewArray(48, u16).data;
					GetClassNameW(hwnd, class_name, 47);
					return wide_to_utf8(class_name, -1, allocator);
				}

				if wparam == {
					// case HSHELL_FLASH; // The orange taskbar icon flash
					// I have not checked whether the flash causes the taskbar to become visible again.
					// Maybe it is better to let the taskbar show (notifying the user of the alert), assuming it is easier enough to hide it again by window activation?

					case HSHELL_WINDOWACTIVATED; {
						log("HSHELL_WINDOWACTIVATED");
						if is_menu_active close_menu();
						if config__enabled {
							refresh_taskbar_state();
							set_taskbar_visibility();
						}
					}
					case HSHELL_RUDEAPPACTIVATED; {
						if config__enabled | is_menu_active {
							if !is_menu_active reset_temporary_storage(); // temporary storage gets reset in the UI loop.

							// Note: we are not able to detect alt-tab by this method of activation detection

							activated_window:= cast(HWND) lparam;
							if activated_window == null {
								if config__enabled {
									activated_window = GetForegroundWindow();
									// class TopLevelWindowForOverflowXamlIsland is used for the tray overflow menu
									// class XamlExplorerHostIslandWindow is used for task view
									class_name_str:= get_window_class_name(activated_window);
									log("Activated (null): %", class_name_str);
									if class_name_str == "Shell_TrayWnd"
									|| class_name_str == "TopLevelWindowForOverflowXamlIsland"
									|| class_name_str == "XamlExplorerHostIslandWindow"
									|| class_name_str == "Shell_SecondaryTrayWnd" {
										should_show_taskbar_due_to_focus = true;
									} else {
										should_show_taskbar_due_to_focus = false;
									}
								}
							} else {
								// start menu corresponds to window class of Windows.UI.Core.CoreWindow, but is also used for things like notification and action centre
								// Could be more reliably identified as the exe is SearchHost.exe
								class_name_str:= get_window_class_name(activated_window);
								log("Activated: %", class_name_str);
								if is_menu_active && class_name_str != menu_class_name  close_menu();
								if config__enabled {
									if class_name_str == "Windows.UI.Core.CoreWindow" {
										found:= array_find(core_windows, activated_window);
										if !found array_add(*core_windows, activated_window);
									}
									refresh_taskbar_state();
								}
							}
							if config__enabled set_taskbar_visibility();
						}
					}
				}
			} else if msg == taskbar_restart_window_message {
				add_notification_icon(hwnd);
			}
	}

	return DefWindowProcW(hwnd, msg, wparam, lparam);
}


// Taskbar stuff

refresh_taskbars :: () {
	h_primary_taskbar:= FindWindowW(utf8_to_wide("Shell_TrayWnd"), null);
	array_reset(*taskbar_hwnds);
	array_add(*taskbar_hwnds, h_primary_taskbar);
	hwnd: HWND = null;
	while 1 {
		hwnd = FindWindowExW(null, hwnd, utf8_to_wide("Shell_SecondaryTrayWnd"), null);
		if hwnd == null break;
		array_add(*taskbar_hwnds, hwnd);
	}
}

set_taskbar_visibility :: inline () {
	atomic_write(*stop_polling, true);
	signal(*taskbar_thread_sema);
}

// Note: because this is a different thread, we should be careful not to touch any of the hook stuff here.
taskbar_thread_proc :: (thread: *Thread) -> s64 {
	while 1 {
		wait_for(*taskbar_thread_sema);
		is_final_cycle:= is_finalising;
		log("Woke up taskbar thread.");

		refresh_taskbars();
		refresh_monitor_rect();

		if win_key_press_requested {
			ip: INPUT;
			ip.type = .KEYBOARD;
			ip.ki.wVk = VK_LWIN;
			SendInput(1, *ip, size_of(INPUT));
			ip.ki.dwFlags = KEYEVENTF_KEYUP;
			SendInput(1, *ip, size_of(INPUT));

			win_key_press_requested = false;
		}
			
		if taskbar_hwnds {
			abd: APPBARDATA;
			abd.cbSize = size_of(APPBARDATA);
			abd.hWnd = taskbar_hwnds[0];
			abd.lParam = ifx (config__enabled && !is_finalising) || config__autohide_when_disabled ABS_AUTOHIDE else 0;
			SHAppBarMessage(ABM_SETSTATE, *abd);
		}

		atomic_write(*stop_polling, false);
		n_attempts:= 0;
		while n_attempts<60 && !stop_polling {
			defer n_attempts += 1;
			failed:= false;
			should_show_taskbar:= should_show_taskbar_due_to_focus || is_win_key_down || current_millis() < should_stay_visible_before;
			for hwnd, hwnd_index: taskbar_hwnds {
				previously_shown:= cast(bool) ShowWindow(hwnd, cast(s32) ifx should_show_taskbar SW_SHOWNOACTIVATE else SW_HIDE);
				actually_shown:= cast(bool) IsWindowVisible(hwnd);
				if previously_shown != should_show_taskbar {
					log("Set taskbar % visibility: % -> % (actual: %; win: %; state: %; n: %)",
						hwnd_index, previously_shown, should_show_taskbar,
						actually_shown, is_win_key_down, should_show_taskbar_due_to_focus, n_attempts);
				}
				failed = should_show_taskbar != actually_shown;
			}
			if current_millis() < should_stay_visible_before {
				// keep polling until the time is up
				n_attempts = 0;
				sleep_milliseconds(100);
			} else if failed {
				// This rarely happens
				sleep_milliseconds(10);
				log("Retry!");
			} else if should_show_taskbar {
				break; // making and keeping the taskbar visible usually isn't a problem
			} else {
				// Just to be extra sure, keep setting the taskbar to hidden for a while
				sleep_milliseconds(50);
				n_attempts += 8;
			}
		}

		if is_final_cycle break;
	}
	log("Taskbar thread is shutting down.");
	return 0;
}

refresh_taskbar_state :: () {
	should_show_taskbar:= false;
	active_hwnd:= GetForegroundWindow();
	for hwnd: core_windows {
		// Window info (rect, style etc) does not allow distinguishing between open and closed start menu.
		// IsWindowVisible always returns true.
		// But we can check for whether the window is active
		should_show_taskbar = (hwnd == active_hwnd);
		if should_show_taskbar break;
	}
	should_show_taskbar_due_to_focus = should_show_taskbar;
}


set_windows_hooks_appropriately :: () {
	// When the UI is active, we suspend the hooks because when the UI thread sleeps
	// (e.g. between frames or at a breakpoint) the keyboard/mouse input becomes much less responsive.
	should_hook_mouse:= config__enabled && config__scroll_activation_enabled && !is_menu_active;
	should_hook_keyboard:= (config__enabled || config__toggle_shortcut_enabled) && !is_menu_active;
	
	if (keyboard_hook != null) != should_hook_keyboard {
		if should_hook_keyboard {
			log("Installed keyboard hook.");
			keyboard_hook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboard_hook_proc, null, 0);
		} else {
			log("Uninstalled keyboard hook.");
			UnhookWindowsHookEx(keyboard_hook);
			keyboard_hook = null;
		}
	}
	if (mouse_hook != null) != should_hook_mouse {
		if should_hook_mouse {
			log("Installed mouse hook.");
			mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, mouse_hook_proc, null, 0);
		} else {
			log("Uninstalled mouse hook.");
			UnhookWindowsHookEx(mouse_hook);
			mouse_hook = null;
		}
	}
}

//
// Key listener
//

keyboard_hook_proc_context: Context;
keyboard_hook_proc :: (ncode: s32, wparam: WPARAM, lparam: LPARAM) -> LRESULT #c_call {
	keyboard_hook_proc_context.stack_trace = null;
	push_context,defer_pop keyboard_hook_proc_context;

	info:= cast(*KBDLLHOOKSTRUCT) lparam;

	if ncode == 0 {
		vk:= info.vkCode;
		// We organise this to minimise the computation per message. Only when we find the rarer trigger
		// keys do we go out to collect further information like modifiers.
		if wparam == {
			case WM_KEYDOWN;
				if inline handle_key_down(vk) return 1;
			case WM_KEYUP;
				if (vk == VK_LWIN || vk == VK_RWIN) && config__enabled {
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

handle_key_down :: (vk: u32) -> handled:= false {
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

	if vk == {
		case VK_LWIN; #through;
		case VK_RWIN;
			if config__enabled && !is_win_key_down {
				is_win_key_down = true;
				set_taskbar_visibility();
			}

		case VK_F11;
			mods:= get_mods();
			if mods == {
				// Note: If winkey is the only modifier, mouse button keybinding ends up opening the start menu (winkey press leaks through)
				case .win | .control; // enable / disable
					if config__toggle_shortcut_enabled {
						set_config__enabled(!config__enabled);
						save_config();
						return true;
					}

				case .win | .shift;
					#if !RELEASE_MODE {
						log("Exit by shortcut");
						terminate_program();
						return true;
					}
			}
	}
	return;
}


// Mouse scroll listener
// The hook for this should only be active when config__scroll_activation_enabled

mouse_hook_proc_context: Context;
mouse_hook_proc :: (ncode: s32, wparam: WPARAM, lparam: LPARAM) -> LRESULT #c_call {
	mouse_hook_proc_context.stack_trace = null;
	push_context,defer_pop mouse_hook_proc_context;

	if ncode == 0 && wparam == WM_MOUSEWHEEL {
		info:= cast(*MSLLHOOKSTRUCT) lparam;
		delta:= info.mouseData >> 16;
		if delta != 0 {
			if inline handle_mouse_scroll(delta, info.pt.x, info.pt.y) return 1;
		}
	}
	return CallNextHookEx(keyboard_hook, ncode, wparam, lparam);
}

is_showing_window_due_to_scroll_action:= false;

handle_mouse_scroll :: (delta: int, mouse_x: int, mouse_y: int) -> handled:= false {
	// When the cursor is at the bottom edge of the primary monitor
	if mouse_y == primary_monitor_rect.bottom-1
	&& primary_monitor_rect.left <= mouse_x && mouse_x < primary_monitor_rect.right
	&& !should_show_taskbar_due_to_focus {

		// It has been found that with a very high scroll rate (rapid fire of these scroll events)
		// that Windows starts beeping and input becomes less responsive.
		// This seems to happen because we get a scroll event happening whilst the hook is still
		// waiting on its stuff to complete.
		// It does not help to immediately unhook the mouse hook proc, so the proc must complete fast.
		// This minimal implementation is better than it was before, but with an absurd scroll rate
		// (e.g. with Logitech hyper scroll thing) you will still get beeping. In fact, I have observed
		// beeping this way just by scrolling very quickly over the sidebar in Sublime Text, not
		// at the bottom of the screen.

		log("Focusing taskbar due to scroll action");

		should_show_taskbar_due_to_focus = true;
		win_key_press_requested = true; // Open Start Menu to workaround sublime's broken maximised/fullscreen state.
		set_taskbar_visibility();

		return true;
	}
	return;
}


start_check_for_updates :: () {
	if !update_check_thread_initialised {
		update_check_thread_initialised = true;
		thread_init(*update_check_thread, update_check_thread_proc);
	} else {
		if !thread_is_done(*update_check_thread) return;
		thread_deinit(*update_check_thread);
		thread_init(*update_check_thread, update_check_thread_proc);
	}
	thread_start(*update_check_thread);
}

update_check_thread_proc :: (thread: *Thread) -> s64 {
	fetch_update_status();
	reset_temporary_storage();
	return 0;
}

fetch_update_status :: () {
	host_name:= "api.github.com";
	path:= app_latest_release_api_path;
	log("Checking version at: %0%", host_name, path);

	user_agent:: #run join("Buttery Taskbar ", app_version);
	session:= WinHttpOpen(utf8_to_wide(user_agent), WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, null, null, 0);
	if !session {
		log_error("Failed to initialise WinHTTP.");
		return;
	}
	defer WinHttpCloseHandle(session);

	connection:= WinHttpConnect(session, utf8_to_wide(host_name), 443, 0);
	if !connection {
		log_error("Failed to connect.");
		return;
	}
  defer WinHttpCloseHandle(connection);

  request:= WinHttpOpenRequest(connection, utf8_to_wide("GET"), utf8_to_wide(path), null, null, null, WINHTTP_FLAG_SECURE);
  if !request {
  	log_error("Failed to make request.");
  	return;
  }
  defer WinHttpCloseHandle(request);

  if !WinHttpSendRequest(request, null, 0, null, 0, 0, 0) {
  	log_error("Failed to send HTTP request.");
  	return;
  }

  if !WinHttpReceiveResponse(request, null) {
  	log_error("Failed to receive response.");
  	return;
  }

  sb: String_Builder;
  while 1 {
  	buf_size:: 1024;
  	ensure_contiguous_space(*sb, buf_size);
  	buffer:= get_current_buffer(*sb);
  	n_bytes_read: DWORD;
  	if !WinHttpReadData(request, get_buffer_data(buffer)+buffer.count, buf_size, *n_bytes_read) {
  		log_error("Failed to read.");
  		free_buffers(*sb);
  		return;
  	}
  	if n_bytes_read == 0 break;
  	buffer.count += n_bytes_read;
  }
  response:= builder_to_string(*sb, allocator=temp);

  found_tag:= false;
  while breakable:= 1 {
  	key_pattern:= "\"tag_name\":";
	  idx:= find_index_from_left(response, key_pattern);
	  if idx < 0 break;
	  advance(*response, idx + key_pattern.count);
	  idx = find_index_from_left(response, #char "\"");
	  if idx < 0 break;
	  advance(*response, idx + 1);
	  idx = find_index_from_left(response, #char "\"");
	  if idx < 0 break;
	  response = slice(response, 0, idx);
	  found_tag = true;
	  break;
  }
  if !found_tag {
  	log_error("Could not find release tag in the response.");
  	return;
  }
  if response.count > newer_version_buffer.count {
  	log_error("The tag we got is too big.");
  	return;
  }
  is_up_to_date = (response == app_version);
  if !is_up_to_date {
  	memcpy(*newer_version_buffer[0], response.data, response.count);
  	newer_version.data = *newer_version_buffer[0];
  	newer_version.count = response.count;
  }

  log("Determined up-to-date status: %", is_up_to_date);
}