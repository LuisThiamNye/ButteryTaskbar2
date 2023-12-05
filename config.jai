
config__enabled:= true;
config__scroll_activation_enabled:= true;
config__toggle_shortcut_enabled:= false;
config__auto_launch_enabled:= false;
config__autohide_when_disabled:= true;

set_config__enabled :: (v: bool) {
	config__enabled = v;
	if config__enabled {
		refresh_taskbar_state();
	} else {
		should_show_taskbar_due_to_focus = true;
	}
	log("Set enabled state: %", config__enabled);
	set_taskbar_visibility();
	set_windows_hooks_appropriately();
}

// The problem with the auto-launch entry in the registry is that the program will not run with elevated permissions,
// and thus the keyboard (and mouse?) hooks will not work when an elevated program is activated.
// TODO, low priority. If running as administrator, we could automatically create a Task Scheduler entry with 'highest privileges' option. This is what PowerToys does.
set_config__auto_launch_enabled :: (enabled: bool) {
	reg_key: HKEY;
	if RegOpenKeyExA(HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0, KEY_SET_VALUE, *reg_key) {
		config__auto_launch_enabled = false;
		log_error("Failed to open registry key.");
		return;
	}
	defer RegCloseKey(reg_key);

	if enabled {
		config__auto_launch_enabled = enabled;
		res:= RegSetValueExA(reg_key, reg_value_name, 0, REG_SZ, registry_value_exe_path.data, xx registry_value_exe_path.count);
		if res == {
		case 0;
			config__auto_launch_enabled = true;
		case;
			config__auto_launch_enabled = false;
			log_error("Failed to set the auto-launch registry entry. (Code: %)", res);
		}

	} else {
		res:= RegDeleteValueA(reg_key, reg_value_name);
		if res == {
		case 0; #through;
		case ERROR_FILE_NOT_FOUND;
			config__auto_launch_enabled = false;
		case;
			log_error("Failed to delete the auto-launch registry entry. (Code: %)", res);
		}
	}
}


window_width  : s32;
window_height : s32;
menu_hwnd: HWND;
current_time: float64;
last_time: float64;
is_ui_initialised: bool;

menu_loop :: () {
	while loop:= 1 {
		current_time = get_time();
		dt := cast(float)(current_time - last_time);
		Clamp(*dt, 0, 0.1);
		last_time = current_time;

		Input.update_window_events();

		for event: Input.events_this_frame {
			GetRect.getrect_handle_event(event);

			// Could also handle mouse events by capturing the mouse input, possibly.

			if event.type == {
				case .KEYBOARD;
					if event.key_pressed {
						if event.key_code == {
							case .ESCAPE;
								close_menu();
								break loop;
							case .META;
								handle_key_down(VK_LWIN);
								close_menu();
								break loop;
							case .F11;
								handle_key_down(VK_F11);
						}
					}
			}
		}

		draw_menu_frame(menu_hwnd);

		reset_temporary_storage();
		sleep_milliseconds(10);

		if !is_menu_active || is_finalising break;
	}
}

close_menu :: () {
	// Rather than destroying the window, just hide it. Creating a new window and using it with
	// Simp is not a fun time (I think because the GL context is initialised once only for the
	// first window). Also, Simp does not seem to do any garbage collection on its global window data.
	ShowWindow(menu_hwnd, SW_HIDE);
	is_menu_active = false;
	set_windows_hooks_appropriately();
}

menu_class_name :: "BUTTERY_TASKBAR_MENU";
reg_value_name :: app_name;

open_menu_window :: (x_anchor: s32, y_anchor: s32) {
	if is_menu_active return;
	is_menu_active = true;
	set_windows_hooks_appropriately();
	is_ui_initialised = false;
	start_check_for_updates();

	if !menu_hwnd {
		class_name:= utf8_to_wide(menu_class_name);
		wc: WNDCLASSEXW;
		wc.cbSize = size_of(WNDCLASSEXW);
		wc.style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW | CS_DROPSHADOW | CS_NOCLOSE;
		wc.lpfnWndProc = xx Input.MyWindowProc;
		wc.hInstance = GetModuleHandleW(null);
		wc.hCursor = LoadCursorW(null, IDC_ARROW);
		wc.lpszClassName = class_name;

		if 0 == RegisterClassExW(*wc) {
			log_error("Failed to register window class.");
			terminate_program();
		}

		window_name:= utf8_to_wide(app_name);
		menu_hwnd = CreateWindowExW(
			WS_EX_TOPMOST,
			class_name,
			window_name,
			WS_POPUP,
			0, 0, 0, 0,
			null, null,
			GetModuleHandleW(null),
			null);
	}

	is_dark_theme = is_system_app_dark_mode_enabled();
	set_window_frame_dark_mode(menu_hwnd, is_dark_theme);

	x, y := prepare_window_pos(x_anchor, y_anchor);
	MoveWindow(menu_hwnd, x, y, window_width, window_height, repaint=.FALSE);

	ShowWindow(menu_hwnd, SW_RESTORE);
	SetForegroundWindow(menu_hwnd);
}

// Dark mode stuff. See https://github.com/microsoft/WindowsAppSDK/issues/41

set_window_frame_dark_mode :: (hwnd: HWND, dark: bool) {
	dark_mode:= cast(BOOL) dark;
	DwmSetWindowAttribute(hwnd, .DWMWA_USE_IMMERSIVE_DARK_MODE, *dark_mode, size_of(BOOL));
}

is_system_app_dark_mode_enabled :: () -> bool {
	// Dynamically link because this API is undocumented
	hUxTheme:= LoadLibraryW(utf8_to_wide("uxtheme.dll"));
	if hUxTheme == null {
		log_error("uxtheme.dll not found.");
		return false;
	}
	defer FreeLibrary(hUxTheme);
	prc:= cast(() -> bool #c_call) GetProcAddress(hUxTheme, MAKEINTRESOURCEA(132));
	if prc == null {
		log_error("ShouldAppsUseDarkMode not found.");
		return false;
	}

	return prc();
}

prepare_window_pos :: (x_anchor: s32, y_anchor: s32) -> s32, s32 {
	refresh_monitor_rect();
	ui_scale:= scale_factor_from_monitor(primary_monitor);
	window_width  = xx (240*ui_scale);
	window_height = xx (290*ui_scale);
	x, y: s32;
	x = x_anchor - window_width/2;
	y = y_anchor - window_height + xx (20*ui_scale);
	Clamp(*x, 0, primary_monitor_rect.right - window_width);
	Clamp(*y, 0, primary_monitor_rect.bottom - window_height);
	return x, y;
}

get_window_scale :: (hwnd: HWND) -> float {
	monitor:= MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
	return scale_factor_from_monitor(monitor);
}

scale_factor_from_monitor :: (monitor: HMONITOR) -> float {
	scale_factor: DEVICE_SCALE_FACTOR;
	GetScaleFactorForMonitor(monitor, *scale_factor);
	if scale_factor == .DEVICE_SCALE_FACTOR_INVALID {
		scale_factor = .SCALE_100_PERCENT;
	}
	return cast(float)scale_factor/100;
}

ui_scale: float;
my_theme: GetRect.Overall_Theme;
is_dark_theme: bool;

draw_menu_frame :: (hwnd: HWND) {
	#import "GetRect";
	if !is_ui_initialised {
		is_ui_initialised = true;
		Simp.set_render_target(menu_hwnd);

		// Check the auto-launch registry entry
		config__auto_launch_enabled = false;
		reg_key: HKEY;
		if RegOpenKeyExA(HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0, KEY_QUERY_VALUE, *reg_key) {
			log_error("Failed to open registry key.");
		} else {
			defer RegCloseKey(reg_key);
			key_type: DWORD;
			data: []u8;
			buf_size: u32;
			if !RegQueryValueExA(reg_key, reg_value_name, null, null, null, *buf_size) // Get the required buffer size
				data = NewArray(buf_size, u8);
			res:= RegQueryValueExA(reg_key, reg_value_name, null, *key_type, data.data, *buf_size);
			if res == {
			case 0; // success
				if data.count > 0 && data[data.count-1] == 0  data.count -= 1; // Trim trailing null character.
				if key_type == REG_SZ
				&& registry_value_exe_path.count == data.count
				&& memcmp(registry_value_exe_path.data, data.data, data.count) == 0 {
					config__auto_launch_enabled = true;
				}
			case ERROR_FILE_NOT_FOUND;
			case;
				log_error("Failed to query registry value: % (Code: %)", reg_value_name, res);
			}
		}
	}
	
	scale_:= get_window_scale(hwnd);
	if ui_scale != scale_ {
		ui_scale = scale_;
		GetRect.ui_init();
	}

	my_theme = default_theme_procs[ifx is_dark_theme Default_Themes.Default else Default_Themes.Nimbus]();
	set_default_theme(my_theme);

	bg_col := my_theme.background_color;
	Simp.clear_render_target(bg_col.x, bg_col.y, bg_col.z, 1);

	ui_per_frame_update(hwnd, window_width, window_height, current_time);

	v_padding:= ceil(6*ui_scale);
	h_padding:= ceil(12*ui_scale);

	height:= ceil(30*ui_scale);
	r: = get_rect(h_padding, window_height - height - v_padding, xx window_width - 2*h_padding, height);


	// Title
	label(r, app_name, *my_theme.label_theme);

	// Version caption
	small_height:= ceil(21*ui_scale);
	r.y -= small_height;
	r.h = small_height;
	label(r, tprint("% — %", app_version, BUILD_DATE_STRING), *my_theme.label_theme);

	r.h = small_height;
	r.y -= small_height;
	if !is_up_to_date {
		_, _, released:= button(r, tprint("Update to %", newer_version), *my_theme.button_theme, 1123);
		if released {
			open_url_in_browser(app_releases_url);
		}
	}

	{ // Close button
		button_theme:= my_theme.button_theme;
		button_theme.frame_color = .{0,0,0,0};
		button_theme.text_color.w *= 0.5;
		button_theme.surface_color.w = 0;
		size:= ceil(28*ui_scale);
		r:= get_rect(xx window_width - size, window_height - size, size, size);
		_, _, released:= button(r, "X", *button_theme, 9999);
		if released {
			close_menu();
			return;
		}
	}

	// Configuration settings
	// ----------------------
	config_changed:= false;

	height = ceil(25*ui_scale);
	r.h = height - 1; // Subtract one so that the mouse hit boxes do not overlap; A possible bug in GetRect.
	r.y -= height;
	toggled:= base_checkbox(r, ifx config__enabled "Enabled" else "Enable", config__enabled, *my_theme.checkbox_theme, 0);
	if toggled {
		set_config__enabled(!config__enabled);
		config_changed = true;
	}

	r.y -= height;
	toggled = base_checkbox(r, "Ctrl+Win+F11 to toggle", config__toggle_shortcut_enabled, *my_theme.checkbox_theme, 1);
	if toggled {
		config__toggle_shortcut_enabled ^= true;
		set_windows_hooks_appropriately();
		config_changed = true;
	}

	r.y -= height;
	toggled = base_checkbox(r, "Scroll to reveal taskbar", config__scroll_activation_enabled, *my_theme.checkbox_theme, 2);
	if toggled {
		config__scroll_activation_enabled ^= true;
		set_windows_hooks_appropriately();
		config_changed = true;
	}

	r.y -= height;
	toggled = base_checkbox(r, "Auto-hide when disabled", config__autohide_when_disabled, *my_theme.checkbox_theme, 3);
	if toggled {
		config__autohide_when_disabled = !config__autohide_when_disabled;
		set_taskbar_visibility();
		config_changed = true;
	}

	r.y -= height;
	toggled = base_checkbox(r, "Start at log-in (non-admin)", config__auto_launch_enabled, *my_theme.checkbox_theme, 3);
	if toggled {
		set_config__auto_launch_enabled(!config__auto_launch_enabled);
		config_changed = true;
	}

	{
		note_height:= small_height*0.9;
		label_theme:= my_theme.label_theme;
		label_theme.alignment = .Left;
		if !config__auto_launch_enabled  label_theme.text_color.w *= 0.5;
		d:= note_height*0.8;
		r.h = note_height;
		r.y -= d;
		label(r, "Not recommended. Instead,", *label_theme);
		r.y -= d;
		label(r, "use Task Scheduler to run", *label_theme);
		r.y -= d;
		label(r, "with 'highest privileges.'", *label_theme);
	}

	// Quit button
	r.h = height;
	r.y -= height + v_padding;
	_, _, released:= button(r, "Quit", *my_theme.button_theme, 420);
	if released {
		terminate_program();
		return;
	}

	if config_changed save_config();

	// print("window height: %\n", (window_height - (r.y - v_padding))/ui_scale);

	Simp.swap_buffers(hwnd);
}

#assert size_of(Cold_Config) == 512;
Cold_Config :: union {
	_: [512]u8;
	struct {
		VERSION :: 2;
		version: s64;
		using v1: V1;
		V1 :: struct {
			enabled: bool;
			toggle_shortcut_enabled: bool;
			scroll_activation_enabled: bool;
			auto_launch_enabled: bool;
		}
		autohide_when_disabled: bool;
	}
}

config_file_name :: "config";

save_config :: () {
	programs_dir:= get_path_os_program_data();
	data_dir:= join(programs_dir, "\\", app_name, allocator=temp);
	if !make_directory_if_it_does_not_exist(data_dir) {
		log_error("Could not create data directory");
		return;
	}
	config_path:= join(data_dir, "\\", config_file_name, allocator=temp);
	config:= Cold_Config.{
		version = Cold_Config.VERSION,
		enabled = config__enabled,
		toggle_shortcut_enabled = config__toggle_shortcut_enabled,
		scroll_activation_enabled = config__scroll_activation_enabled,
		auto_launch_enabled = config__auto_launch_enabled,
		autohide_when_disabled = config__autohide_when_disabled,
	};
	if !write_entire_file(config_path, *config, size_of(Cold_Config)) {
		log_error("Failed to write config file");
		return;
	}
	log("Saved config version % to %", config.version, config_path);
}

load_config :: () {
	// Set defaults first.
	abd: APPBARDATA;
	abd.cbSize = size_of(APPBARDATA);
	res:= SHAppBarMessage(ABM_GETSTATE, *abd);
	config__autohide_when_disabled = (res & ABS_AUTOHIDE) != 0;

	programs_dir:= get_path_os_program_data();
	data_dir:= join(programs_dir, "\\", app_name, allocator=temp);
	config_path:= join(data_dir, "\\", config_file_name, allocator=temp);
	data, ok := read_entire_file(config_path);
	if !ok {
		log("Failed to read config file %", config_path, flags=.WARNING);
		return;
	}
	if data.count < 8 {
		log("Config file is too small in size to be valid (% bytes).", data.count, flags=.WARNING);
		return;
	}
	config:= cast(*Cold_Config) data.data;
	if !(1 <= config.version && config.version <= Cold_Config.VERSION) {
		log("Unsupported config file version. Got %, wanted at most %.", config.version, Cold_Config.VERSION, flags=.WARNING);
		return;
	}
	expected_size:= ifx config.version==1 16 else 512;
	if data.count != expected_size {
		log("Config file contains an invalid number of bytes. Got %, wanted %.", data.count, expected_size, flags=.WARNING);
		return;
	}
	set_config__enabled(config.enabled);
	config__toggle_shortcut_enabled = config.toggle_shortcut_enabled;
	config__scroll_activation_enabled = config.scroll_activation_enabled;
	set_config__auto_launch_enabled(config.auto_launch_enabled);

	if config.version == 2 {
		config__autohide_when_disabled = config.autohide_when_disabled;
	}

	set_windows_hooks_appropriately();
	log("Loaded configuration version % successfully.", config.version);
}

open_url_in_browser :: (url: string) {
	if xx ShellExecuteW(null, utf8_to_wide("open"), utf8_to_wide(url), null, null, SW_SHOWNORMAL) <= 32 {
		log_error("Failed to open URL in browser.");
	}
}