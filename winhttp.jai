HINTERNET :: *void;
INTERNET_PORT :: WORD;

WINHTTP_ACCESS_TYPE_DEFAULT_PROXY   :: 0;
WINHTTP_ACCESS_TYPE_NO_PROXY        :: 1;
WINHTTP_ACCESS_TYPE_NAMED_PROXY     :: 3;
WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY :: 4;

WINHTTP_FLAG_SECURE               :: 0x00800000;
WINHTTP_FLAG_ESCAPE_PERCENT       :: 0x00000004;
WINHTTP_FLAG_NULL_CODEPAGE        :: 0x00000008;
WINHTTP_FLAG_BYPASS_PROXY_CACHE   :: 0x00000100;
WINHTTP_FLAG_REFRESH              :: WINHTTP_FLAG_BYPASS_PROXY_CACHE;
WINHTTP_FLAG_ESCAPE_DISABLE       :: 0x00000040;
WINHTTP_FLAG_ESCAPE_DISABLE_QUERY :: 0x00000080;

WinHttpReadData :: (hRequest: HINTERNET, lpBuffer: *void, dwNumberOfBytesToRead: DWORD, lpdwNumberOfBytesRead: *DWORD) -> BOOL #foreign winhttp;

WinHttpOpen :: (pszAgentW: *u16, dwAccessType: DWORD, pszProxyW: *u16, pszProxyBypassW: *u16, dwFlags: DWORD) -> HINTERNET #foreign winhttp;

WinHttpCloseHandle :: (hInternet: HINTERNET) -> BOOL #foreign winhttp;

WinHttpConnect :: (hSession: HINTERNET, pswzServerName: *u16, nServerPort: INTERNET_PORT, dwReserved: DWORD) -> HINTERNET #foreign winhttp;

WinHttpOpenRequest :: (hConnect: HINTERNET, pwszVerb: *u16, pwszObjectName: *u16, pwszVersion: *u16, pwszReferrer: *u16, ppwszAcceptTypes: **u16, dwFlags: DWORD) -> HINTERNET #foreign winhttp;

WinHttpSendRequest :: (hRequest: HINTERNET, lpszHeaders: *u16, dwHeadersLength: DWORD, lpOptional: *void, dwOptionalLength: DWORD, dwTotalLength: DWORD, dwContext: u64) -> BOOL #foreign winhttp;

WinHttpReceiveResponse :: (hRequest: HINTERNET, lpReserved: *void) -> BOOL #foreign winhttp;

winhttp :: #library,system "Winhttp";
