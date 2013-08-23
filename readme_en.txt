╔═════════════════════════════════════════════════════════════════════╗
║                                                                     ║
║ FastFind Enhanced                                                   ║
║ © Acerbic, 2013                                                     ║
╚═════════════════════════════════════════════════════════════════════╝

  This plugin replaces default functionality of fast search in file 
panels - you can type partial name of a file while holding Alt to 
reposition cursor to the file matching a pattern you entered.
  
  In addition to the default features the plugin provides:
 - indication of number of files matching prior and following 
   the highlighted (current) one;
 - quick shortcut to the first and the last matched elements on the 
   panel;
 - auto insertion of an asterisk ('*') as the first character in 
   a search;
 - preference to matches closer to the beginning of a file name, i.e. 
   '*im' pattern will be matched to 'my images' first and to 
   'Summercamp.img' second (if disabled then the next matching in the 
   file list will be selected - default Far Manager behaviour);
 - more intuitive scrolling in panels with great number of files;
 - alternative handling of non-English input while Alt is held - with 
   or without using XLat. (Pick the best fitting your locale);
 - Fancy 'side stick' dialogue placement.

-== Controls ==-

AltHome                 - to the first element matching current pattern
AltEnd                  - to the last element
AltUp, CtrlShiftEnter   - previous
AltDown, CtrlEnter      - next
Esc                     - close FastFind


-== Macro integration ==-

  Arguments: 1, KeyName
  Calls plugin and sends KeyName as the first pressed input key. If 
plugin is already running on screen then nothing happens.

Plugin.Call("3106d308-a685-415c-96e6-84c8ebb361fe", 1, akey(1))

  Arguments: 2
  Returns current match pattern from the FastFind dialogue. If plugin is
not running, returns nil.

Plugin.Call("3106d308-a685-415c-96e6-84c8ebb361fe", 2)
