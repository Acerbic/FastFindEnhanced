local ffind = {}

local le = require ("le"); -- for occasional debugging

local ffi = require("ffi")
ffi.cdef[[
	void keybd_event(
		unsigned char bVk,
		unsigned char bScan,
		unsigned long dwFlags,
		unsigned long dwExtraInfo
	);

	unsigned int GetKeyState(unsigned int nVirtKey);

	unsigned int MapVirtualKeyW(
		unsigned int uCode,
		unsigned int uMapType
	);
]]

local common = require ("common_functions")

ffind.dlgGUID="{a1770ccc-5933-4661-bc8c-53192d0c06fa}"

-- these variables are to communicate with the user of the "ffind" module.
ffind.firstRun = false
ffind.dieSemaphor = false
ffind.resendKey = nil

local dontBlinkPlease = false
local _F = far.Flags
local width = 36; --dialog width

-- note that search (shorter or not) is different in that it process FULL name, where possible,
--  not only the part after last "/"

local optShorterSearch = true
local optPanelSidePosition = true
local optDefaultScrolling = false
local optForceScrollEdge = 0.08 -- [0.0-0.5] 0.5 for always(default) scroll, 0.0 for minimum scroll
local optUseXlat = true


    --TODO predict-skipping: if all items found for current pattern share the same next chars, they might be skipped
    --TODO auto bilingual guess (xlat pattern if no matches for current lang)
    --TODO prev/next items lists hovering

    --TODO Alternative dialog skins
    --TODO (prob never) "overlay mask" mode for minimalistic skin

    --TODO KEY_OP_XLAT KEY_OP_PLAINTEXT??
    --TODO (minor) make dialog re-positioning (and pattern matching?) when it is shown, not closed?

--[[
Get a list of items visible on active panel

returns: array of PluginPanelItem: {[1] = item1, [2] = item2...}
         this array might be empty  {}
]]
local function get_apanel_items()
    local totalItems = panel.GetPanelInfo(nil,1).ItemsNumber;
    local items = {}
    for i = 1,totalItems do
        items[i] = panel.GetPanelItem(nil,1,i)
    end
    return items
end

--[[
Compiles a search pattern and parses it for "onlyFolders" flag

Params: pattern (string)

returns: regexObject (compiled pattern), onlyFolders(boolean)
]]
local function prepare_pattern(pattern)
    local regexPattern = pattern
    local onlyFolders = false

    -- special meaning of a single trailing slash or backslash
    if (regexPattern:sub(-1, -1) == "\\" or regexPattern:sub(-1, -1)=="/") then
        regexPattern = regexPattern:sub(1,-2)
        onlyFolders = true;
    end

    regexPattern = regex.gsub(regexPattern, "([()|^$.[{+\\]\\/\\\\])","\\%1")
    regexPattern = regex.gsub(regexPattern,"[?]",".")
    regexPattern = regex.gsub(regexPattern,"[*]",".*")

    if (regexPattern:sub(1,2)==".*") then
        --remove 1st '.*' if any (otherwise all matchings will be found from pos 1)
        regexPattern = regexPattern:sub(3,-1)
        else
        --force matching from the beginning
        regexPattern = "^"..regexPattern
    end


    return regex.new(regexPattern, "i"), onlyFolders
end

--[[
Calculate new cursor position in the active panel
params: pattern of search (string),
		direction of search (one of values: "current_or_next", "current", "next", "first", "last", "prev")

returns: newPositionIndex(nil/false or integer), countBefore, countAfter
]]
local function get_new_cursor_position(pattern, direction)
    local items = get_apanel_items()
    local refInd = panel.GetPanelInfo(nil,1).CurrentItem;

    local regexObject, onlyFolders = prepare_pattern(pattern)
	local countBefore, countAfter = 0, 0
	local firstMatched, lastMatched, previousMatched, nextMatched, currentMatched = nil, nil, nil, nil, nil

    for i,item in ipairs(items) do
        local start = regexObject:find(item.FileName, 1)
        if (start and item.FileName~=".." and (not onlyFolders or item.FileAttributes:find("d"))) then
        	firstMatched = firstMatched or i
        	lastMatched = i
            if (i<refInd) then
        		previousMatched = i
                countBefore = countBefore +1
            elseif (i>refInd) then
                countAfter = countAfter +1
        		nextMatched = nextMatched or i
            else
            	currentMatched = i
            end
        end
    end

    if (not firstMatched) then return nil, 0, 0 end  -- no matching at all

    -- below this line firstMatched is not nil and lastMatched is not nil

    local countTotal = countBefore + countAfter + (currentMatched and 1 or 0)

    if (currentMatched and (direction=="current_or_next" or direction=="current")) then
    	return currentMatched, countBefore, countAfter

    elseif (direction=="current_or_next" or direction=="next") then

    	if (nextMatched) then
    		return nextMatched, countTotal - countAfter , countAfter -1
    	else
    		return firstMatched, 0, countTotal -1  --rollover
    	end

    elseif (direction=="prev") then

    	if (previousMatched) then
    		return previousMatched, countBefore -1, countTotal - countBefore
        else
    		return lastMatched, countTotal -1, 0   --rollover
    	end

    elseif (direction=="last" and lastMatched) then
    	return lastMatched, countTotal -1, 0

    elseif (direction=="first" and firstMatched) then
   		return firstMatched, 0, countTotal -1

    end

    return nil, 0, 0   -- direction not recognized
end

--[[
A variant of "get_new_position" with precedence given to files with matching portion
closer to the beginning of the filename. Only has effect if direction is "current_or_next"
(initial search), otherwise it calls get_new_position.

params: pattern (string), this function will give results different from 'get_new_position' only if pattern starts with '*'
		direction of search (one of values: "current_or_next", "next", "current", "first", "last", "prev")

returns: newPositionIndex(nil or integer), countBefore, countAfter
]]
local function get_new_cursor_position_shorter_start(pattern, direction)
    if (direction ~= "current_or_next" or pattern:len() < 2) then
        return get_new_cursor_position(pattern, direction)
    end

    local items = get_apanel_items()
    local itemIndex, matchDistance, countBefore, countTotal = nil, -1, 0, 0
    local regexObject, onlyFolders = prepare_pattern(pattern)

    local refInd = panel.GetPanelInfo(nil,1).CurrentItem;
    local refStart = regexObject:find(items[refInd].FileName, 1)    -- current item
    if (refStart and (not onlyFolders or items[refInd].FileAttributes:find("d"))) then
        itemIndex = refInd;
        matchDistance = refStart
    end --don't move from current if its already shortest match

    for i,item in ipairs(items) do
        local start = regexObject:find(item.FileName, 1)
        if (start and item.FileName~=".." and (not onlyFolders or item.FileAttributes:find("d"))) then
            if (start<matchDistance or matchDistance==-1 or i==itemIndex) then
                countBefore = countTotal
                itemIndex = i
                matchDistance = start
            end
            countTotal = countTotal +1
        end
    end
    return itemIndex, countBefore, countTotal - countBefore -1

end

--[[
Simulates a new key pressed combo based on current key pressed, only without Alt being pressed.

params: inprec - current key event
returns: char that un-alted key would produce or "Ignore"
]]
local function un_alt (inprec)

	if (optUseXlat) then
		local shiftTable = {     -- this is for english keyboard, i'm making an assumption here.
		["`"]  =  "~",
		["1"]  =  "!",
		["2"]  =  "@",
		["3"]  =  "#",
		["4"]  =  "$",
		["5"]  =  "%",
		["6"]  =  "^",
		["7"]  =  "&",
		["8"]  =  "*",
		["9"]  =  "(",
		["0"]  =  ")",
		["-"]  =  "_",
		["="]  =  "+",
		["["]  =  "{",
		["]"]  =  "}",
		[";"]  =  ":",
		["'"]  =  "\"",
		[","]  =  "<",
		["."]  =  ">",
		["/"]  =  "?",
		["\\"] =  "|"
		}

		local _, _, shift, key = far.InputRecordToName(inprec, true)
		if (key:len() > 1) then
			return key -- do not touch special non-character keys like "F3" or "BS"
		end

		local macroResults = far.MacroExecute("return Far.KbdLayout()",0) -- fml
		if (macroResults.n <1) then
			return "Ignore" -- failed to acquire kbdlayout, just sweep this key under the rug
		end
		local kbdL = bit64.band(macroResults[1], 0xFFFF) -- lower word for base language of the keyboard layout

		local resultChar = shift and shiftTable[key] or key
		if (kbdL == 0x0409) then --U.S. English
			resultChar =  resultChar -- no more actions required
		else
			resultChar = far.XLat( resultChar )
		end

		return far.LLowerBuf(resultChar) -- lower case it (native FastSearch behavior)
	else
	-- work around to drop alt ( I failed to make mapping vk -> char work, so this is what is left)
	    local rAlt = false
	    local lAlt = false

	    local vkLAlt = 0xA4
	    local vkRAlt = 0xA5
	    local scLAlt = ffi.C.MapVirtualKeyW(0xA4, 0)
	    local scRAlt = ffi.C.MapVirtualKeyW(0xA5, 0)

		-- check  if LAlt is pressed
		if (bit64.band(ffi.C.GetKeyState(vkLAlt), 0x80) > 0) then
			lAlt = true
			ffi.C.keybd_event(vkLAlt, scLAlt, 2, 0) -- lALT  unpress
		end

		-- check if RAlt is pressed
		if (bit64.band(ffi.C.GetKeyState(vkRAlt), 0x80) > 0) then
			rAlt = true
			ffi.C.keybd_event(vkRAlt, scRAlt, 3, 0) -- rALT  unpress
		end

		-- I don't have a slightiest of clue how this will interact with fancy input locales, like hierogliphics
		ffi.C.keybd_event(inprec.VirtualKeyCode, inprec.VirtualScanCode, 0, 0)
		ffi.C.keybd_event(inprec.VirtualKeyCode, inprec.VirtualScanCode, 2, 0)

		if (rAlt) then
			ffi.C.keybd_event(vkRAlt, scRAlt, 1, 0) -- rALT repress
		end

		if (lAlt) then
			ffi.C.keybd_event(vkLAlt, scLAlt, 0, 0) -- lALT repress
		end

		return "Ignore"
	end
-- My original plan was to convert Alt[Shift]Key -> char in-house with respect to CAPS and
--   current keyboard locale and without build-in XLAT from Far (I don't trust it, tbh).
-- BUT I faced a number of issues:

-- GetKeyboardLayout() doesn't read a correct layout from "current" thread. Instead, you must
--   locate a hosting 'conhost.exe' thread (there is code for that on the net, but its not trivial
--   and possibly needs UAC approval)
-- Alternatively, I was thinking about using 'lua-macro-code-eval' call to get Far.KbdLayout()
--   of MacroAPI kit from macro context of Far execution

-- MapVirtualKeyEx() does not work, seemingly
-- ToUnicodeEx() translates a key just fine but creates some kind of a leak in LuaMacro,
--   causing Far to crash later (or you can see an error message in console after Far terminates)
end


--[[
Convert InputRecord to a key name relevant to this dialog input

params: inputRecord

returns: keyName - as if pressed without Alt

         + some special key names:
         "CtrlV" in response to "R?CtrlV" or "ShiftIns"
         "Alt(Up|Down|Home|End)" in response to "R?Alt(Up|Down|Home|End)"
         "\" for BackSlash
         "Ignore" if the key is to be ignored
         "Default" for default processing of the key by Far
         "Terminate" to close this dialog and pass the key pressed through to Far
]]
local function get_dry_key (inprec)
    -- OK. First draft: ignoring XLat and multilangual complications
    local ctrl,alt,shift,key = far.InputRecordToName (inprec, true)
    local comboKey = far.InputRecordToName (inprec)

	-- bare modifier or *lock key
    if (not key or key=="CapsLock" or key=="NumLock" or key=="ScrollLock") then
    	return "Default"
    end

    if (comboKey=="ShiftIns" or comboKey=="CtrlV" or comboKey=="RCtrlV" or
        comboKey=="ShiftNumpad0") then
        return "CtrlV"
    end

    if (ctrl and key=="Enter") then
        return shift and "AltUp" or "AltDown"
    end
    if (ctrl) then return nil end -- return nil if Ctrl*Key
    if (alt and not shift and ((key=="Up") or (key=="Down") or (key=="Home") or (key=="End"))) then
        return "Alt"..key
    end
    if (key == "Multiply") then return "*" end -- (R?Alt)?(Shift)?numMul
    if (not shift and key == "BackSlash") then return "\\" end -- (R?Alt)?BackSlash

    -- need to filter out all non-filename keypresses, like F1 or LeftArrow, Tab
	if (inprec.UnicodeChar:byte()==0 or key=="Enter" or key=="Tab") then
		return "Terminate"
	end


    if (not alt) then return key end -- return Key if ShiftKey or Key

    -- below this we have only Alt(Shift)?Key combinations
     return un_alt (inprec)
end

--[[
This will put given values to dialog elements
params: hDlg, pattern, countBefore, countAfter
]]
local function update_dialog_data (hDlg, pattern, countBefore, countAfter)
    if ( countAfter > 999 ) then countAfter = 999 end
    if ( countBefore > 999 ) then countBefore = 999 end
    common.set_dialog_item_data(hDlg, 2, pattern);
    common.set_dialog_item_data(hDlg, 3, string.format("%03d",countBefore))
    common.set_dialog_item_data(hDlg, 4, string.format("%03d",countAfter))
end

--[[
Figure out a number of file-item lines a vertical column of a panel can hold

params: pRect - panel rectangle coords, as in PanelInfo.PanelRect returned by GetPanelInfo(..) call

returns: itemLinesPerColumn (integer), panelLinesSkipTop (integer), panelLinesSkipBottom (integer)
]]
local function get_lines_per_column(pRect)
    local panelLinesSkipTop = 0
    local panelLinesSkipBottom = 0

	local obj = far.CreateSettings("far")
	if (obj:Get(_F.FSSF_PANELLAYOUT, "ColumnTitles", FST_DATA) > 0) then
		panelLinesSkipTop = 1
	end
	if (obj:Get(_F.FSSF_PANELLAYOUT, "StatusLine", FST_DATA) > 0) then
		panelLinesSkipBottom = 2
	end
	far.FreeSettings ()

    --how many item lines fit in panel (by height)
    return 	pRect.bottom - pRect.top -1 -panelLinesSkipTop -panelLinesSkipBottom,
    		panelLinesSkipTop,
            panelLinesSkipBottom;
end

--[[ get new position of the dialog to be on a side of active panel across the new cursor position
note: will work properly only after panel was scrolled to make newPos visible.

params: hDlg (dialog handle)
returns: {X=integer, Y=integer} (table with dialog's left-top coordinates)
]]
local function calc_new_side_dialog_coords(hDlg)
    local pRect = panel.GetPanelInfo(nil,0).PanelRect; -- passive panel!
    local topItem = panel.GetPanelInfo(nil,1).TopPanelItem
    local curItem = panel.GetPanelInfo(nil,1).CurrentItem

    local x
    if (bit64.band(panel.GetPanelInfo(nil,0).Flags, _F.PFLAGS_PANELLEFT) >0) then
        -- passive on the left side
        x = pRect.right-width+1
    else
        x = pRect.left
    end

    --how many item lines fit in panel (by height)
    local itemLinesPerColumn, panelLinesSkipTop = get_lines_per_column(pRect)
    local overTop = curItem-topItem -- 0+

    local y = overTop % itemLinesPerColumn + panelLinesSkipTop + pRect.top
    return {X = x, Y = y}
end

--[[
Panel scrolling and cursor position calculation subroutine

params: newPos (index of the item to move cursor to)
returns: newTopItem (top element after scrolling)
]]
local function calc_new_panel_top_item(newPos)
    local newTopItem = panel.GetPanelInfo(nil,1).TopPanelItem -- default to current top item

    if (newPos ~= panel.GetPanelInfo(nil,1).CurrentItem) then
        local pRect = panel.GetPanelInfo(nil,1).PanelRect;
        local totalItemLines = get_lines_per_column(pRect)
        if (optDefaultScrolling) then
            -- center current element in the 1st column if scrolling is possible (FAR standard behavior)
            newTopItem = newPos-totalItemLines/2
        else
            -- alternative scrolling

        	-- in case of multiple filename columns
            local panelMode = panel.GetColumnTypes(nil,1)
            local numNameColumns = 0
            local from, to = 1, 0
            while (from) do
                 from, to = regex.find( panelMode, "N[^,]*", from, "i" )
                 if (from) then
                    numNameColumns = numNameColumns +1
                    from = to +1
                 end
            end

            totalItemLines = totalItemLines * numNameColumns

            -- ==0 if newPos already in center, ==0.5 if newPos on the edge of the panel
            -- >0.5 if off screen
            local relOffset = (newTopItem + totalItemLines/2 - newPos)/totalItemLines

            local edgePercent = optForceScrollEdge / numNameColumns --scale edge according to number of columns
            if (math.abs(relOffset)+edgePercent>0.5) then -- need to scroll
                if (math.abs(relOffset)>0.5) then
                    -- big scroll and center
                    newTopItem = newPos-totalItemLines/2
                else
                    -- mini scroll and put on edge
                    if (relOffset>0) then
                        newTopItem = newPos - edgePercent*totalItemLines
                    else
                        newTopItem = newPos + edgePercent*totalItemLines - totalItemLines
                    end
                end
            end
        end
    end
    return newTopItem
end

--[[
Do works of keyboard input to the dialog input field. Change pattern, check it against panel,
update panel and dialog accordingly

params: hDlg, inputRec (InputRecord table)

returns: true or false to be returned to Far from dlgProc
]]
function ffind.process_input(hDlg, inputRec)
    local dryKey = get_dry_key(inputRec)
    local pattern = common.get_dialog_item_data(hDlg, 2)
    local newPattern = pattern

    local searchDirection = "current_or_next" -- default search mode

    if (dryKey == "CtrlV") then -- special occasion covering all insertion keys
        local paste = far.PasteFromClipboard ()
        dontBlinkPlease = true
        for i = 1, paste:len()-1 do --all but the final one
            ffind.process_input (hDlg, far.NameToInputRecord(paste:sub(i,i)))
        end
        dontBlinkPlease = nil

        dryKey = paste:sub(-1,-1) -- process the final char as usuall input
	end

    -- omfg. LUA HAS NO SWITCH STATEMENT... Shit got serious...
    if (dryKey == "Default") then
        return false
    elseif (dryKey == "Ignore") then
    	return true

    elseif (dryKey == "AltHome") then
        searchDirection = "first"
    elseif (dryKey == "AltDown") then
        searchDirection = "next"
    elseif (dryKey == "AltUp") then
        searchDirection = "prev"
    elseif (dryKey == "AltEnd") then
        searchDirection = "last"

    elseif (dryKey == "Space") then
        newPattern = newPattern.." "
    elseif (dryKey == "BS") then
        newPattern = pattern:sub(1, -2)
        searchDirection = "current"

    elseif (dryKey == "Esc") then
        ffind.dieSemaphor = true;
        return false -- close naturally by Esc

    -- dryKey is a simple character.
    elseif (type(dryKey) == "string" and dryKey:len() == 1) then
        if (pattern:sub(-1,-1) == '*' and ((dryKey=='*') or (dryKey=='?'))) then
            return true -- ignore '**' and '*?'
        end
        newPattern = pattern..dryKey

    else
        -- close dialog on every other key  or dryKey == nil
        -- and pass the key over to the panel
        ffind.dieSemaphor = true;
        ffind.resendKey = far.InputRecordToName(inputRec)

        far.SendDlgMessage(hDlg, _F.DM_CLOSE, -1, 0) -- force close
        return true
    end

    -- pattern was modified. now search for newPattern in file list
    local newPos, countBefore, countAfter

    if (optShorterSearch) then
        newPos, countBefore, countAfter = get_new_cursor_position_shorter_start(newPattern, searchDirection)
    else
        newPos, countBefore, countAfter = get_new_cursor_position(newPattern, searchDirection)
    end

    if (not newPos) then
        return true; -- new input does not match anything, ignore this key input
    end

    update_dialog_data(hDlg, newPattern, countBefore, countAfter)

    local newTopItem = calc_new_panel_top_item(newPos)
    panel.RedrawPanel(nil, 1, {CurrentItem=newPos, TopPanelItem=newTopItem})

    -- must move dialog AFTER panel scrolled to the element
    if (optPanelSidePosition) then
        far.SendDlgMessage(hDlg, _F.DM_MOVEDIALOG, 1, calc_new_side_dialog_coords(hDlg))
    end

    if (not dontBlinkPlease) then
        far.SendDlgMessage (hDlg, _F.DM_CLOSE, -1, 0) -- blink the dialog to update panel views
    end
    return true
end


--[[
Dialog is placed in the bottom-center of an active panel. If it does not fit then it is
"snapped" to a closer edge of the screen

Params: width, height - dialog size

returns: left,top,right,bottom
]]
local function get_std_dialog_rect(width, height)
    local pRect = panel.GetPanelInfo(nil,1).PanelRect;
    local farRect = far.AdvControl (_F.ACTL_GETFARRECT, 0, 0)
    local bottom = pRect.bottom + height - 1
    if (bottom > farRect.Bottom) then
        bottom=farRect.Bottom -- limit
    end
    local top = bottom - height + 1

    local pWidth = pRect.right - pRect.left +1
    local left = pRect.left + math.floor((pWidth-width)/2)
    if (left<farRect.Left) then left = farRect.Left; end
    local right = left + width-1
    if (right > farRect.Right) then
        right = farRect.Right
        left = right - width +1
    end
    -- I ignore a case when farRectWidth < width

    return left,top,right,bottom
end

--[[
Event handler for Fast Find dialog.
Standard dlgProc function interface
]]
function ffind.dlg_proc (hDlg, msg, param1, param2)
    if (ffind.firstRun) then
        ffind.firstRun = nil
        far.SendDlgMessage(hDlg, _F.DM_EDITUNCHANGEDFLAG, 2, 0) -- drop "unchanged"
        far.SendDlgMessage (hDlg, _F.DM_CLOSE, -1, 0) -- blink the dialog to update panel views
        return
    end

    if (msg == _F.DN_CTLCOLORDLGITEM) then
        if (param1==3) then param2[1].ForegroundColor = 10; return param2; end
        if (param1==4) then param2[1].ForegroundColor = 12; return param2; end
    elseif (msg == _F.DN_CONTROLINPUT) then
        if (param1 == 2) then
            if ((param2.EventType ~= _F.KEY_EVENT) and (param2.EventType ~= _F.FARMACRO_KEY_EVENT)) then
                return false
            end

            return ffind.process_input(hDlg, param2) -- pass results to Far
        end
    end
end

function ffind.create_dialog()
	local dialogItems = {
--[[1]]         {_F.DI_DOUBLEBOX  ,0,0,width-1,2,0,0,0,_F.DIF_LEFTTEXT,"Fast Find"}
--[[2]]        ,{_F.DI_EDIT       ,2,1,width-3,1,0,0,0,0,""}
--[[3]]        ,{_F.DI_TEXT       ,width-4,0,width-2,0,0,0,0,0,"000"}
--[[4]]        ,{_F.DI_TEXT       ,width-4,2,width-2,2,0,0,0,0,"000"}
--[[5]]        ,{_F.DI_TEXT       ,width-5,0,width-5,0,0,0,0,0,""}
--[[6]]        ,{_F.DI_TEXT       ,width-5,2,width-5,2,0,0,0,0,""}
	}

    local left,top,right,bottom = get_std_dialog_rect(width,3)
	local hDlg = far.DialogInit(ffind.dlgGUID,left,top,right,bottom,nil,dialogItems,
		_F.FDLG_KEEPCONSOLETITLE + _F.FDLG_SMALLDIALOG + _F.FDLG_NODRAWSHADOW ,
        ffind.dlg_proc)

    -- load settings 
    optShorterSearch     = common.load_setting("optShorterSearch", 1, 1)
    optPanelSidePosition = common.load_setting("optPanelSidePosition", 1, 1)
    optDefaultScrolling  = common.load_setting("optDefaultScrolling", 0, 1)
    optForceScrollEdge   = common.load_setting("optForceScrollEdge", 16, 100)
    optUseXlat           = common.load_setting("optUseXlat", 0, 1)

    -- convert settings to local options
	optShorterSearch     = optShorterSearch>0
	optPanelSidePosition = optPanelSidePosition>0
	optDefaultScrolling  = optDefaultScrolling>0
	optForceScrollEdge   = optForceScrollEdge/200
	optUseXlat           = optUseXlat>0
    
    return hDlg
end

--[[

              1         2         3
    012345678901234567890123456789012345

  0 ╔ Fast Find ═══════════════════000╗     ─═══─ 00┐                            ─═══─ 00┐
  1 ║ ................................ ║   *]-Fast Find     *]=0000FastFind=-  ...........
  2 ╚══════════════════════════════000╝   ──══──  00┘                          ──══──  00┘

    012345678901234567890123456789012345

]]


return ffind