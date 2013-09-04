Macro {
  description="Select files by FastFind Enhanced mask";
  area="Dialog";
  key="AltAdd";
  flags="";
  condition=function()
    return Dlg.Id ==  "3731617B-3037-6363-632D-353933332D34";
  end;
  action=function()
    Panel.Select(0, 0, 3, "*") -- unselect
    Panel.Select(0, 1, 3, Plugin.Call("3106d308-a685-415c-96e6-84c8ebb361fe", 2).."*") -- select
  end;
}
