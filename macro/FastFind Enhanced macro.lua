Macro {
  description="FastFind Enhanced starter";
  area="Shell";
  key="/.Alt(Shift)?./";
  flags="";
  action=function()
    mf.mmode(3,1) -- do not wait for Plugin.Call to finish execution
    Plugin.Call("3106d308-a685-415c-96e6-84c8ebb361fe", 1, akey(1))
  end;
}