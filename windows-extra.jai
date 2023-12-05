HHOOK :: HANDLE;

wstring :: *u16;

VK_LALT :: VK_LMENU;
VK_RALT :: VK_RMENU;

WM_APP :: 0x8000;


MAKEINTRESOURCEA :: inline (i: u32) -> *u8 { return cast(*u8)i; }
MAKEINTRESOURCEW :: inline (i: u32) -> *u16 { return cast(*u16)i; }

IDI_APPLICATION := cast(*void) 32512;

LoadImageW :: (hInst: HINSTANCE, name: LPCWSTR, type: u32, cx: s32, cy: s32, fuLoad: u32 ) -> HANDLE #foreign user32;

IMAGE_BITMAP :: 0;
IMAGE_ICON :: 1;
IMAGE_CURSOR :: 2;
IMAGE_ENHMETAFILE :: 3;

LR_DEFAULTCOLOR :: 0x0000;
LR_MONOCHROME :: 0x0001;
LR_COLOR :: 0x0002;
LR_COPYRETURNORG :: 0x0004;
LR_COPYDELETEORG :: 0x0008;
LR_LOADFROMFILE :: 0x0010;
LR_LOADTRANSPARENT :: 0x0020;
LR_DEFAULTSIZE :: 0x0040;
LR_VGACOLOR :: 0x0080;
LR_LOADMAP3DCOLORS :: 0x1000;
LR_CREATEDIBSECTION :: 0x2000;
LR_COPYFROMRESOURCE :: 0x4000;
LR_SHARED :: 0x8000;

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
MoveWindow :: (hwnd: HWND, x: s32, y: s32, width: s32, height: s32, repaint: BOOL) -> BOOL #foreign user32;

CS_DROPSHADOW :: 0x00020000;
CS_NOCLOSE :: 0x0200;

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
ShellExecuteW :: (hwnd: HWND, lpOperation: *u16, lpFile: *u16, lpParameters: *u16, lpDirectory: *u16, nShowCmd: s32) -> HINSTANCE #foreign shell32;

SHAppBarMessage :: (dwMessage: u32, pData: *APPBARDATA) -> u64 #foreign shell32;

ABM_SETSTATE :: 0x0000000a;
ABM_GETSTATE :: 0x00000004;
ABS_AUTOHIDE :: 0x0000001;
ABS_ALWAYSONTOP :: 0x0000002;

APPBARDATA :: struct {
	cbSize: u32;
	hWnd: HWND;
	uCallbackMessage: u32;
	uEdge: u32;
	rc: RECT;
	lParam: LPARAM;
}


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


GetScaleFactorForMonitor :: (hmonitor: HMONITOR, scale_factor: *DEVICE_SCALE_FACTOR) #foreign shcore;

Device_Scale_Factor :: enum {
  DEVICE_SCALE_FACTOR_INVALID :: 0;
  SCALE_100_PERCENT :: 100;
  SCALE_120_PERCENT :: 120;
  SCALE_125_PERCENT :: 125;
  SCALE_140_PERCENT :: 140;
  SCALE_150_PERCENT :: 150;
  SCALE_160_PERCENT :: 160;
  SCALE_175_PERCENT :: 175;
  SCALE_180_PERCENT :: 180;
  SCALE_200_PERCENT :: 200;
  SCALE_225_PERCENT :: 225;
  SCALE_250_PERCENT :: 250;
  SCALE_300_PERCENT :: 300;
  SCALE_350_PERCENT :: 350;
  SCALE_400_PERCENT :: 400;
  SCALE_450_PERCENT :: 450;
  SCALE_500_PERCENT :: 500;
}
DEVICE_SCALE_FACTOR :: Device_Scale_Factor;



RegDeleteValueA :: (hkey: HKEY, lpValueName: *u8) -> LSTATUS #foreign kernel32;
RegSetValueExA :: (hkey: HKEY, lpValueName: *u8, Reserved: DWORD, dwType: DWORD, lpData: *u8, cbData: DWORD) -> LSTATUS #foreign kernel32;



#scope_file

kernel32 :: #system_library "kernel32";
user32   :: #system_library "user32";
shell32  :: #system_library "Shell32";
dwmapi   :: #system_library "Dwmapi";
shcore   :: #system_library "Shcore";
