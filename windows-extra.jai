HHOOK :: HANDLE;

wstring :: *u16;

VK_LALT :: VK_LMENU;
VK_RALT :: VK_RMENU;

WM_APP :: 0x8000;


MAKEINTRESOURCEA :: inline (i: u32) -> *u8 { return cast(*u8)i; }
MAKEINTRESOURCEW :: inline (i: u32) -> *u16 { return cast(*u16)i; }

IDI_APPLICATION := cast(*void) 32512;


KBDLLHOOKSTRUCT :: struct {
	vkCode: DWORD;
	scanCode: DWORD;
	flags: DWORD;
	time: DWORD;
	dwExtraInfo: *void;
}

MSLLHOOKSTRUCT :: struct {
	pt: POINT;
	mouseData: DWORD;
	flags: DWORD;
	time: DWORD;
	dwExtraInfo: *void;
}

MOUSEINPUT :: struct {
	dx: s32;
	dy: s32;
	mouseData: DWORD;
	dwFlags: DWORD;
	time: DWORD;
	dwExtraInfo: *void;
}

KEYBDINPUT :: struct {
	wVk: WORD;
	wScan: WORD;
	dwFlags: DWORD;
	time: DWORD;
	dwExtraInfo: *void;
}

HARDWAREINPUT :: struct {
	uMsg: DWORD;
	wParamL: WORD;
	wParamH: WORD;
}

INPUT_TYPE :: enum u32 {
	MOUSE :: 0;
	KEYBOARD :: 1;
	HARDWARE :: 2;
}

INPUT :: struct {
	type: INPUT_TYPE;
	using _: union {
		mi: MOUSEINPUT;
		ki: KEYBDINPUT;
		hi: HARDWAREINPUT;
	}
}

HOOKPROC :: #type (code: s32, wParam: WPARAM, lParam: LPARAM) -> LRESULT #c_call;

FindWindowW :: (lpClassName: LPCWSTR, lpWindowName: LPCWSTR) -> HWND #foreign user32;
FindWindowExW :: (hWndParent: HWND, hWndChildAfter: HWND, lpszClass: LPCWSTR, lpszWindow: LPCWSTR) -> HWND #foreign user32;
IsWindowVisible :: (hwnd: HWND) -> BOOL #foreign user32;
GetClassNameW :: (hWnd: HWND, lpClassName: *u16, nMaxCount: s32) -> s32 #foreign user32;
SetForegroundWindow :: (hWnd: HWND) -> BOOL #foreign user32;
BringWindowToTop :: (hWnd: HWND) -> BOOL #foreign user32;

SetWindowsHookExW :: (idHook: s32, lpfn: HOOKPROC, hmod: HINSTANCE, dwThreadId: DWORD) -> HHOOK #foreign user32;
UnhookWindowsHookEx :: (hhk: HHOOK) -> BOOL #foreign user32;
CallNextHookEx :: (hhk: HHOOK, nCode: s32, wParam: WPARAM, lParam: LPARAM) -> LRESULT #foreign user32;

GetMessageW :: (lpMsg: *MSG, hWnd: HWND, wMsgFilterMin: u32, wMsgFilterMax: u32) -> BOOL #foreign user32;
RegisterWindowMessageW :: (lpString: LPCWSTR) -> u32 #foreign user32;

SetProcessDpiAwarenessContext :: (value: DPI_AWARENESS_CONTEXT) -> BOOL #foreign user32;

SendInput :: (cInputs: u32, pInputs: *INPUT, cbSize: s32) -> u32 #foreign user32;
KEYEVENTF_KEYUP :: 0x2;

// SetWindowsHook codes
WH_MIN             :: -1;
WH_MSGFILTER       :: -1;
WH_JOURNALRECORD   :: 0;
WH_JOURNALPLAYBACK :: 1;
WH_KEYBOARD        :: 2;
WH_GETMESSAGE      :: 3;
WH_CALLWNDPROC     :: 4;
WH_CBT             :: 5;
WH_SYSMSGFILTER    :: 6;
WH_MOUSE           :: 7;
WH_HARDWARE        :: 8;
WH_DEBUG           :: 9;
WH_SHELL           :: 10;
WH_FOREGROUNDIDLE  :: 11;
WH_CALLWNDPROCRET  :: 12;
WH_KEYBOARD_LL     :: 13;
WH_MOUSE_LL        :: 14;
WH_MAX             :: 14;
WH_MINHOOK         :: WH_MIN;
WH_MAXHOOK         :: WH_MAX;

HSHELL_WINDOWCREATED       :: 1;
HSHELL_WINDOWDESTROYED     :: 2;
HSHELL_ACTIVATESHELLWINDOW :: 3;
HSHELL_WINDOWACTIVATED     :: 4;
HSHELL_GETMINRECT          :: 5;
HSHELL_REDRAW              :: 6;
HSHELL_TASKMAN             :: 7;
HSHELL_LANGUAGE            :: 8;
HSHELL_SYSMENU             :: 9;
HSHELL_ENDTASK             :: 10;
HSHELL_ACCESSIBILITYSTATE  :: 11;
HSHELL_APPCOMMAND          :: 12;
HSHELL_WINDOWREPLACED      :: 13;
HSHELL_WINDOWREPLACING     :: 14;
HSHELL_MONITORCHANGED      :: 16;
HSHELL_HIGHBIT             :: 0x8000;
HSHELL_FLASH               :: HSHELL_REDRAW | HSHELL_HIGHBIT;
HSHELL_RUDEAPPACTIVATED    :: HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT;


NOTIFYICONDATAW :: struct {
	cbSize: DWORD;
	hWnd: HWND;
	uID: u32;
	uFlags: u32;
	uCallbackMessage: u32;
	hIcon: HICON;
	szTip: [128]u16;
	dwState: DWORD;
	dwStateMask: DWORD;
	szInfo: [256]u16;
	using _: union {
		uTimeout: u32;
		uVersion: u32;
	};
	szInfoTitle: [64]u16;
	dwInfoFlags: DWORD;
	guidItem: GUID;
	hBalloonIcon: HICON;
}

NIF_MESSAGE :: 0x00000001;
NIF_ICON :: 0x00000002;
NIF_TIP :: 0x00000004;
NIF_STATE :: 0x00000008;
NIF_INFO :: 0x00000010;
NIF_GUID :: 0x00000020;
NIF_REALTIME :: 0x00000040;
NIF_SHOWTIP :: 0x00000080;

NIM_ADD :: 0x00000000;
NIM_MODIFY :: 0x00000001;
NIM_DELETE :: 0x00000002;
NIM_SETFOCUS :: 0x00000003;
NIM_SETVERSION :: 0x00000004;

NIN_SELECT :: 0x0400;

Shell_NotifyIconW :: (dwMessage: DWORD, lpData: *NOTIFYICONDATAW) -> BOOL #foreign shell32;



DWMWINDOWATTRIBUTE :: enum u32 {
	DWMWA_NCRENDERING_ENABLED;
	DWMWA_NCRENDERING_POLICY;
	DWMWA_TRANSITIONS_FORCEDISABLED;
	DWMWA_ALLOW_NCPAINT;
	DWMWA_CAPTION_BUTTON_BOUNDS;
	DWMWA_NONCLIENT_RTL_LAYOUT;
	DWMWA_FORCE_ICONIC_REPRESENTATION;
	DWMWA_FLIP3D_POLICY;
	DWMWA_EXTENDED_FRAME_BOUNDS;
	DWMWA_HAS_ICONIC_BITMAP;
	DWMWA_DISALLOW_PEEK;
	DWMWA_EXCLUDED_FROM_PEEK;
	DWMWA_CLOAK;
	DWMWA_CLOAKED;
	DWMWA_FREEZE_REPRESENTATION;
	DWMWA_PASSIVE_UPDATE_MODE;
	DWMWA_USE_HOSTBACKDROPBRUSH;
	DWMWA_USE_IMMERSIVE_DARK_MODE :: 20;
	DWMWA_WINDOW_CORNER_PREFERENCE :: 33;
	DWMWA_BORDER_COLOR;
	DWMWA_CAPTION_COLOR;
	DWMWA_TEXT_COLOR;
	DWMWA_VISIBLE_FRAME_BORDER_THICKNESS;
	DWMWA_SYSTEMBACKDROP_TYPE;
  DWMWA_LAST;
}

DWMNCRENDERINGPOLICY :: enum {
	DWMNCRP_USEWINDOWSTYLE;
	DWMNCRP_DISABLED;
	DWMNCRP_ENABLED;
	DWMNCRP_LAST;
}

MARGINS :: [4]s64;

DwmFlush :: () -> HRESULT #foreign dwmapi;
DwmExtendFrameIntoClientArea :: (hWnd: HWND, pMarInset: *MARGINS) -> HRESULT #foreign dwmapi;
DwmSetWindowAttribute :: (hWnd: HWND, dwAttribute: DWMWINDOWATTRIBUTE, pvAttribute: *void, cbAttribute: DWORD) -> HRESULT #foreign dwmapi;



#scope_file

kernel32 :: #system_library "kernel32";
user32   :: #system_library "user32";
shell32  :: #system_library "Shell32";
dwmapi   :: #system_library "Dwmapi";
