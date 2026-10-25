separate (Terminal.Core)
procedure Decode_Image_Cell
  (T          : in out Terminal;
   Cell_Index : Positive)
is
   Cells : constant Cell_Array_Access := Active_Cells (T);
   Low_ID : Graphics_ID;
   Placement_Valid : Boolean;
   Image_Valid : Boolean;
   Values : array (Positive range 1 .. 3) of Natural := (others => 0);
   Decoded_Count : Natural := 0;
   High_Value : Natural := 0;
   Col : Positive;
begin
   if Cells = null or else Cell_Index not in Cells'Range then
      return;
   end if;

   Cells (Cell_Index).Image := (others => <>);
   if Cells (Cell_Index).Kind /= Character
     or else Cells (Cell_Index).Text.Code_Point /= Kitty_Image_Placeholder
   then
      return;
   end if;

   Cells (Cell_Index).Image.Is_Placeholder := True;
   Low_ID :=
     Color_Graphics_ID (Cells (Cell_Index).Style.Foreground, Image_Valid);
   Cells (Cell_Index).Image.Image_ID_Valid := Image_Valid;
   Cells (Cell_Index).Image.Placement_ID :=
     Color_Graphics_ID
       (Cells (Cell_Index).Style.Underline_Color, Placement_Valid);

   for I in 1 .. Natural'Min
     (Cells (Cell_Index).Text.Attachment_Count, Values'Length)
   loop
      exit when not Image_Diacritic_Value
        (Cells (Cell_Index).Text.Attachments (I), Values (I));
      Decoded_Count := I;
   end loop;

   if Decoded_Count >= 1 then
      Cells (Cell_Index).Image.Image_Row := Values (1);
      Cells (Cell_Index).Image.Row_Specified := True;
   end if;
   if Decoded_Count >= 2 then
      Cells (Cell_Index).Image.Image_Column := Values (2);
      Cells (Cell_Index).Image.Column_Specified := True;
   end if;
   if Decoded_Count >= 3 and then Values (3) <= 255 then
      High_Value := Values (3);
      Cells (Cell_Index).Image.High_Byte_Specified := True;
   elsif Decoded_Count >= 3 then
      Cells (Cell_Index).Image.Image_ID_Valid := False;
   end if;

   Col := Positive (((Cell_Index - 1) mod T.Cols) + 1);
   if Col > 1 then
      declare
         Left : Cell renames Cells (Cell_Index - 1);
         Same_Colors : constant Boolean :=
           Left.Image.Is_Placeholder
           and then Left.Style.Foreground =
             Cells (Cell_Index).Style.Foreground
           and then Left.Style.Underline_Color =
             Cells (Cell_Index).Style.Underline_Color;
         Left_High : constant Natural :=
           Natural (Left.Image.Image_ID / Graphics_ID (16#1_000000#));
      begin
         if Same_Colors and then Decoded_Count = 0 then
            Cells (Cell_Index).Image.Image_Row := Left.Image.Image_Row;
            Cells (Cell_Index).Image.Image_Column :=
              Left.Image.Image_Column + 1;
            High_Value := Left_High;
         elsif Same_Colors
           and then Decoded_Count = 1
           and then Values (1) = Left.Image.Image_Row
         then
            Cells (Cell_Index).Image.Image_Column :=
              Left.Image.Image_Column + 1;
            High_Value := Left_High;
         elsif Same_Colors
           and then Decoded_Count = 2
           and then Values (1) = Left.Image.Image_Row
           and then Values (2) = Left.Image.Image_Column + 1
         then
            High_Value := Left_High;
         end if;
      end;
   end if;

   Cells (Cell_Index).Image.Image_ID :=
     Low_ID + Graphics_ID (High_Value) * Graphics_ID (16#1_000000#);
   Cells (Cell_Index).Image.Image_ID_Valid :=
     Cells (Cell_Index).Image.Image_ID_Valid
     and then Cells (Cell_Index).Image.Image_ID /= 0;
end Decode_Image_Cell;
