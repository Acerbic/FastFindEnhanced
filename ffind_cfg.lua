local _F = far.Flags
local ffind_cfg = {}
ffind_cfg.dlgGUID = "{30ed409d-b5e6-4ed0-a3ef-d1757a36b6f5}"

 local optShorterSearch = true
 local optPanelSidePosition = true
 local optPrecedingAsterisk = true
 local optDefaultScrolling = false
 local optForceScrollEdge = 0.08 -- [0.0-0.5] 0.5 for always(default) scroll, 0.0 for minimum scroll
 local optUseXlat = false

 local chkPrecedingAsterisk = optPrecedingAsterisk and 1 or 0
 local chkShorterSearch = optShorterSearch and 1 or 0
 local chkPanelAtBottom = optPanelSidePosition and 0 or 1
 local chkBetterScrolling = optDefaultScrolling and 0 or 1
 local inpScrollMargin = tostring(optForceScrollEdge and optForceScrollEdge*200 or 16)
 local chkUseXlat = optUseXlat and 1 or 0


--[[
Event handler for Fast Find configuration dialog.
Standard dlgProc function interface
]]
function ffind_cfg.dlg_proc (hDlg, msg, param1, param2)
end

--[[
Creates a Far dialog object for FastFind configuration dialog,

returns: hDlg - handle for this dialog. far.DialogFree() MUST be called sometime downstream.
]]
function ffind_cfg.create_dialog()
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
--		_F.FDLG_KEEPCONSOLETITLE + _F.FDLG_SMALLDIALOG + _F.FDLG_NODRAWSHADOW ,
		_F.FDLG_KEEPCONSOLETITLE,
        ffind_cfg.dlg_proc)

    return hDlg
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