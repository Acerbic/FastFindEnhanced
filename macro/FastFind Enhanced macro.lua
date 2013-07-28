Macro {
  description="FastFind Enhancer starter";
  area="Shell";
  key="/Alt(Shift)?./";
  flags="";
  action=function()
    mf.mmode(3,1) -- do not wait for Plugin.Call to finish execution
    Plugin.Call("ace12b1c-5fc7-e11f-1337-fa575ea12c11", 1)
  	Keys("Akey")
  end;
}