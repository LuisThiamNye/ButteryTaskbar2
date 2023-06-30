package buttery_taskbar

import win "core:sys/windows"
foreign import user32 "system:User32.lib"

foreign user32 {
	IsWindowVisible :: proc(win.HWND) -> b32 ---
}

HSHELL_WINDOWCREATED       :: 1
HSHELL_WINDOWDESTROYED     :: 2
HSHELL_ACTIVATESHELLWINDOW :: 3
HSHELL_WINDOWACTIVATED     :: 4
HSHELL_GETMINRECT          :: 5
HSHELL_REDRAW              :: 6
HSHELL_TASKMAN             :: 7
HSHELL_LANGUAGE            :: 8
HSHELL_SYSMENU             :: 9
HSHELL_ENDTASK             :: 10
HSHELL_ACCESSIBILITYSTATE  :: 11
HSHELL_APPCOMMAND          :: 12
HSHELL_WINDOWREPLACED      :: 13
HSHELL_WINDOWREPLACING     :: 14
HSHELL_MONITORCHANGED      :: 16
HSHELL_HIGHBIT             :: 0x8000
HSHELL_FLASH               :: HSHELL_REDRAW | HSHELL_HIGHBIT
HSHELL_RUDEAPPACTIVATED    :: HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

VKey :: enum { // virtual keys
	nil = 0,
	lbutton = 1,
	rbutton,
	cancel,
	middle_button,
	x1_button,
	x2_button,
	backspace = 0x8,
	tab,
	clear = 0xc,
	enter,
	shift = 0x10,
	control,
	alt,
	pause,
	caps_lock,
	kana,
	hanguel,
	ime_on,
	junja,
	final,
	hanja = 0x19,
	kanji = 0x19,
	ime_off,
	escape,
	convert,
	nonconvert,
	accept,
	mode_change,
	space,
	page_up,
	page_down,
	end,
	home,
	left_arrow,
	up_arrow,
	right_arrow,
	down_arrow,
	select,
	print,
	execute,
	print_screen,
	insert,
	delete,
	help,
	n0,
	n1,
	n2,
	n3,
	n4,
	n5,
	n6,
	n7,
	n8,
	n9,
	a = 0x41,
	b,
	c,
	d,
	e,
	f,
	g,
	h,
	i,
	j,
	k,
	l,
	m,
	n,
	o,
	p,
	q,
	r,
	s,
	t,
	u,
	v,
	w,
	x,
	y,
	z,
	lwin,
	rwin,
	apps,
	sleep = 0x5F,
	keypad0,
	keypad1,
	keypad2,
	keypad3,
	keypad4,
	keypad5,
	keypad6,
	keypad7,
	keypad8,
	keypad9,
	multiply,
	add,
	separator,
	subtract,
	decimal,
	divide,
	f1,
	f2,
	f3,
	f4,
	f5,
	f6,
	f7,
	f8,
	f9,
	f10,
	f11,
	f12,
	f13,
	f14,
	f15,
	f16,
	f17,
	f18,
	f19,
	f20,
	f21,
	f22,
	f23,
	f24,
	num_lock = 0x90,
	scroll_lock,
	lshift = 0xa0,
	rshift,
	lcontrol,
	rcontrol,
	lalt,
	ralt,
	browser_back,
	browser_forward,
	browser_refresh,
	browser_stop,
	browser_search,
	browser_favourites,
	browser_home,
	volume_mute,
	volume_down,
	volume_up,
	media_next,
	media_prev,
	media_stop,
	media_play_pause,
	launch_mail,
	launch_media_select,
	launch_app1,
	launch_app2,
	oem_1 = 0xBA, // Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ';:' key
	oem_plus,
	oem_comma,
	oem_minus,
	oem_full_stop,
	oem_2, // Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '/?' key
	oem_3, // Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '`~' key
	oem_4=0xDB, //	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '[{' key
	oem_5, //	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '\|' key
	oem_6, //	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ']}' key
	oem_7, //	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the 'single-quote/double-quote' key
	oem_8, // Used for miscellaneous characters; it can vary by keyboard.
	oem_102=0xE2, //	The <> keys on the US standard keyboard, or the \\| key on the non-US 102-key keyboard

// 	0xE3-E4 	OEM specific
// VK_PROCESSKEY 	0xE5 	IME PROCESS key
// 	0xE6 	OEM specific
// VK_PACKET 	0xE7 	Used to pass Unicode characters as if they were keystrokes. The VK_PACKET key is the low word of a 32-bit Virtual Key value used for non-keyboard input methods. For more information, see Remark in KEYBDINPUT, SendInput, WM_KEYDOWN, and WM_KEYUP
// - 	0xE8 	Unassigned
// 	0xE9-F5 	OEM specific
// VK_ATTN 	0xF6 	Attn key
// VK_CRSEL 	0xF7 	CrSel key
// VK_EXSEL 	0xF8 	ExSel key
// VK_EREOF 	0xF9 	Erase EOF key
// VK_PLAY 	0xFA 	Play key
// VK_ZOOM 	0xFB 	Zoom key
// VK_NONAME 	0xFC 	Reserved
// VK_PA1 	0xFD 	PA1 key
// VK_OEM_CLEAR 	0xFE 	Clear key
}
