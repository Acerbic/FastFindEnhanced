local _F = far.Flags

function export.GetPluginInfo ()

  	return {
      Flags = _F.PF_NONE,

      PluginMenuStrings = {"FastFind Enhanced"},
      PluginMenuGuids = "8195eb6d-9651-4d60-9a16-ed0d90e20be7"
	}
end

function export.Open( openFrom, ...)
    package.loaded.ffind = nil
    local ffind = require "ffind"

    _G[ffind.dlgGUID] = _G[ffind.dlgGUID] or {}
    local hDlg = ffind.create_dialog()

    -- !! workaround some wild bug
    _G[ffind.dlgGUID].firstRun = true
    far.DialogRun(hDlg); -- run and close. Otherwise calls to "process_input" will lock input field into "unchanged" state

-- initialize dialog with input string
    local pattern = ffind.get_dialog_item_data(hDlg,2)
    ffind.set_dialog_item_data(hDlg,2,"")
    while (#pattern >0) do
        local inprec = far.NameToInputRecord(pattern:sub(1,1))
        pattern = pattern:sub(2,-1)
        ffind.process_input(hDlg, inprec)
    end

    while (not _G[ffind.dlgGUID].dieSemaphor) do
        far.DialogRun(hDlg);
    end

    far.DialogFree(hDlg);

    if (_G[ffind.dlgGUID].resendKey) then
        Keys(_G[ffind.dlgGUID].resendKey)
    end
    _G[ffind.dlgGUID] = nil;

end