separate (Terminal.App.Graphics.Kitty_Validation)
procedure Validate_Action_Controls
  (Params : String;
   Fields : Control_Fields;
   Result : in out Graphics_Header)
is
   Cursor_Text       : constant String := Value (Params, Fields, 'C');
   Virtual_Text      : constant String := Value (Params, Fields, 'U');
   Cell_X_Text       : constant String := Value (Params, Fields, 'X');
   Columns_Text      : constant String := Value (Params, Fields, 'c');
   Rows_Text         : constant String := Value (Params, Fields, 'r');
   Width_Pixels_Text : constant String := Value (Params, Fields, 's');
   Source_X_Text     : constant String := Value (Params, Fields, 'x');
   Source_Y_Text     : constant String := Value (Params, Fields, 'y');
   Has_Identity : constant Boolean :=
     (Result.Kitty_ID /= 0) xor (Result.Kitty_Image_Number /= 0);
begin
   Result.Kitty_Delete_Controls_Valid :=
     (case Result.Kitty_Delete is
        when ASCII.NUL | 'a' | 'A' | 'c' | 'C' | 'z' | 'Z' => True,
        when 'i' | 'I' =>
           Result.Kitty_ID /= 0 and then Result.Kitty_Image_Number = 0,
        when 'n' | 'N' =>
           Result.Kitty_Image_Number /= 0 and then Result.Kitty_ID = 0,
        when 'f' | 'F' => Has_Identity,
        when 'p' | 'P' | 'q' | 'Q' =>
           Valid_Natural_Text (Source_X_Text)
           and then Valid_Natural_Text (Source_Y_Text)
           and then Parse_Natural (Source_X_Text) > 0
           and then Parse_Natural (Source_Y_Text) > 0,
        when 'x' | 'X' =>
           Valid_Natural_Text (Source_X_Text)
           and then Parse_Natural (Source_X_Text) > 0,
        when 'y' | 'Y' =>
           Valid_Natural_Text (Source_Y_Text)
           and then Parse_Natural (Source_Y_Text) > 0,
        when 'r' | 'R' =>
           Source_X_Text'Length > 0
           and then Source_Y_Text'Length > 0
           and then Valid_Graphics_ID_Text (Source_X_Text)
           and then Valid_Graphics_ID_Text (Source_Y_Text)
           and then Result.Kitty_Delete_Range_Last >=
             Result.Kitty_Delete_Range_First,
        when others => False);
   Result.Kitty_Action_Controls_Valid :=
     Result.Kitty_Control_Data_Valid
     and then not
       (Result.Kitty_ID /= 0 and then Result.Kitty_Image_Number /= 0)
     and then
       (case Result.Kitty_Action is
          when 't' | 'T' => Result.Has_Data,
          when 'q' =>
             Result.Has_Data
             and then Result.Kitty_ID /= 0
             and then Result.Kitty_Image_Number = 0,
          when 'p' => not Result.Has_Data and then Has_Identity,
          when 'd' =>
             not Result.Has_Data and then Result.Kitty_Delete_Controls_Valid,
          when 'f' =>
             Result.Has_Data
             and then Has_Identity
             and then
               (Cell_X_Text'Length = 0
                or else Cell_X_Text = "0"
                or else Cell_X_Text = "1"),
          when 'a' =>
             not Result.Has_Data
             and then Has_Identity
             and then
               (Width_Pixels_Text'Length = 0
                or else Width_Pixels_Text = "1"
                or else Width_Pixels_Text = "2"
                or else Width_Pixels_Text = "3"),
          when 'c' =>
             not Result.Has_Data
             and then Has_Identity
             and then Parse_Natural (Columns_Text) > 0
             and then Parse_Natural (Rows_Text) > 0
             and then
               (Cursor_Text'Length = 0
                or else Cursor_Text = "0"
                or else Cursor_Text = "1"),
          when others => False)
     and then
       (if Result.Kitty_Action in 'T' | 'p'
        then
          (Cursor_Text'Length = 0
           or else Cursor_Text = "0"
           or else Cursor_Text = "1")
          and then
            (Virtual_Text'Length = 0
             or else Virtual_Text = "0"
             or else Virtual_Text = "1")
        else True);
end Validate_Action_Controls;
