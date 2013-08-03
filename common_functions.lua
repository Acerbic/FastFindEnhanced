--
-- this module contains some not ffind-specific functions to help working with Far API
--

local common_functions = {}
local _F = far.Flags

--[[
Set value for a dialog item (field [10] of FarDialogItem)

Params: hDlg,
		itemIndex,
		newValue

Returns: true on success
         false on failure
]]
function common_functions.set_dialog_item_data(hDlg, itemNum, data)
    local inputField = far.GetDlgItem(hDlg, itemNum);
    if (not inputField) then return false end
    inputField[10] = data;
    return far.SetDlgItem(hDlg,itemNum,inputField);
end

--[[
Get value of a dialog item
Params: hDlg,
		itemIndex

Returns: value
         nil on falure
]]
function common_functions.get_dialog_item_data(hDlg, itemNum)
    local inputField = far.GetDlgItem(hDlg, itemNum);
    return inputField and inputField[10];
end

--[[ 
Load a named QWORD setting from Far's database, check agains a constraint (>=1)
and assing default_value if something is wrong

params: name - (string) name of the setting to load
        defaultValue - if setting is out of range or isn't defined, this value is returned
        constraint - a maximum value for the setting (a number)

returns: the value of loaded setting
]]
function common_functions.load_setting(name, defaultValue, constraint)
    local settingsObj = far.CreateSettings ()
    local setting = settingsObj:Get(0, name, _F.FST_QWORD)

    setting = setting and setting <= constraint and setting or defaultValue
    -- if you are like "whaa...?" after the line above, then welcome to Lua, son.

    far.FreeSettings ( settingsObj )
    return setting
end

return common_functions