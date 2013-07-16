--[[
     многократный вызов ToUnicodeEx вызывает вылет LuaMacro, однократный - репорт о баге на выходе из
     фара
]]

  	local ffi = require("ffi")
	ffi.cdef[[
	 int ToUnicodeEx(
		int wVirtKey,
		int wScanCode,
	    const char *lpKeyState,
  		char *pwszBuff,
  		int cchBuff,
  		int wFlags,
  		long int dwhkl
	);

	bool GetKeyboardState(
  		char * lpKeyState
	);

	long GetKeyboardLayout(
  		long idThread
	);

	int MapVirtualKeyExW(
	  int uCode,
	  int uMapType,
	  long dwhkl
	);

	bool SetKeyboardState(
  		char *lpKeyState
	);
]]

	local buff = ffi.new("char[20]")
	local keybState = ffi.new("char[256]")
	local kbdl = ffi.C.GetKeyboardLayout(0)
	local gksResult = ffi.C.GetKeyboardState(keybState)

	-- A
	local virtKey = 65
	local virtScan = 30

-- http://msdn.microsoft.com/en-us/library/windows/desktop/ms646322%28v=vs.85%29.aspx

	-- 68748313 is RU
	local uniInt = ffi.C.ToUnicodeEx(virtKey, virtScan,
		keybState, buff, 20, 0, 68748313)

	far.Show(" chars saved to buff: "..tonumber(uniInt))
	if (uniInt > 0) then
	 far.Show(" First two bytes of the buffer: "..buff[0].."  "..buff[1],
	 		  " As a number: "..buff[0]+buff[1]*256,
	 		  " As a unicode(utf8) char: ".. unicode.utf8.char(buff[0]+buff[1]*256))
	 local x = ffi.string(buff)
	 far.Show(win.Utf16ToUtf8(x))
	end
