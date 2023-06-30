package buttery_taskbar

import "core:fmt"
import "core:runtime"
import "core:os"
import "core:time"
import "core:thread"
import "core:sync"
import win "core:sys/windows"

State :: struct {
	is_enabled: bool,
	taskbar_hwnds: [dynamic]win.HWND,
	core_windows: map[win.HWND]rawptr,
	should_show_taskbar: bool,
	should_stay_visible_before: time.Time,
	is_win_key_down: bool,
	taskbar_thread: ^thread.Thread,
	taskbar_thread_sema: sync.Atomic_Sema,
	stop_polling: bool,
}

app_name :: "Buttery Taskbar"

global_state: ^State

run_program :: proc(state: ^State) {
	using win

	pressed_keys = new([32]u8)
	global_state = state
	state.is_enabled = true
	sync.post(&state.taskbar_thread_sema)

	// win.timeBeginPeriod(1) // higher resolution timings; not strictly needed
	start_taskbar_thread(state)
	refresh_taskbars(state)

	keyboard_hook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboard_hook_proc, nil, 0)
	defer UnhookWindowsHookEx(keyboard_hook)

	setup_window(state)
	do_message_loop()
}

cleanup_program :: proc(state: ^State) {
	win.UnhookWindowsHookEx(keyboard_hook)
	state.should_show_taskbar = true
	set_taskbar_visibility(state)
}
	
exit_program :: proc(state: ^State) {
	cleanup_program(state)
	os.exit(0)
}


// Keyboard stuff

pressed_keys : ^[32]u8

key_pressed :: proc(key: VKey) -> bool {
	x := cast(uint) key
	b := pressed_keys[x>>3]
	i := b & (1<<(x & 0b111))
	return i > 0
}

change_key_pressed :: proc(pressed_keys: ^[32]u8, key: VKey, pressed: bool) {
	x := cast(uint) key
	b := pressed_keys[x>>3]
	mask : u8 = 1<<(x & 0b111)
	if pressed {
		b |= mask
	} else {
		b &~= mask
	}
	pressed_keys[x>>3] = b
}

notify_key_pressed :: proc(key: VKey, pressed: bool) {
	change_key_pressed(pressed_keys, key, pressed)
}

keyboard_hook : win.HHOOK

keyboard_hook_proc :: proc "stdcall" (ncode: i32, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	using win
	context = runtime.default_context()
	info := (^KBDLLHOOKSTRUCT)(uintptr(lparam))

	input : INPUT
	input.type = .KEYBOARD
	input.ki.time = info.time

	if ncode == 0 {
		vk := VKey(info.vkCode)
		switch wparam {
		case WM_KEYDOWN, WM_SYSKEYDOWN:
			notify_key_pressed(vk, true)

			mods : bit_set[enum{caps_lock, shift, control, win, alt}]

			if key_pressed(.caps_lock) {mods += {.caps_lock}}
			if key_pressed(.lshift) {mods += {.shift}}
			if key_pressed(.lcontrol) {mods += {.control}}
			if key_pressed(.lwin) {mods += {.win}}
			if key_pressed(.lalt) {mods += {.alt}}
			if key_pressed(.ralt) {mods += {.alt}}
			if key_pressed(.rwin) {mods += {.win}}
			if key_pressed(.rcontrol) {mods += {.control}}
			if key_pressed(.rshift) {mods += {.shift}}

			if .win in mods && (vk==.lwin || vk==.rwin) {
				global_state.is_win_key_down = .win in mods
				set_taskbar_visibility(global_state)
			}

			if mods=={.win, .control} {
				#partial switch vk {
				// Note: If winkey is the only modifier, mouse button keybinding ends up opening the start menu (winkey press leaks through)
				case .f11: // enable / disable
					if global_state.is_enabled {
						global_state.is_enabled = false
						global_state.should_show_taskbar = true
					} else {
						global_state.is_enabled = true
						refresh_taskbar_state(global_state)
					}
					set_taskbar_visibility(global_state)
					return 1
				}
			} else if mods=={.win, .shift} {
				#partial switch vk {
				case .f11: // exit the program
					exit_program(global_state)
					return 1
				}
			}

		case WM_KEYUP, WM_SYSKEYUP:
			notify_key_pressed(vk, false)
			if vk == .lwin || vk == .rwin {
				global_state.is_win_key_down = key_pressed(.lwin) || key_pressed(.rwin)
				// We want the taskbar to stay visible for a short while after the windows key is lifted,
				// as start menu activation might come next and we do not want to hide the taskbar before then.
				global_state.should_stay_visible_before = time.time_add(time.now(), 400*time.Millisecond)
				set_taskbar_visibility(global_state)
			}
		}
	}
	return CallNextHookEx(keyboard_hook, ncode, wparam, lparam)
}