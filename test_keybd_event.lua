--[[
     работает!
]]

  	local ffi = require("ffi")
	ffi.cdef[[

	void keybd_event(
	  unsigned char bVk,
	  unsigned char bScan,
	  unsigned long dwFlags,
	  unsigned long dwExtraInfo
	);
]]

	-- A
	local virtKey = 65
	local virtScan = 30

	ffi.C.keybd_event(virtKey, virtScan, 0, 0)
	ffi.C.keybd_event(virtKey, virtScan, 2, 0)
