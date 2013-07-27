-- TODO readme
-- TODO F1 help (HLF)
-- TODO Plugin.Call (...)
-- TODO fix macro/FastFind Enhanced macro.lua to reflect Plugin.Call
-- TODO "fck the police"
-- TODO rebuild *.dll to no longer export unneeded shit


local _F = far.Flags

function export.Configure(guid)
	package.loaded.ffind_cfg = nil
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

      PluginMenuStrings = {"FastFind Enhanced"},
      PluginMenuGuids = win.Uuid("8195eb6d-9651-4d60-9a16-ed0d90e20be7"),

      PluginConfigStrings = {"FastFind Enhanced"},
      PluginConfigGuids = win.Uuid("22595d6e-fc1e-4317-9935-5e9d3a39bea7")
	}
end

function export.Open(openFrom, guid, item)
    -- since we use a generic dll as a proxy Far thinks we export every function possible.
    if (openFrom == _F.OPEN_FINDLIST) then
        return nil
    end
local ffind
    ffind = require "ffind"

    if (openFrom == _F.OPEN_FROMMACRO) then
        require "le"(ffind.get_current_ffind_pattern())
        return
    end

    package.loaded.ffind = nil
    ffind = require "ffind"

    ffind.create_dialog()

	--main loop
    while (not ffind.dieSemaphor) do
        ffind.run_dialog()
    end
    ffind.dieSemaphor = nil

    ffind.free_dialog()

    if (ffind.resendKey) then
    	far.MacroPost ('Keys("'..ffind.resendKey..'")') -- note quotes usage,
    	--   resendKey may contain <'> but not <"> ( <"> is only generated when Alt and Control
    	--   are not pressed, and is checked against filenames inside the dialog)
    	ffind.resendKey = nil
    end

end