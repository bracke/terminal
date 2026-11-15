separate (Terminal.App.Graphics)
function Parse_ITerm2_Header (Text : String) return Graphics_Header is
   package Controls renames Terminal.App.ITerm2_Controls;
   Result : Graphics_Header (ITerm2);
   Parsed : Controls.Parsed_Controls;

   procedure Parse_Size
     (Value     : String;
      Specified : out Boolean;
      Valid     : out Boolean;
      Number    : out Natural;
      Unit      : out ITerm2_Size_Unit)
   is
      Digits_Last : Natural := 0;
   begin
      Specified := Value'Length > 0;
      Valid := True;
      Number := 0;
      Unit := ITerm2_Auto;
      if Value'Length = 0 or else Value = "auto" then
         return;
      elsif Value'Length >= 3
        and then Value (Value'Last - 1 .. Value'Last) = "px"
      then
         Unit := ITerm2_Pixels;
         Digits_Last := Value'Last - 2;
      elsif Value (Value'Last) = '%' then
         Unit := ITerm2_Percent;
         Digits_Last := Value'Last - 1;
      else
         Unit := ITerm2_Cells;
         Digits_Last := Value'Last;
      end if;
      if Digits_Last < Value'First then
         Valid := False;
         return;
      end if;
      declare
         Numeric_Text : constant String := Value (Value'First .. Digits_Last);
      begin
         Valid := Valid_Natural_Text (Numeric_Text);
         Number := Parse_Natural (Numeric_Text);
         Valid := Valid and then Number > 0;
      end;
   end Parse_Size;

   procedure Apply_Field (Field : Controls.Field_Kind; Value : String) is
   begin
      case Field is
         when Controls.Inline_Field =>
            Result.ITerm2_Inline := Value = "1";
            Result.ITerm2_Control_Data_Valid :=
              Result.ITerm2_Control_Data_Valid
              and then
                (Value'Length = 0 or else Value = "0" or else Value = "1");
         when Controls.Name_Field =>
            Result.ITerm2_Name_Length := Value'Length;
         when Controls.Width_Field =>
            Parse_Size
              (Value, Result.ITerm2_Width_Specified,
               Result.ITerm2_Width_Valid, Result.ITerm2_Width_Value,
               Result.ITerm2_Width_Unit);
         when Controls.Height_Field =>
            Parse_Size
              (Value, Result.ITerm2_Height_Specified,
               Result.ITerm2_Height_Valid, Result.ITerm2_Height_Value,
               Result.ITerm2_Height_Unit);
         when Controls.Preserve_Aspect_Field =>
            Result.ITerm2_Preserve_Aspect_Ratio := Value /= "0";
            Result.ITerm2_Control_Data_Valid :=
              Result.ITerm2_Control_Data_Valid
              and then
                (Value'Length = 0 or else Value = "0" or else Value = "1");
         when Controls.Do_Not_Move_Field =>
            Result.ITerm2_Do_Not_Move_Cursor := Value = "1";
            Result.ITerm2_Control_Data_Valid :=
              Result.ITerm2_Control_Data_Valid
              and then
                (Value'Length = 0 or else Value = "0" or else Value = "1");
         when Controls.Size_Field =>
            Result.ITerm2_Declared_Size_Valid :=
              Value'Length = 0 or else Valid_Natural_Text (Value);
            Result.ITerm2_Declared_Size := Parse_Natural (Value);
            Result.ITerm2_Control_Data_Valid :=
              Result.ITerm2_Control_Data_Valid
              and then Result.ITerm2_Declared_Size_Valid;
      end case;
   end Apply_Field;
begin
   Controls.Parse (Text, Parsed);
   if not Controls.Recognized (Parsed) then
      return Result;
   end if;

   Result.Recognized := True;
   Result.Has_Data := Controls.Has_Data (Parsed);
   Result.ITerm2_Control_Data_Valid := Controls.Valid (Parsed);
   Result.ITerm2_Preserve_Aspect_Ratio := True;
   Parse_Size
     ("", Result.ITerm2_Width_Specified, Result.ITerm2_Width_Valid,
      Result.ITerm2_Width_Value, Result.ITerm2_Width_Unit);
   Parse_Size
     ("", Result.ITerm2_Height_Specified, Result.ITerm2_Height_Valid,
      Result.ITerm2_Height_Value, Result.ITerm2_Height_Unit);

   for Field in Controls.Field_Kind loop
      Apply_Field (Field, Controls.Value (Text, Parsed, Field));
   end loop;

   if Result.ITerm2_Width_Unit = ITerm2_Cells
     and then Result.ITerm2_Width_Valid
   then
      Result.Placeholder_Cols :=
        Clamp_Positive (Result.ITerm2_Width_Value, 6, 80);
   end if;
   if Result.ITerm2_Height_Unit = ITerm2_Cells
     and then Result.ITerm2_Height_Valid
   then
      Result.Placeholder_Rows :=
        Clamp_Positive (Result.ITerm2_Height_Value, 3, 40);
   end if;
   return Result;
end Parse_ITerm2_Header;
