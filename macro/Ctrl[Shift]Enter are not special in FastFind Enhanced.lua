Macro {
  description="CtrlEnter not a special key in FastFind Enhanced";
  area="Dialog";
  key="/.Ctrl(Shift)?Enter/";
  condition=function()
    return Dlg.Id ==  "3731617B-3037-6363-632D-353933332D34";
  end;
  action=function()
    Keys("Esc "..akey(1)) -- close FFE and apply CtrlEnter
  end;
}