with Terminal.Core.Graphics_Runtime;

separate (Terminal.Core)
procedure Reset_Terminal (T : in out Terminal) is
begin
   Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
   Graphics_Runtime.Clear_ITerm2_Multipart (T.Graphics);
   Graphics_Runtime.Clear_Graphics_Events (T.Graphics);
   Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
   Graphics_Runtime.Clear_Deferred_Input (T.Graphics);
   T.Graphics.Primary_Generation :=
     T.Graphics.Primary_Generation + 1;
   if T.Graphics.Primary_Generation = 0 then
      T.Graphics.Primary_Generation := 1;
   end if;
   T.Graphics.Alternate_Generation :=
     T.Graphics.Alternate_Generation + 1;
   if T.Graphics.Alternate_Generation = 0 then
      T.Graphics.Alternate_Generation := 1;
   end if;
   Reset_Graphics_Scroll (T, False);
   Reset_Graphics_Scroll (T, True);
   T.Active := Primary;
   T.Current_Modes := Default_Modes;
   T.Keyboard_Stacks := (others => <>);
   T.Cursor_Row := 1;
   T.Cursor_Col := 1;
   T.Current_Cursor_Shape := Cursor_Block;
   T.Current_Cursor_Blinking := False;
   T.Saved_Row := 1;
   T.Saved_Col := 1;
   T.Pending_Wrap := False;
   T.Top_Margin := 1;
   T.Bottom_Margin := T.Rows;
   T.Current_Style := (others => <>);
   T.Saved_Style := (others => <>);
   T.G0_Charset := ASCII_Charset;
   T.G1_Charset := ASCII_Charset;
   T.G2_Charset := ASCII_Charset;
   T.G3_Charset := ASCII_Charset;
   T.Active_Charset := G0;
   T.Charset_Target := G0;
   T.Single_Shift_Charset := G2;
   T.Saved_G0_Charset := ASCII_Charset;
   T.Saved_G1_Charset := ASCII_Charset;
   T.Saved_G2_Charset := ASCII_Charset;
   T.Saved_G3_Charset := ASCII_Charset;
   T.Saved_Active_Charset := G0;
   T.Last_Printable := 0;
   T.Last_Printable_Text := (others => <>);
   T.Last_Printable_Clipped_Wide := False;
   T.Has_Last_Printable := False;
   T.Window_Title := (others => <>);
   T.Saved_Window_Title := (others => <>);
   T.Saved_Window_Title_Valid := False;
   T.Shell_State := (others => <>);
   T.Shell_Marks := (others => <>);
   T.Shell_Mark_Head := 0;
   T.Shell_Mark_Total := 0;
   T.Shell_Command_Blocks := (others => <>);
   T.Shell_Command_Block_Head := 0;
   T.Shell_Command_Block_Total := 0;
   T.Current_Shell_Command_Block := 0;
   T.Next_Shell_Command_Sequence := 1;
   T.History_Rows := 0;
   T.Notification_Data := (others => <>);
   T.Clipboard_Data := (others => <>);
   T.Hyperlinks.Current := null;
   T.Responses := (others => <>);
   T.Parser.State := Ground;
   T.Parser.CSI_Private := ASCII.NUL;
   T.Parser.CSI_Params := (others => 0);
   T.Parser.CSI_Set := (others => False);
   T.Parser.CSI_Separators := (others => ASCII.NUL);
   T.Parser.CSI_Count := 0;
   T.Parser.CSI_Intermediates := (others => ASCII.NUL);
   T.Parser.CSI_Intermediate_Count := 0;
   T.Parser.CSI_Invalid := False;
   T.Parser.OSC_Count := 0;
   T.Parser.Ignored_String_Data := (others => ASCII.NUL);
   T.Parser.Ignored_String_Count := 0;
   T.Parser.Ignored_String_Is_DCS := False;
   T.Parser.Ignored_String_Is_APC := False;
   T.Parser.UTF8_Need := 0;
   T.Parser.UTF8_Seen := 0;
   T.Parser.UTF8_Accum := 0;
   T.Parser.UTF8_Min := 0;
   Reset_Tab_Stops (T);
   Reset_Buffer (T, T.Primary_Cells);
   Reset_Buffer (T, T.Alt_Cells);
   --  Scrollback capacity is retained across RIS, but its cells are no longer
   --  logical roots. Clear their interned-link pointers before releasing the
   --  hyperlink pool so unused backing storage never contains dangling links.
   Scrollback_Storage.Clear (T.Scrollback_State, T.Current_Style);
   Hyperlink_Store.Release_All (T.Hyperlinks);
end Reset_Terminal;
