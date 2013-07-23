local _F = far.Flags
local ffind_cfg = {}
ffind_cfg.dlgGUID = "{30ed409d-b5e6-4ed0-a3ef-d1757a36b6f5}"

-- TODO guard "Scroll margin" input field for 0-100 values only
-- TODO disable "Scroll margin" field if "Better scrolling" is not set

--[[
Event handler for Fast Find configuration dialog.
Standard dlgProc function interface
]]
function ffind_cfg.dlg_proc (hDlg, msg, param1, param2)
end

--[[
Set value for a dialog item (field [10] of FarDialogItem)

Params: hDlg,
		itemIndex,
		newValue

returns: true on success
         false on failure
]]
local function set_dialog_item_data(hDlg, itemNum, data)
    local inputField = far.GetDlgItem(hDlg, itemNum);
    if (not inputField) then return false end
    inputField[10] = data;
    far.Show("!")
    return far.SetDlgItem(hDlg,itemNum,inputField);
end

--[[
Set 'selected' field for a dialog item (field [6] of FarDialogItem)

Params: hDlg,
		itemIndex,
		selectedState

returns: true on success
         false on failure
]]
local function set_dialog_item_selected(hDlg, itemNum, selectedState)
    local inputField = far.GetDlgItem(hDlg, itemNum);
    if (not inputField) then return false end
    inputField[6] = selectedState;
    return far.SetDlgItem(hDlg,itemNum,inputField);
end


--[[ load a named setting from Far's database, check agains a constraint (1 .. )
and assing default_value if something is wrong

params: name - name of the setting to load
        defaultValue - if setting is out of range or not defined, this is returned
        constraint - a maximum value for the setting (a number)

returns: the value of loaded setting
]]
local function load_setting(name, defaultValue, constraint)
    local settingsObj = far.CreateSettings ()
    local setting = settingsObj:Get(0, name, _F.FST_QWORD)

    setting = setting and setting <= constraint or defaultValue

    far.FreeSettings ( settingsObj )
    return setting
end

--[[
Creates a Far dialog object for FastFind configuration dialog,

returns: hDlg - handle for this dialog. far.DialogFree() MUST be called sometime downstream.
]]
function ffind_cfg.create_dialog()

    -- load settings and assign defaults if not set
    local optPrecedingAsterisk = load_setting("optPrecedingAsterisk", 1, 1)
    local optShorterSearch     = load_setting("optShorterSearch", 1, 1)
    local optPanelSidePosition = load_setting("optPanelSidePosition", 1, 1)
    local optDefaultScrolling  = load_setting("optDefaultScrolling", 0, 1)
    local optForceScrollEdge   = load_setting("optForceScrollEdge", 16, 100)
    local optUseXlat           = load_setting("optUseXlat", 0, 1)

    -- convert settings to dialog values
	local chkPrecedingAsterisk = optPrecedingAsterisk 
	local chkShorterSearch = optShorterSearch
	local chkPanelAtBottom = 1 - optPanelSidePosition
	local chkBetterScrolling = 1 - optDefaultScrolling
	local inpScrollMargin = tostring(optForceScrollEdge)
	local chkUseXlat = optUseXlat

	local dialogItems = {
--[[1]]         {_F.DI_DOUBLEBOX  ,0,0,41,12,       0,0,0,0,"FastFind Enhanced configuration"}

--[[2]]        ,{_F.DI_CHECKBOX   ,2,2,0,2,         chkPrecedingAsterisk,0,0,0,"Auto '*' as 1st char"}
--[[3]]        ,{_F.DI_CHECKBOX   ,2,3,0,3,         chkShorterSearch,0,0,0,"Favor shorter matches"}
--[[4]]        ,{_F.DI_CHECKBOX   ,2,4,0,4,         chkPanelAtBottom,0,0,0,"Put dialog on the bottom"}
--[[5]]        ,{_F.DI_CHECKBOX   ,2,6,0,6,         chkBetterScrolling,0,0,0,"Better scrolling algorithm"}

--[[6]]        ,{_F.DI_TEXT       ,5,7,0,7,         0,0,0,0,"Scroll margin:"}
--[[7]]        ,{_F.DI_EDIT       ,20,7,23,7,       0,0,"999",_F.DIF_MASKEDIT,inpScrollMargin,3}
--[[8]]        ,{_F.DI_TEXT       ,24,7,1,7,        0,0,0,0,"%"}

--[[9]]        ,{_F.DI_CHECKBOX   ,2,9,0,9,         chkUseXlat,0,0,0,"Use XLat for non-English keyboards"}

--[[10]]       ,{_F.DI_BUTTON     ,9,11,0,11,       0,0,0,_F.DIF_DEFAULTBUTTON,"OK"}
--[[11]]       ,{_F.DI_BUTTON     ,23,11,0,11,      0,0,0,0,"Cancel"}

	}

    local hDlg = far.DialogInit(ffind_cfg.dlgGUID, -1, -1, 42, 13, nil, dialogItems,
		_F.FDLG_KEEPCONSOLETITLE,
        ffind_cfg.dlg_proc)

    return hDlg
end

function ffind_cfg.save_settings(hDlg)
    -- convert dialog values to settings
    local optPrecedingAsterisk = far.GetDlgItem(hDlg, 2)[6]
    local optShorterSearch     = far.GetDlgItem(hDlg, 3)[6]
    local optPanelSidePosition = 1- far.GetDlgItem(hDlg, 4)[6]
    local optDefaultScrolling  = 1- far.GetDlgItem(hDlg, 5)[6]
    local optForceScrollEdge   = tonumber(far.GetDlgItem(hDlg, 7)[10])
    local optUseXlat           = far.GetDlgItem(hDlg, 9)[6]

    local settingsObj = far.CreateSettings ()

    -- save settings
    settingsObj:Set(0, "optPrecedingAsterisk",  _F.FST_QWORD, optPrecedingAsterisk)
    settingsObj:Set(0, "optShorterSearch",      _F.FST_QWORD, optShorterSearch)
    settingsObj:Set(0, "optPanelSidePosition",  _F.FST_QWORD, optPanelSidePosition)
    settingsObj:Set(0, "optDefaultScrolling",   _F.FST_QWORD, optDefaultScrolling)
    settingsObj:Set(0, "optForceScrollEdge",    _F.FST_QWORD, optForceScrollEdge)
    settingsObj:Set(0, "optUseXlat",            _F.FST_QWORD, optUseXlat)

    far.FreeSettings ( settingsObj )
end

return ffind_cfg

--[[
     0         1         2         3         4
     012345678901234567890123456789012345678901

 0   ╔══════ Fast find enhanced: Cfg ═════════╗
 1   ║                                        ║
 2   ║ [x] Auto '*' as 1st char               ║
 3   ║ [x] Favor shorter matches              ║
 4   ║ [ ] Put dialog on the bottom           ║
 5   ║                                        ║
 6   ║ [x] Better scrolling algorithm         ║
 7   ║    Scroll margin: *** %                ║
 8   ║                                        ║
 9   ║ [ ] Use XLat for non-English keyboards ║
10   ║                                        ║
 1   ║        { OK }        [ Cancel ]        ║
 2   ╚════════════════════════════════════════╝

]]