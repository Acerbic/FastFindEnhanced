local ffind = {}

ffind.dlgGUID="{ACE12B1C-5FC7-E11F-1337-FA575EA12C14}"       -- fuck teh police

local _F = far.Flags
local bit = require "bit"
local width = 36; --dialog width

local shorterSearch = true --opt
local defaultScrolling = false --opt
local sideStickPosition = true --opt
local precedingAst = true; -- opt
local forceScrollEdge = 0.08 -- opt [0.0-0.5] 0.5 for always(default) scroll, 0.0 for minimum scroll

    --TODO XLat support
    --TODO Alternative dialog skins
    --TODO  + "overlay mask" mode for minimalistic skin

    -- TODO KEY_OP_XLAT KEY_OP_PLAINTEXT??
    -- TODO F1
    -- TODO?? make dialog re-positioning (and pattern matching?) when it is shown, not closed?

--[[
Set value for a dialog item (field [10] of FarDialogItem)

Params: hDlg,
		itemIndex,
		newValue

returns: true on success
         false on failure
]]
function ffind.set_dialog_item_data(hDlg, itemNum, data)
    local inputField = far.GetDlgItem(hDlg, itemNum);
    if (not inputField) then return false end
    inputField[10] = data;
    return far.SetDlgItem(hDlg,itemNum,inputField);
end

--[[
Get value of a dialog item
params: hDlg,
		itemIndex

returns: value
         nil on falure
]]
function ffind.get_dialog_item_data(hDlg, itemNum)
    local inputField = far.GetDlgItem(hDlg, itemNum);
    return inputField and inputField[10];
end

--[[
Get a list of items visible on active panel

returns: array of PluginPanelItem: {[1] = item1, [2] = item2...}
         this array might be empty  {}
]]
function ffind.get_apanel_items()
    local totalItems = panel.GetPanelInfo(nil,1).ItemsNumber;
    local items = {}
    for i = 1,totalItems do
        items[i] = panel.GetPanelItem(nil,1,i)
    end
    return items
end

--[[
Matches items list against a pattern

params: pattern (string),
		items (array),
		referenceItemIndex

returns: indexesBefore, itemsBefore, indexesAfter, itemsAfter, isReferenceMatched (boolean)
            note: first 4 returning variables are arrays ( {integer => value,... } ).
]]
function ffind.get_matched_items(pattern, items, referenceItemInd)
    local itemsBefore, itemsAfter = {}, {}
    local idxBefore, idxAfter = {}, {}
    local referenceMatching = false

    local onlyFolders = false
    if (pattern:sub(-2, -2) == "\\" or pattern:sub(-2, -2)=="/") then
        pattern = pattern:sub(1,-3).."*"
        onlyFolders = true;
    end

    -- processing in current panel sort order
    for i,item in ipairs(items) do
        if (item.FileName~=".." and far.ProcessName(_F.PN_CMPNAME, pattern, item.FileName)
            and (not onlyFolders or item.FileAttributes:find("d"))) then

            if (i<referenceItemInd) then
                itemsBefore[#itemsBefore+1] = item; -- really? LUA has no simple way to add an element with auto indexing..
                idxBefore[#idxBefore+1] = i;
            elseif (i==referenceItemInd) then
                referenceMatching = true;
            else
                idxAfter[#idxAfter+1] = i;
                itemsAfter[#itemsAfter+1] = item
            end
        end
    end

    return idxBefore, itemsBefore, idxAfter, itemsAfter, referenceMatching;
end


--[[
Calculate new cursor position in the active panel
params: pattern of search (string),
		direction of search (one of values: "current_or_next", "current", "next", "first", "last", "prev")

returns: newPositionIndex(nil or integer), countBefore, countAfter
]]
function ffind.get_new_position(pattern, direction)
    local items = ffind.get_apanel_items()
    local refInd;

    refInd = panel.GetPanelInfo(nil,1).CurrentItem;

    local before, _ , after, _, refMatch = ffind.get_matched_items(pattern, items, refInd)
    if (refMatch and (direction=="current_or_next" or direction=="current")) then return refInd, #before, #after end

    if (refMatch) then before[#before+1] = refInd end
    if (direction=="current_or_next" or direction=="next") then
        if (#after>0) then                -- matching to the next item if possible
            return after[1], #before, #after-1
        elseif (#before>0) then            -- first from top
            return before[1], 0, #before-1
        end
    elseif (direction=="last") then
        if (#after>0) then                -- matching to the last item if possible
            return after[#after], #before+#after-1, 0
        elseif (#before>0) then
            return before[#before], #before+#after-1, 0
        end
    elseif (direction=="first") then
        if (#before>0) then                -- matching to the top item if possible
            return before[1], 0, #before+#after-1
        elseif (#after>0) then
            return after[1], 0, #before+#after-1
        end
    elseif (direction=="prev") then
        local x=0; if (refMatch) then x=1 end
        if (#before>x) then
            return before[#before-x], #before-1-x, #after+x
        elseif (#after>0) then
            return after[#after], #after-1+x, 0
        elseif (refMatch) then
            return refInd, 0, 0
        end
    end
    return nil, 0, 0; -- no matching at all
end

--[[
A variant of "get_new_position" with precedence given to files with matching portion
closer to the beginning of the filename. Only has effect if direction is "current_or_next"
(initial search), otherwise it calls get_new_position.

params: pattern (string), must be a string of length 1 or more and its last char must be "*"
		direction of search (one of values: "current_or_next", "next", "current", "first", "last", "prev")

returns: newPositionIndex(nil or integer), countBefore, countAfter
]]
function ffind.get_new_position_shorter_start(pattern, direction)
    if (direction ~= "current_or_next" or #pattern<2) then
        return ffind.get_new_position(pattern, direction)
    end

    local items = ffind.get_apanel_items()
    local itemIndex, matchDistance, countBefore, countTotal = nil, -1, 0, 0
    local regexPattern = pattern
    local onlyFolders = false

    if (regexPattern:sub(-2, -2) == "\\" or regexPattern:sub(-2, -2)=="/") then
        regexPattern = regexPattern:sub(1,-3).."*"
        onlyFolders = true;
    end

    regexPattern = regex.gsub(regexPattern, "([()|^$.[{+\\]\\/])","\\%1")
    regexPattern = regex.gsub(regexPattern,"[?]",".")
    regexPattern = regex.gsub(regexPattern,"[*]",".*")

    if (regexPattern:sub(1,2)==".*") then
        --remove 1st '.*' if any (otherwise all matchings will be found from pos 1)
        regexPattern = regexPattern:sub(3,-1)
        else
        --force matching from the beginning
        regexPattern = "^"..regexPattern
    end

    local regexObject = regex.new (regexPattern, "i")               --compile

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
Converts a key to proper case with regards to CAPSLOCK status and whether SHIFT was pressed.
This is called bc key combos with Alt do not consume shift.

params: key, if alphabetic then key is in upper case
		shift (nil or "Shift")
		caps (0 or 1)
]]
--TODO XLAT
function ffind.shifted_case (key, shift, caps)
--[[
    shift caps input    output
      0		0  	A 3   	a 3
      0		1	A 3		A 3
      1		0	A 3		A #
      1		1	A 3		a #
]]
    local changeCase = not not caps == not not shift -- (xor) fucking LUA, extended boolean logic and does not have === operator

    --far.Show(key, shift, caps, changeCase)
    local shiftPair = {
        ["`"] = "~",
        ["1"] = "!",
        ["2"] = "@",
        ["3"] = "#",
        ["4"] = "$",
        ["5"] = "%",
        ["6"] = "^",
        ["7"] = "&",
        ["8"] = "*",
        ["9"] = "(",
        ["0"] = ")",
        ["-"] = "_",
        ["="] = "+",
        ["["] = "{",
        ["]"] = "}",
        [";"] = ":",
        ["'"] = '"',
        [","] = "<",
        ["."] = ">",
        ["/"] = "?",
        ["BackSlash"] = "|"
    }
    -- cause Lua idioms are soooo simple and intuitive
    return  (shift and shiftPair[key]) or
    		(#key==1 and far.LIsAlpha(key) and
    			(changeCase and key:lower() or
    			key)
    		) or
    		((shift or '')..key)
end


--[[
Convert InputRecord to a key name relevant to this dialog input

params: inputRecord

returns: keyName as if pressed without Alt and in eng keyb layout (shift is consumed or dropped)
         nil if key is to be ignored, dialog closed and key sent to panel
         false if key is to have default dialog processing, like a bare modifier combo (i.e RAltShift)

         + some special keyNames:
         "CtrlV" in response to "R?CtrlV" or "ShiftIns"
         "Alt(Up|Down|Home|End)" in response to "R?Alt(Up|Down|Home|End)"
         "\" for BackSlash
]]
function ffind.get_dry_key (inprec)
    -- OK. First draft: ignoring XLat and multilangual complications
    local ctrl,alt,shift,key = far.InputRecordToName (inprec, true)
    local comboKey = far.InputRecordToName (inprec)

    if (not key) then return false end -- bare modifier
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
    if (key == "Multiply") then return "*" end -- (R?Alt)?(Shift)?num"*"
    if (not shift and key == "BackSlash") then return "\\" end -- (R?Alt)?BackSlash


    if (not alt) then return key end -- return Key if ShiftKey or Key

    -- below this we have only Alt(Shift)?Key combinations

	local ffi = require("ffi")
	ffi.cdef[[ int GetKeyState(int nVirtKey); ]]

	local capslockState = ffi.C.GetKeyState(20) -- VK_CAPITAL code

    return ffind.shifted_case (key, shift, capslockState)
end

--[[
This will put given values to dialog elements
params: hDlg, pattern, countBefore, countAfter
]]
function ffind.update_dialog_data (hDlg, pattern, countBefore, countAfter)
    if ( countAfter > 999 ) then countAfter = 999 end
    if ( countBefore > 999 ) then countBefore = 999 end
    ffind.set_dialog_item_data(hDlg, 2, pattern);
    ffind.set_dialog_item_data(hDlg, 3, string.format("%03d",countBefore))
    ffind.set_dialog_item_data(hDlg, 4, string.format("%03d",countAfter))
end

--[[ get new position of the dialog to be on a side of active panel across the new cursor position
note: will work properly only after panel was scrolled to make newPos visible.

params: hDlg (dialog handle)
returns: {X=integer, Y=integer} (table with dialog's left-top coordinates)
]]
function ffind.calc_new_sidestick_dialog_coords(hDlg)
    local pRect = panel.GetPanelInfo(nil,0).PanelRect; -- passive panel!
    local topItem = panel.GetPanelInfo(nil,1).TopPanelItem
    local curItem = panel.GetPanelInfo(nil,1).CurrentItem

    --TODO check panel settings for "Show column titles" (+1) and "Show info line" (+2)
    --far:config
--  Panel.Layout.ColumnTitles
--  Panel.Layout.StatusLine
    local panelLinesUsedForOtherInfo = 3      -- magical constant

    local X
    if (bit.band(panel.GetPanelInfo(nil,0).Flags, _F.PFLAGS_PANELLEFT) >0) then
        -- passive on the left side
        X = pRect.right-width+1
    else
        X = pRect.left
    end

    --how many item lines fit in panel (by height)
    local totalItemLines = pRect.bottom - pRect.top -panelLinesUsedForOtherInfo -1;
    local overTop = curItem-topItem -- 0+

    local Y = overTop % totalItemLines + 1 + pRect.top
    return {X = X, Y = Y}
end

--[[
Panel scrolling and cursor position calculation subroutine

params: newPos (index of the item to move cursor to)
returns: newTopItem (top element after scrolling)
]]
function ffind.calc_new_panel_top_item(newPos)
    local newTopItem = panel.GetPanelInfo(nil,1).TopPanelItem -- default to current top item

    if (newPos ~= panel.GetPanelInfo(nil,1).CurrentItem) then
        local pRect = panel.GetPanelInfo(nil,1).PanelRect;
        local totalItemLines = pRect.bottom - pRect.top -4; --how many item lines fit in panel (by height)
        if (defaultScrolling) then
            -- center current element if scrolling is possible (FAR standard behavior)
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

            local edgePercent = forceScrollEdge / numNameColumns --scale edge according to number of columns
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
    local dryKey = ffind.get_dry_key(inputRec)
    local pattern = ffind.get_dialog_item_data(hDlg, 2)
    local newPattern = pattern

    local searchDirection = "current_or_next" -- default search mode

    -- care: dryKey might be nil or false
    -- Lua, where's my switch statement? I miss it so hard.
    if (dryKey == false) then
        return false -- do default whatever
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
        newPattern = pattern:sub(1, #pattern-1)
        searchDirection = "current"

    elseif (dryKey and #dryKey==1) then
        if (pattern:sub(-1,-1) == '*' and ((dryKey=='*') or (dryKey=='?'))) then
            return true -- ignore '**' and '*?'
        end
        newPattern = pattern..dryKey

    elseif (dryKey == "CtrlV") then -- special occasion covering all insertion keys
        local paste = far.PasteFromClipboard ()
        _G[ffind.dlgGUID].dontBlinkPlease = true
        for i = 1,#paste-1 do --all but the final one
            ffind.process_input (hDlg, far.NameToInputRecord(paste:sub(i,i)))
        end
        _G[ffind.dlgGUID].dontBlinkPlease = nil
        newPattern = ffind.get_dialog_item_data(hDlg, 2) .. paste:sub(#paste,#paste) -- process the final char as usuall input

    elseif (dryKey == "Esc") then
        _G[ffind.dlgGUID].dieSemaphor = true;
        return false -- close naturally by Esc
    else
        -- close dialog on every other key  or dryKey == nil
        -- and pass the key over to the panel
        _G[ffind.dlgGUID].dieSemaphor = true;
        _G[ffind.dlgGUID].resendKey = far.InputRecordToName(inputRec)

        far.SendDlgMessage(hDlg, _F.DM_CLOSE, -1, 0) -- force close
        return true
    end

    local newPos, countBefore, countAfter

    if (shorterSearch) then
        newPos, countBefore, countAfter = ffind.get_new_position_shorter_start(newPattern.."*", searchDirection)
    else
        newPos, countBefore, countAfter = ffind.get_new_position(newPattern.."*", searchDirection)
    end


    if (not newPos) then
        return true; -- new input does not match anything, ignore this key input
    end

    ffind.update_dialog_data(hDlg, newPattern, countBefore, countAfter)

    local newTopItem = ffind.calc_new_panel_top_item(newPos)
    panel.RedrawPanel(nil, 1, {CurrentItem=newPos, TopPanelItem=newTopItem})

    -- must move dialog AFTER panel scrolled to the element
    if (sideStickPosition) then
        far.SendDlgMessage(hDlg, _F.DM_MOVEDIALOG, 1, ffind.calc_new_sidestick_dialog_coords(hDlg))
    end

    if (not _G[ffind.dlgGUID].dontBlinkPlease) then
        far.SendDlgMessage (hDlg, _F.DM_CLOSE, -1, 0) -- blink the dialog to update panel views
    end
    return true
end


--[[
Event handler for Fast Find dialog.
Standard dlgProc function interface
]]
function ffind.dlg_proc (hDlg, msg, param1, param2)
    if (_G[ffind.dlgGUID].firstRun) then
        _G[ffind.dlgGUID].firstRun = nil
        far.SendDlgMessage(hDlg, _F.DM_EDITUNCHANGEDFLAG, 2, 0) -- drop "unchanged"
        far.SendDlgMessage (hDlg, _F.DM_CLOSE, -1, 0) -- blink the dialog to update panel views
        return
    end

    -- omfg. LUA HAS NO SWITCH STATEMENT... Shit got serious...
    if (msg == _F.DN_CTLCOLORDLGITEM) then
        if (param1==3) then param2[1].ForegroundColor = 10; return param2; end
        if (param1==4) then param2[1].ForegroundColor = 12; return param2; end
    elseif (msg == _F.DN_CONTROLINPUT) then
        if (param1 == 2) then
            if ((param2.EventType ~= _F.KEY_EVENT) and (param2.EventType ~= _F.FARMACRO_KEY_EVENT)) then
                return false
            end

            return ffind.process_input(hDlg, param2) -- proxy results to Far
        end
    end
end

--[[
Dialog is placed in the bottom-center of an active panel. If it does not fit then it is
"snapped" to a closer edge of the screen

Params: width, height - dialog size
]]
function ffind.get_dialog_rect(width, height)
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

function ffind.create_dialog()
	local dialogItems = {
--[[1]]         {_F.DI_DOUBLEBOX  ,0,0,width-1,2,0,0,0,_F.DIF_LEFTTEXT,"Fast Find"}
--[[2]]        ,{_F.DI_EDIT       ,2,1,width-3,1,0,0,0,0,""}
--[[3]]        ,{_F.DI_TEXT       ,width-4,0,width-2,0,0,0,0,0,"000"}
--[[4]]        ,{_F.DI_TEXT       ,width-4,2,width-2,2,0,0,0,0,"000"}
--[[5]]        ,{_F.DI_TEXT       ,width-5,0,width-5,0,0,0,0,0,""}
--[[6]]        ,{_F.DI_TEXT       ,width-5,2,width-5,2,0,0,0,0,""}
	}

    local left,top,right,bottom = ffind.get_dialog_rect(width,3)
	local hDlg = far.DialogInit(ffind.dlgGUID,left,top,right,bottom,nil,dialogItems,
		_F.FDLG_KEEPCONSOLETITLE + _F.FDLG_SMALLDIALOG + _F.FDLG_NODRAWSHADOW ,
        ffind.dlg_proc)

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