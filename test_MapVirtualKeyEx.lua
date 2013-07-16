--[[
     эта куета мапит только в английскую раскладку
]]

  	local ffi = require("ffi")
	ffi.cdef[[

	int MapVirtualKeyExW(
	  int uCode,
	  int uMapType,
	  long dwhkl
	);
]]

	-- A
	local virtKey = 65
	local virtScan = 30

	-- 68748313 is RU
	local uniInt = ffi.C.MapVirtualKeyExW(virtKey, 2, 68748313) -- map mode MAPVK_VK_TO_CHAR

	if (uniInt == 0) then
		far.Show ("Translation failed")
	else
		far.Show(tonumber(uniInt))
	end
