package buttery_taskbar

import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"
import win "core:sys/windows"

start_taskbar_thread :: proc(state: ^State) {
	state.taskbar_thread = thread.create_and_start_with_poly_data(state, taskbar_thread_proc)
}

refresh_taskbars :: proc(state: ^State) {
	h_primary_taskbar := win.FindWindowW(win.utf8_to_wstring("Shell_TrayWnd"), nil)
	clear(&state.taskbar_hwnds)
	append(&state.taskbar_hwnds, h_primary_taskbar)
	hwnd: win.HWND = nil
	for {
		hwnd = win.FindWindowExW(nil, hwnd, win.utf8_to_wstring("Shell_SecondaryTrayWnd"), nil)
		if hwnd == nil {break}
		append(&state.taskbar_hwnds, hwnd)
	}
}

set_taskbar_visibility :: proc(state: ^State) {
	sync.atomic_store(&state.stop_polling, true)
	sync.post(&state.taskbar_thread_sema)
}

taskbar_thread_proc :: proc(state: ^State) {
	using win
	for {
		sync.wait(&state.taskbar_thread_sema)
		log("Woke up taskbar thread.")

		refresh_taskbars(state)

		sync.atomic_store(&state.stop_polling, false)
		for n_attempts := 0; n_attempts<60 && !state.stop_polling; n_attempts += 1 {
			failed := false
			should_show_taskbar := state.should_show_taskbar || state.is_win_key_down || time.diff(time.now(), state.should_stay_visible_before) > 0
			for hwnd, i in state.taskbar_hwnds {
				previously_shown := ShowWindow(hwnd, should_show_taskbar ? SW_SHOWNOACTIVATE : SW_HIDE)
				actually_shown := bool(IsWindowVisible(hwnd))
				log("Set taskbar visibility:", previously_shown, "->", should_show_taskbar,
					"(actual:", actually_shown, "; win:", state.is_win_key_down, "; state:", state.should_show_taskbar, "; n:", n_attempts, ")")
				failed = should_show_taskbar != actually_shown
			}
			if time.diff(time.now(), state.should_stay_visible_before) > 0 {
				// keep polling until the time is up
				n_attempts = 0
				time.sleep(100*time.Millisecond)
			} else if failed {
				// This rarely happens
				time.sleep(10*time.Millisecond)
				log("Retry!")
			} else if should_show_taskbar {
				break // making and keeping the taskbar visible usually isn't a problem
			} else {
				// Just to be extra sure, keep setting the taskbar to hidden for a while
				time.sleep(50*time.Millisecond)
				n_attempts += 8
			}
		}
	}
}

refresh_taskbar_state :: proc(state: ^State) {
	should_show_taskbar := false
	active_hwnd := win.GetForegroundWindow()
	for hwnd, _ in state.core_windows {
		// Window info (rect, style etc) does not allow distinguishing between open and closed start menu.
		// IsWindowVisible always returns true.
		// But we can check for whether the window is active
		should_show_taskbar = (hwnd == active_hwnd)
		if should_show_taskbar do break
	}
	state.should_show_taskbar = should_show_taskbar
}