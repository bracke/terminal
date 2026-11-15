separate (Terminal.App.Graphics.Kitty_Validation)
procedure Populate_Base_Controls
  (Params : String;
   Fields : Control_Fields;
   Result : in out Graphics_Header)
is
   Action_Text           : constant String := Value (Params, Fields, 'a');
   Cursor_Text           : constant String := Value (Params, Fields, 'C');
   Parent_X_Text         : constant String := Value (Params, Fields, 'H');
   Image_Number_Text     : constant String := Value (Params, Fields, 'I');
   Usage_Text            : constant String := Value (Params, Fields, 'N');
   Data_Offset_Text      : constant String := Value (Params, Fields, 'O');
   Parent_ID_Text        : constant String := Value (Params, Fields, 'P');
   Parent_Placement_Text : constant String := Value (Params, Fields, 'Q');
   Data_Size_Text        : constant String := Value (Params, Fields, 'S');
   Virtual_Text          : constant String := Value (Params, Fields, 'U');
   Parent_Y_Text         : constant String := Value (Params, Fields, 'V');
   Cell_X_Text           : constant String := Value (Params, Fields, 'X');
   Cell_Y_Text           : constant String := Value (Params, Fields, 'Y');
   Delete_Text           : constant String := Value (Params, Fields, 'd');
   Format_Field_Text     : constant String := Value (Params, Fields, 'f');
   Source_Height_Text    : constant String := Value (Params, Fields, 'h');
   ID_Text               : constant String := Value (Params, Fields, 'i');
   More_Field_Text       : constant String := Value (Params, Fields, 'm');
   Compression_Text      : constant String := Value (Params, Fields, 'o');
   Placement_Text        : constant String := Value (Params, Fields, 'p');
   Quiet_Text            : constant String := Value (Params, Fields, 'q');
   Width_Pixels_Text     : constant String := Value (Params, Fields, 's');
   Transmission_Text     : constant String := Value (Params, Fields, 't');
   Height_Pixels_Text    : constant String := Value (Params, Fields, 'v');
   Source_Width_Text     : constant String := Value (Params, Fields, 'w');
   Source_X_Text         : constant String := Value (Params, Fields, 'x');
   Source_Y_Text         : constant String := Value (Params, Fields, 'y');
   Z_Text                : constant String := Value (Params, Fields, 'z');
begin
   Result.Kitty_Action :=
     (if Action_Text'Length > 0 then Action_Text (Action_Text'First) else 't');
   Result.Kitty_Transmission :=
     (if Transmission_Text'Length > 0
      then Transmission_Text (Transmission_Text'First)
      else ASCII.NUL);
   Result.Kitty_Transmission_Specified := Transmission_Text'Length > 0;
   Result.Kitty_Transmission_Valid :=
     Transmission_Text'Length = 0
     or else
       (Transmission_Text'Length = 1
        and then Transmission_Text (Transmission_Text'First)
          in 'd' | 'f' | 't' | 's');
   Result.Kitty_Compression :=
     (if Compression_Text'Length > 0
      then Compression_Text (Compression_Text'First)
      else ASCII.NUL);
   Result.Kitty_Compression_Specified := Compression_Text'Length > 0;
   Result.Kitty_Compression_Valid :=
     Compression_Text'Length = 0 or else Compression_Text = "z";
   Result.Kitty_Delete :=
     (if Delete_Text'Length > 0
      then Delete_Text (Delete_Text'First)
      else ASCII.NUL);
   Result.Kitty_ID := Parse_Graphics_ID (ID_Text);
   Result.Kitty_Image_Number := Parse_Graphics_ID (Image_Number_Text);
   Result.Kitty_Placement_ID := Parse_Graphics_ID (Placement_Text);
   Result.Kitty_Quiet := Parse_Natural (Quiet_Text);
   Result.Kitty_Usage_Hint := Parse_Natural (Usage_Text);
   Result.Kitty_Format :=
     (if Format_Field_Text'Length = 0
      then 32
      else Parse_Natural (Format_Field_Text));
   Result.Kitty_More_Specified := More_Field_Text'Length > 0;
   Result.Kitty_More_Valid :=
     More_Field_Text'Length = 0
     or else More_Field_Text = "0"
     or else More_Field_Text = "1";
   Result.Kitty_More := More_Field_Text = "1";
   Result.Raw_Format := Result.Kitty_Format;
   Result.Pixel_Width := Parse_Natural (Width_Pixels_Text);
   Result.Pixel_Height := Parse_Natural (Height_Pixels_Text);
   Result.Kitty_Data_Size_Specified := Data_Size_Text'Length > 0;
   Result.Kitty_Data_Size_Valid :=
     Data_Size_Text'Length = 0 or else Valid_Natural_Text (Data_Size_Text);
   Result.Kitty_Data_Size := Parse_Natural (Data_Size_Text);
   Result.Kitty_Data_Offset_Specified := Data_Offset_Text'Length > 0;
   Result.Kitty_Data_Offset_Valid :=
     Data_Offset_Text'Length = 0
     or else Valid_Natural_Text (Data_Offset_Text);
   Result.Kitty_Data_Offset := Parse_Natural (Data_Offset_Text);
   Result.Kitty_Source_X := Parse_Natural (Source_X_Text);
   Result.Kitty_Source_Y := Parse_Natural (Source_Y_Text);
   Result.Kitty_Delete_Range_First := Parse_Graphics_ID (Source_X_Text);
   Result.Kitty_Delete_Range_Last := Parse_Graphics_ID (Source_Y_Text);
   Result.Kitty_Source_Width := Parse_Natural (Source_Width_Text);
   Result.Kitty_Source_Height := Parse_Natural (Source_Height_Text);
   Result.Kitty_Cell_X := Parse_Natural (Cell_X_Text);
   Result.Kitty_Cell_Y := Parse_Natural (Cell_Y_Text);
   Result.Kitty_Geometry_Controls_Valid :=
     (Source_X_Text'Length = 0 or else Valid_Natural_Text (Source_X_Text))
     and then
       (Source_Y_Text'Length = 0 or else Valid_Natural_Text (Source_Y_Text))
     and then
       (Source_Width_Text'Length = 0
        or else Valid_Natural_Text (Source_Width_Text))
     and then
       (Source_Height_Text'Length = 0
        or else Valid_Natural_Text (Source_Height_Text))
     and then
       (Cell_X_Text'Length = 0 or else Valid_Natural_Text (Cell_X_Text))
     and then
       (Cell_Y_Text'Length = 0 or else Valid_Natural_Text (Cell_Y_Text));
   Result.Kitty_Z_Index := Parse_Integer (Z_Text);
   Result.Kitty_No_Cursor_Move := Cursor_Text = "1";
   Result.Kitty_Virtual_Placement := Virtual_Text = "1";
   Result.Kitty_Parent_ID := Parse_Graphics_ID (Parent_ID_Text);
   Result.Kitty_Parent_Placement_ID :=
     Parse_Graphics_ID (Parent_Placement_Text);
   Result.Kitty_Parent_Offset_X := Parse_Integer (Parent_X_Text);
   Result.Kitty_Parent_Offset_Y := Parse_Integer (Parent_Y_Text);
end Populate_Base_Controls;
