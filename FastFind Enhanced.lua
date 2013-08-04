-- TODO F1 help (HLF)
-- TODO rebuild *.dll to no longer export unneeded shit

local _F = far.Flags
local hDlg = nil  --singleton

function export.Configure(guid)
--	package.loaded.ffind_cfg = nil
--    package.loaded.ffind = nil
	local ffind_cfg = require "ffind_cfg"

	local hDlg = ffind_cfg.create_dialog()
    
    local dlgReturnedValue = far.DialogRun(hDlg)
    if (dlgReturnedValue == 10) then
        ffind_cfg.save_settings(hDlg)
    end

    far.DialogFree(hDlg);

	return true -- success
end

function export.GetPluginInfo ()
  	return {
      Flags = _F.PF_NONE,

      PluginMenuStrings = {far.GetMsg(10)},
      PluginMenuGuids = win.Uuid("8195eb6d-9651-4d60-9a16-ed0d90e20be7"),

      PluginConfigStrings = {far.GetMsg(10)},
      PluginConfigGuids = win.Uuid("22595d6e-fc1e-4317-9935-5e9d3a39bea7")
	}
end

function export.Open(openFrom, guid, item)
    -- since we use a generic dll as a proxy Far thinks we export every function possible.
    if (openFrom == _F.OPEN_FINDLIST) then
        return nil
    end

    local ffind = require "ffind"
    -- if called from macro, pass the invoking key into ffind dialog
    local akeyPassed = nil

    -- command "2" - get current input string
    if (openFrom==_F.OPEN_FROMMACRO and item.n>=0 and item[1]==2) then
        return hDlg and ffind.get_current_ffind_pattern(hDlg)
    end

    -- command "1" - open with a starting char
    if (openFrom==_F.OPEN_FROMMACRO and item.n>=1 and item[1]==1 and item[2]) then
        akeyPassed = item[2]
    end

    if (hDlg) then return nil end -- singleton

    hDlg = ffind.create_dialog(akeyPassed)
    if (not hDlg) then return nil end

	--main loop
    while (not ffind.dieSemaphor) do
        far.DialogRun(hDlg)
    end
    ffind.dieSemaphor = nil

    far.DialogFree(hDlg)

    if (ffind.resendKey) then
    	far.MacroPost ('Keys("'..ffind.resendKey..'")') -- note quotes usage,
    	--   resendKey may contain <'> but not <"> ( <"> is only generated when Alt and Control
    	--   are not pressed, and is checked against filenames inside the dialog)
    	ffind.resendKey = nil
    end
    hDlg = nil
end