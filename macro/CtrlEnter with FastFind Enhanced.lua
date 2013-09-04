Macro {
  description="Copy file name to the command line while keeping FastFind Enhanced mask";
  area="Dialog";
  key="CtrlEnter";
  condition=function()
    return Dlg.Id ==  "3731617B-3037-6363-632D-353933332D34";
  end;
  action=function()
    --save mask
    local ffeMask = Plugin.Call("3106d308-a685-415c-96e6-84c8ebb361fe", 2)
    -- save pos
    local pos = APanel.CurPos

    Keys("Esc CtrlEnter") -- close FFE and apply CtrlEnter

    mf.mmode(3,1) -- do not wait for Plugin.Call to finish execution

    -- now restart FFE and send back the mask
    Plugin.Call("3106d308-a685-415c-96e6-84c8ebb361fe", 1, nil)

    -- bypass asterisk option
    Keys("BS") 
    print(ffeMask)

    -- bypass favour shorter matches option
    Keys("*") 
    Panel.SetPosIdx(0,pos)
    Keys("BS")
  end;
}

                          --[[
Macro {
  description="CtrlEnter not a special key in FastFind Enhanced";
  area="Dialog";
  key="CtrlEnter";
  condition=function()
    return Dlg.Id ==  "3731617B-3037-6363-632D-353933332D34";
  end;
  action=function()
    Keys("Esc CtrlEnter") -- close FFE and apply CtrlEnter
  end;
}
]]