separate (Terminal.App.Graphics.Kitty_Validation)
procedure Populate_Action_Controls
  (Params : String;
   Fields : Control_Fields;
   Result : in out Graphics_Header)
is
   Cursor_Text  : constant String := Value (Params, Fields, 'C');
   Cell_X_Text  : constant String := Value (Params, Fields, 'X');
   Cell_Y_Text  : constant String := Value (Params, Fields, 'Y');
   Columns_Text : constant String := Value (Params, Fields, 'c');
   Rows_Text    : constant String := Value (Params, Fields, 'r');
   Z_Text       : constant String := Value (Params, Fields, 'z');
   Column_Value : constant Natural := Parse_Natural (Columns_Text);
   Row_Value    : constant Natural := Parse_Natural (Rows_Text);
begin
   if Result.Kitty_Action = 'f' then
      Result.Kitty_Frame_Number := Parse_Natural (Rows_Text);
      Result.Kitty_Base_Frame := Parse_Natural (Columns_Text);
      Result.Kitty_Frame_Gap := Parse_Integer (Z_Text);
      Result.Kitty_Composition_Mode := Parse_Natural (Cell_X_Text);
      Result.Kitty_Background_Color := Parse_Graphics_ID (Cell_Y_Text);
   elsif Result.Kitty_Action = 'a' then
      Result.Kitty_Animation_State := Result.Pixel_Width;
      Result.Kitty_Frame_Number := Parse_Natural (Rows_Text);
      Result.Kitty_Base_Frame := Parse_Natural (Columns_Text);
      Result.Kitty_Frame_Gap := Parse_Integer (Z_Text);
      Result.Kitty_Loop_Count := Result.Pixel_Height;
   elsif Result.Kitty_Action = 'c' then
      Result.Kitty_Frame_Number := Parse_Natural (Columns_Text);
      Result.Kitty_Base_Frame := Parse_Natural (Rows_Text);
      Result.Kitty_Composition_Mode := Parse_Natural (Cursor_Text);
   end if;
   Result.Kitty_Columns_Specified := Columns_Text'Length > 0;
   Result.Kitty_Rows_Specified := Rows_Text'Length > 0;
   Result.Kitty_Columns_Valid :=
     Columns_Text'Length = 0 or else Column_Value > 0;
   Result.Kitty_Rows_Valid := Rows_Text'Length = 0 or else Row_Value > 0;
   Result.Placeholder_Cols :=
     (if Result.Kitty_Columns_Specified and then Result.Kitty_Columns_Valid
      then Positive (Column_Value)
      else 6);
   Result.Placeholder_Rows :=
     (if Result.Kitty_Rows_Specified and then Result.Kitty_Rows_Valid
      then Positive (Row_Value)
      else 3);
end Populate_Action_Controls;
