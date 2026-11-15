separate (Terminal.Core)
procedure Soft_Reset (T : in out Terminal) is
   Old_Row : constant Positive := T.Cursor_Row;
   Keep_Alternate : constant Boolean := T.Current_Modes.Alternate_Screen;
begin
   T.Current_Style := (others => <>);
   T.Saved_Style := (others => <>);
   T.Current_Modes := Default_Modes (Alternate_Screen => Keep_Alternate);
   T.Cursor_Row := 1;
   T.Cursor_Col := 1;
   T.Current_Cursor_Shape := Cursor_Block;
   T.Current_Cursor_Blinking := False;
   T.Saved_Row := 1;
   T.Saved_Col := 1;
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
   T.Pending_Wrap := False;
   T.Top_Margin := 1;
   T.Bottom_Margin := T.Rows;
   T.Last_Printable := 0;
   T.Last_Printable_Text := (others => <>);
   T.Last_Printable_Clipped_Wide := False;
   T.Has_Last_Printable := False;
   Refresh_Keyboard_Flags (T);
   Mark_Cursor_Move (T, Old_Row);
end Soft_Reset;
