separate (Terminal.App.Graphics)
   procedure Decode_Sixel_Rows
     (Text   : String;
      Row_Sink : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Palette : in out Sixel_Palette_State;
      Reset_Palette : Boolean;
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension)
   is
      Info : constant Sixel_Info := Analyze_Sixel (Text);
      I : Natural := Text'First;
      X : Natural := 0;
      Y : Natural := 0;
      Repeat_Count : Natural := 1;
      Color_Index : Natural range 0 .. 255 := 1;
      Byte_Count : constant Natural :=
        RGBA_Decoded_Length (Info.Width, Info.Height);
      Row_Bytes : constant Natural := Raw_Row_Stride (32, Info.Width);
      Within_Limits : constant Boolean :=
        Byte_Count > 0
        and then Byte_Count <= Maximum_Decoded_Bytes
        and then Info.Width <= Maximum_Pixel_Dimension
        and then Info.Height <= Maximum_Pixel_Dimension;
      Band_Byte_Count : constant Natural :=
        (if not Within_Limits
           or else Row_Bytes = 0
           or else Info.Vertical_Aspect > Natural'Last / 6
           or else Row_Bytes >
             Natural'Last / (6 * Info.Vertical_Aspect)
         then 1
         else Natural'Max (Row_Bytes * 6 * Info.Vertical_Aspect, 1));
      Band : Image_Data_Holder;
      Row_Buffer : Image_Data_Holder;

      procedure Initialize_Band is
      begin
         Band.Data.all := (others => 0);
         if not Info.Transparent and then Row_Bytes > 0 then
            for Band_Row in 0 .. 6 * Info.Vertical_Aspect - 1 loop
               for PX in 0 .. Info.Width - 1 loop
                  declare
                     Offset : constant Positive :=
                       Band_Row * Row_Bytes + PX * 4 + 1;
                  begin
                     Band.Data (Offset) := Palette (0).R;
                     Band.Data (Offset + 1) := Palette (0).G;
                     Band.Data (Offset + 2) := Palette (0).B;
                     Band.Data (Offset + 3) := 16#FF#;
                  end;
               end loop;
            end loop;
         end if;
      end Initialize_Band;

      procedure Write_Pixel (PX, PY : Natural; Color : Sixel_Color) is
         Offset : Natural;
         Bit_Row : Natural;
      begin
         if PX >= Info.Width or else PY >= Info.Height then
            return;
         end if;

         Bit_Row := PY - Y;
         if Bit_Row >= 6 then
            return;
         end if;
         for Aspect_Row in 0 .. Info.Vertical_Aspect - 1 loop
            Offset :=
              (Bit_Row * Info.Vertical_Aspect + Aspect_Row) * Row_Bytes
              + PX * 4 + 1;
            Band.Data (Offset) := Color.R;
            Band.Data (Offset + 1) := Color.G;
            Band.Data (Offset + 2) := Color.B;
            Band.Data (Offset + 3) := Color.A;
         end loop;
      end Write_Pixel;

      procedure Flush_Band is
      begin
         for Band_Row in 0 .. 6 * Info.Vertical_Aspect - 1 loop
            exit when Y * Info.Vertical_Aspect + Band_Row >= Info.Height;
            declare
               Source_First : constant Natural := Band_Row * Row_Bytes + 1;
               Continue : Boolean := True;
            begin
               for I in Row_Buffer.Data'Range loop
                  Row_Buffer.Data (I) :=
                    Band.Data (Source_First + I - Row_Buffer.Data'First);
               end loop;
               Row_Sink
                 (Y * Info.Vertical_Aspect + Band_Row,
                  Row_Buffer.Data.all,
                  Continue);
               if not Continue then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  return;
               end if;
            end;
         end loop;
         Initialize_Band;
      end Flush_Band;
   begin
      if Reset_Palette then
         Palette := Default_Sixel_Palette;
      end if;
      if Info.Width = 0 or else Info.Height = 0 then
         Result.Decode_Status := Decode_Invalid_Byte;
         Result.Decode_Complete := False;
         return;
      elsif not Within_Limits or else Row_Bytes = 0 then
         Result.Decode_Status := Decode_Preview_Truncated;
         Result.Decode_Complete := False;
         Result.Decoded_Length := Max_Data_Preview_Length;
         return;
      end if;

      Result.Raw_Format := 32;
      Result.Pixel_Width := Info.Width;
      Result.Pixel_Height := Info.Height;
      Result.Decoded_Row_Stride_Bytes := Row_Bytes;
      Result.Decode_Complete := True;
      Band.Data := new Terminal.Common.Bytes.Byte_Array (1 .. Band_Byte_Count);
      Row_Buffer.Data :=
        new Terminal.Common.Bytes.Byte_Array (1 .. Row_Bytes);
      Initialize_Band;

      while I <= Text'Last and then Text (I) /= 'q' loop
         I := I + 1;
      end loop;
      if I > Text'Last then
         Result.Decode_Status := Decode_Invalid_Byte;
         Result.Decode_Complete := False;
         return;
      end if;

      I := I + 1;
      while I <= Text'Last loop
         case Text (I) is
            when '!' =>
               I := I + 1;
               Repeat_Count := Natural'Max (Read_Sixel_Number (Text, I), 1);
            when '#' =>
               I := I + 1;
               declare
                  Index : constant Natural := Read_Sixel_Number (Text, I);
               begin
                  if Index <= 255 then
                     Color_Index := Index;
                  end if;

                  if I <= Text'Last and then Text (I) = ';' then
                     I := I + 1;
                     declare
                        Mode : constant Natural := Read_Sixel_Number (Text, I);
                        R    : Natural := 0;
                        G    : Natural := 0;
                        B    : Natural := 0;
                     begin
                        if I <= Text'Last and then Text (I) = ';' then
                           I := I + 1;
                           R := Read_Sixel_Number (Text, I);
                        end if;
                        if I <= Text'Last and then Text (I) = ';' then
                           I := I + 1;
                           G := Read_Sixel_Number (Text, I);
                        end if;
                        if I <= Text'Last and then Text (I) = ';' then
                           I := I + 1;
                           B := Read_Sixel_Number (Text, I);
                        end if;
                        if Index <= 255 then
                           if Mode = 1 then
                              Palette (Index) := Sixel_HLS_Color (R, G, B);
                           elsif Mode = 2 then
                              Palette (Index) :=
                                (R => Byte_From_Percent (R),
                                 G => Byte_From_Percent (G),
                                 B => Byte_From_Percent (B),
                                 A => 16#FF#);
                           end if;
                        end if;
                     end;
                  end if;
               end;
            when '$' =>
               X := 0;
               I := I + 1;
            when '-' =>
               Flush_Band;
               if not Result.Decode_Complete then
                  return;
               end if;
               X := 0;
               Y := Y + 6;
               I := I + 1;
            when '?' .. '~' =>
               declare
                  Bits : constant Natural := Character'Pos (Text (I)) - 63;
               begin
                  for Repeat in 1 .. Repeat_Count loop
                     for Bit in 0 .. 5 loop
                        if (Bits / (2 ** Bit)) mod 2 = 1 then
                           Write_Pixel (X, Y + Bit, Palette (Color_Index));
                        end if;
                     end loop;
                     X := X + 1;
                  end loop;
                  Repeat_Count := 1;
                  I := I + 1;
               end;
            when others =>
               Repeat_Count := 1;
               I := I + 1;
         end case;
      end loop;

      loop
         Flush_Band;
         if not Result.Decode_Complete then
            return;
         end if;
         exit when Y >= Info.Logical_Height
           or else Info.Logical_Height - Y <= 6;
         Y := Y + 6;
      end loop;

      Result.Decoded_Length := Byte_Count;
      Result.Decoded_Row_Stride_Bytes := Info.Width * 4;
      Result.Decode_Complete := True;
      Result.Decode_Status := Decode_Ok;
   exception
      when Storage_Error =>
         Result.Decode_Status := Decode_Allocation_Failed;
         Result.Decode_Complete := False;
   end Decode_Sixel_Rows;

