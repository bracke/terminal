separate (Terminal.Core)
procedure Reset_Terminal (T : in out Terminal) is
begin
   Clear_Graphics_Transfer (T);
   Clear_ITerm2_Multipart (T);
   Clear_Graphics_Events (T);
   Advance_Graphics_Transaction (T);
   Clear_Deferred_Input (T);
   T.Primary_Graphics_Generation :=
     T.Primary_Graphics_Generation + 1;
   if T.Primary_Graphics_Generation = 0 then
      T.Primary_Graphics_Generation := 1;
   end if;
   T.Alternate_Graphics_Generation :=
     T.Alternate_Graphics_Generation + 1;
   if T.Alternate_Graphics_Generation = 0 then
      T.Alternate_Graphics_Generation := 1;
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
   T.Scrollback_Rows := 0;
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
   T.Has_Last_Printable := False;
   T.Window_Title := (others => <>);
   T.Saved_Window_Title := (others => <>);
   T.Saved_Window_Title_Valid := False;
   T.Clipboard_Data := (others => <>);
   T.Current_Link := (others => <>);
   T.Response_Length := 0;
   T.Response_Transaction_Start := 0;
   T.Response_Transaction_Active := False;
   T.Response_Transaction_Overflowed := False;
   T.State := Ground;
   T.CSI_Private := ASCII.NUL;
   T.CSI_Params := (others => 0);
   T.CSI_Set := (others => False);
   T.CSI_Separators := (others => ASCII.NUL);
   T.CSI_Count := 0;
   T.CSI_Intermediates := (others => ASCII.NUL);
   T.CSI_Intermediate_Count := 0;
   T.OSC_Count := 0;
   T.Ignored_String_Data := (others => ASCII.NUL);
   T.Ignored_String_Count := 0;
   T.Ignored_String_Is_DCS := False;
   T.Ignored_String_Is_APC := False;
   T.UTF8_Need := 0;
   T.UTF8_Seen := 0;
   T.UTF8_Accum := 0;
   T.UTF8_Min := 0;
   Reset_Tab_Stops (T);
   Reset_Buffer (T, T.Primary_Cells);
   Reset_Buffer (T, T.Alt_Cells);
end Reset_Terminal;
