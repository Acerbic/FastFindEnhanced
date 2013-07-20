package.loaded.ffind_cfg = nil
local ffind_cfg = require("ffind_cfg")

local h = ffind_cfg.create_dialog()

if (h) then
	far.DialogRun(h)
	far.DialogFree(h)
end