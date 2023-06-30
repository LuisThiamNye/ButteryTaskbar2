package main

import "core:fmt"

import bt "buttery-taskbar"

main :: proc() {
	state: bt.State
	bt.run_program(&state)
}

/*

Bug where sometimes the taskbar, even though the window is set to visible, does not show any contents (transparent) except a top border and you can click straight through it as though it weren't there.
Even telling it to hide then show does not fully fix this, but seems to be more reliable (?).
PostMessageW(hwnd, WM_PAINT, 0, 0) is not effective.

This problem seems to not happen when the taskbar is shown by non-startmenu methods?

Showing the taskbar when the windows key is held down and a short while thereafter mitigates the above issue?	

TODO zone around the taskbar where it won't disappear if the mouse is present there.
*/