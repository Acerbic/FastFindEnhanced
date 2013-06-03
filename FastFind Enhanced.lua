local _F = far.Flags
local precedingAst = true --opt

function export.GetPluginInfo ()

  	return {
      Flags = _F.PF_NONE,

      PluginMenuStrings = {"FastFind Enhanced"},
      PluginMenuGuids = "8195eb6d-9651-4d60-9a16-ed0d90e20be7"
	}
end

function export.Open( openFrom, Guid, Item)
--[[
local sql = require "ljsqlite3"

local fname = win.GetEnv("farprofile").."\\generalconfig.db"
local conn = assert(sql.open(fname, "ro"))

local t = conn:exec("SELECT `value` FROM general_config WHERE key=='Panel.Layout' AND name=='ColumnTitles'")

local arr={}
for i in ipairs(t.value) do
--  local v=type(t.value[i])=="string" and '"'..t.value[i]..'"' or t.value[i]
  --arr[i] = {text=("%-32s │ %s"):format(t.key[i].."."..t.name[i], tostring(v))}
  	far.Show(i, t.value[i])
end

--table.sort(arr, function(a,b) return a.text<b.text end)
--far.Menu({Title="database",Flags="FMENU_SHOWAMPERSAND"}, arr)

conn:close()
]]

    package.loaded.ffind = nil
    local ffind = require "ffind"

    _G[ffind.dlgGUID] = _G[ffind.dlgGUID] or {}
    local hDlg = ffind.create_dialog()

    -- !! workaround some wild bug
    _G[ffind.dlgGUID].firstRun = true
    far.DialogRun(hDlg); -- run and close. Otherwise calls to "process_input" will lock input field into "unchanged" state

	-- initialize dialog with input string
    if (precedingAst) then
    	local pattern = "*"
	    while (#pattern >0) do
	        local inprec = far.NameToInputRecord(pattern:sub(1,1))
	        pattern = pattern:sub(2,-1)
	        ffind.process_input(hDlg, inprec)
	    end
	end

	--main loop
    while (not _G[ffind.dlgGUID].dieSemaphor) do
        far.DialogRun(hDlg);
    end

    far.DialogFree(hDlg);

    if (_G[ffind.dlgGUID].resendKey) then
    	far.MacroPost ('Keys("'.._G[ffind.dlgGUID].resendKey..'")') -- note quotes usage, resendKey may contain <'> but not <"> ( <"> is only generated when Alt and Control are not pressed, and is checked agains filename inside a dialog )
    end

    _G[ffind.dlgGUID] = nil;
end