separate (Terminal.App.Graphics.Media_Decoders)
procedure Decode_PNG_RGBA_Source_Rows
  (Length : Natural;
   PNG_Byte : not null access function
     (Index : Positive) return Terminal.Common.Bytes.Byte;
   Row_Sink : not null access procedure
     (Y : Natural;
      Row : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean);
   Result : in out Graphics_Data_Preview)
is
   Parsed       : PNG_Chunks.Parsed_Image;
   Parse_Status : Data_Decode_Status := Decode_Not_Attempted;
begin
   Preview_Storage.Reset_Decode_Metadata (Result);
   PNG_Chunks.Parse (Length, PNG_Byte, Parsed, Parse_Status);
   if Parse_Status /= Decode_Ok then
      Result.Decode_Status := Parse_Status;
      Result.Decode_Complete := False;
      return;
   end if;

   declare
      Info : PNG_Info renames Parsed.Info;
      Bit_Depth : Natural renames Parsed.Bit_Depth;
      Interlace : Natural renames Parsed.Interlace;
      Palette : PNG_Palette renames Parsed.Palette;

      function IDAT_Byte
        (Logical_Pos : Positive) return Terminal.Common.Bytes.Byte
      is
         Remaining : Natural := Logical_Pos;
      begin
         for Index in 1 .. Parsed.IDAT_Count loop
            if Remaining <= Parsed.IDAT_Size (Index) then
               return PNG_Byte
                 (Parsed.IDAT_First (Index) + Remaining - 1);
            end if;
            Remaining := Remaining - Parsed.IDAT_Size (Index);
         end loop;
         return 0;
      end IDAT_Byte;

      Filter_BPP : constant Natural :=
        PNG_Support.Filter_BPP (Info.Color_Type, Bit_Depth);
      Expected : constant Natural :=
        PNG_Support.Inflated_Length
          (Info.Width, Info.Height, Info.Color_Type, Bit_Depth, Interlace);
      RGBA_Bytes : constant Natural :=
        RGBA_Decoded_Length (Info.Width, Info.Height);
      Inflate : PNG_Inflation.Decoder;
      Interlaced_Image : Image_Data_Holder;
      Output_Row : Image_Data_Holder;

      procedure Set_Failure (Status : Data_Decode_Status) is
      begin
         Result.Decode_Status := Status;
         Result.Decode_Complete := False;
      end Set_Failure;

      function Next_Inflated_Byte return Terminal.Common.Bytes.Byte is
         Status : Data_Decode_Status;
         Value : constant Terminal.Common.Bytes.Byte :=
           PNG_Inflation.Next (Inflate, IDAT_Byte'Access, Status);
      begin
         if Status /= Decode_Ok then
            Set_Failure (Status);
         end if;
         return Value;
      end Next_Inflated_Byte;

      procedure Write_Row_Pixels
        (This_Row  : Terminal.Common.Bytes.Byte_Array;
         Pass_Width, X_Start, Y, X_Step : Natural)
      is
         Status : Data_Decode_Status;
         Continue : Boolean := True;

         procedure Convert
           (Destination : in out Terminal.Common.Bytes.Byte_Array) is
         begin
            PNG_Pixels.Convert_Row
              (Info, Bit_Depth, Palette, Parsed.Palette_Count,
               Parsed.Gray_Transparent, Parsed.Red_Transparent,
               Parsed.Green_Transparent, Parsed.Blue_Transparent,
               This_Row, Pass_Width, X_Start, Y, X_Step,
               Interlaced => Interlace /= 0,
               Destination => Destination,
               Status => Status);
         end Convert;
      begin
         if Interlace = 0 then
            Output_Row.Fill (0);
            Output_Row.Modify (Convert'Access);
         else
            Interlaced_Image.Modify (Convert'Access);
         end if;

         if Status /= Decode_Ok then
            Set_Failure (Status);
         elsif Interlace = 0 then
            declare
               procedure Emit (Bytes : Terminal.Common.Bytes.Byte_Array) is
               begin
                  Row_Sink (Y, Bytes, Continue);
               end Emit;
            begin
               Output_Row.Read (Emit'Access);
            end;
            if not Continue then
               Set_Failure (Decode_Invalid_Byte);
            end if;
         end if;
      end Write_Row_Pixels;

      procedure Decode_Pass
        (Pass_Width, Pass_Height, X_Start, Y_Start, X_Step, Y_Step : Natural)
      is
         Pass_Row_Bytes : constant Natural :=
           PNG_Support.Row_Bytes (Pass_Width, Info.Color_Type, Bit_Depth);
      begin
         if Pass_Width = 0 or else Pass_Height = 0 then
            return;
         elsif Pass_Row_Bytes = 0 then
            Set_Failure (Decode_Preview_Truncated);
            return;
         end if;

         declare
            Prev_Row, This_Row : Image_Data_Holder;
         begin
            Terminal.App.Owned_Image_Data.Allocate (Prev_Row, Pass_Row_Bytes);
            Terminal.App.Owned_Image_Data.Allocate (This_Row, Pass_Row_Bytes);
            Terminal.App.Owned_Image_Data.Fill (Prev_Row, 0);
            Terminal.App.Owned_Image_Data.Fill (This_Row, 0);

            for Row in 0 .. Pass_Height - 1 loop
               declare
                  Filter : constant Natural := Natural (Next_Inflated_Byte);
               begin
                  if not Result.Decode_Complete then
                     return;
                  elsif Filter > 4 then
                     Set_Failure (Decode_Invalid_Byte);
                     return;
                  end if;

                  declare
                     procedure Filter_Current
                       (Current : in out Terminal.Common.Bytes.Byte_Array)
                     is
                        procedure With_Previous
                          (Previous : Terminal.Common.Bytes.Byte_Array) is
                        begin
                           for I in 1 .. Pass_Row_Bytes loop
                              declare
                                 Raw : constant Natural :=
                                   Natural (Next_Inflated_Byte);
                                 Left : constant Natural :=
                                   (if I > Filter_BPP
                                    then Natural
                                      (Current
                                         (Current'First + I - Filter_BPP - 1))
                                    else 0);
                                 Up : constant Natural :=
                                   Natural (Previous (Previous'First + I - 1));
                                 Upper_Left : constant Natural :=
                                   (if I > Filter_BPP
                                    then Natural
                                      (Previous
                                         (Previous'First + I - Filter_BPP - 1))
                                    else 0);
                                 Predictor : constant Natural :=
                                   (case Filter is
                                      when 0 => 0,
                                      when 1 => Left,
                                      when 2 => Up,
                                      when 3 => (Left + Up) / 2,
                                      when others => PNG_Support.Paeth
                                        (Left, Up, Upper_Left));
                              begin
                                 if not Result.Decode_Complete then
                                    return;
                                 end if;
                                 Current (Current'First + I - 1) :=
                                   Terminal.Common.Bytes.Byte
                                     ((Raw + Predictor) mod 256);
                              end;
                           end loop;
                        end With_Previous;
                     begin
                        Prev_Row.Read (With_Previous'Access);
                     end Filter_Current;

                     procedure Process_Row
                       (Current : Terminal.Common.Bytes.Byte_Array) is
                     begin
                        Write_Row_Pixels
                          (Current, Pass_Width, X_Start,
                           Y_Start + Row * Y_Step, X_Step);
                        if Result.Decode_Complete then
                           Prev_Row.Copy (Current);
                        end if;
                     end Process_Row;
                  begin
                     This_Row.Modify (Filter_Current'Access);
                     if Result.Decode_Complete then
                        This_Row.Read (Process_Row'Access);
                     end if;
                  end;
                  if not Result.Decode_Complete then
                     return;
                  end if;
               end;
            end loop;
         end;
      end Decode_Pass;

      procedure Emit_Interlaced_Rows is
         Row_Stride : constant Natural := Raw_Row_Stride (32, Info.Width);
      begin
         for Y in 0 .. Info.Height - 1 loop
            declare
               Source_First : constant Natural := Y * Row_Stride + 1;
               Continue : Boolean := True;
            begin
               declare
                  procedure Copy_Row
                    (Image : Terminal.Common.Bytes.Byte_Array) is
                  begin
                     Output_Row.Copy
                       (Image
                          (Image'First + Source_First - 1
                           .. Image'First + Source_First
                             + Output_Row.Length - 2));
                  end Copy_Row;
                  procedure Emit (Bytes : Terminal.Common.Bytes.Byte_Array) is
                  begin
                     Row_Sink (Y, Bytes, Continue);
                  end Emit;
               begin
                  Interlaced_Image.Read (Copy_Row'Access);
                  Output_Row.Read (Emit'Access);
               end;
               if not Continue then
                  Set_Failure (Decode_Invalid_Byte);
                  return;
               end if;
            end;
         end loop;
      end Emit_Interlaced_Rows;

      procedure Decode_Adam7 is
      begin
         Decode_Pass
           (PNG_Support.Pass_Size (Info.Width, 0, 8),
            PNG_Support.Pass_Size (Info.Height, 0, 8), 0, 0, 8, 8);
         if not Result.Decode_Complete then return; end if;
         Decode_Pass
           (PNG_Support.Pass_Size (Info.Width, 4, 8),
            PNG_Support.Pass_Size (Info.Height, 0, 8), 4, 0, 8, 8);
         if not Result.Decode_Complete then return; end if;
         Decode_Pass
           (PNG_Support.Pass_Size (Info.Width, 0, 4),
            PNG_Support.Pass_Size (Info.Height, 4, 8), 0, 4, 4, 8);
         if not Result.Decode_Complete then return; end if;
         Decode_Pass
           (PNG_Support.Pass_Size (Info.Width, 2, 4),
            PNG_Support.Pass_Size (Info.Height, 0, 4), 2, 0, 4, 4);
         if not Result.Decode_Complete then return; end if;
         Decode_Pass
           (PNG_Support.Pass_Size (Info.Width, 0, 2),
            PNG_Support.Pass_Size (Info.Height, 2, 4), 0, 2, 2, 4);
         if not Result.Decode_Complete then return; end if;
         Decode_Pass
           (PNG_Support.Pass_Size (Info.Width, 1, 2),
            PNG_Support.Pass_Size (Info.Height, 0, 2), 1, 0, 2, 2);
         if not Result.Decode_Complete then return; end if;
         Decode_Pass
           (PNG_Support.Pass_Size (Info.Width, 0, 1),
            PNG_Support.Pass_Size (Info.Height, 1, 2), 0, 1, 1, 2);
      end Decode_Adam7;

      Inflate_Status : Data_Decode_Status;
   begin
      if Expected = 0 or else RGBA_Bytes = 0 then
         Set_Failure (Decode_Preview_Truncated);
         Result.Decoded_Length := Max_Data_Preview_Length;
         return;
      elsif RGBA_Bytes > Max_Data_Preview_Length then
         Set_Failure (Decode_Preview_Truncated);
         Result.Decoded_Length := Max_Data_Preview_Length;
         return;
      end if;

      Result.Raw_Format := 32;
      Result.Pixel_Width := Info.Width;
      Result.Pixel_Height := Info.Height;
      Result.Decoded_Row_Stride_Bytes := Info.Width * 4;
      Result.Decode_Complete := True;
      Terminal.App.Owned_Image_Data.Allocate
        (Output_Row, Result.Decoded_Row_Stride_Bytes);
      if Interlace = 1 then
         Terminal.App.Owned_Image_Data.Allocate
           (Interlaced_Image, RGBA_Bytes);
         Terminal.App.Owned_Image_Data.Fill (Interlaced_Image, 0);
      end if;

      PNG_Inflation.Initialize
        (Inflate, Parsed.IDAT_Length, Expected, IDAT_Byte'Access,
         Inflate_Status);
      if Inflate_Status /= Decode_Ok then
         Set_Failure (Inflate_Status);
         return;
      end if;

      if Interlace = 0 then
         Decode_Pass (Info.Width, Info.Height, 0, 0, 1, 1);
      else
         Decode_Adam7;
      end if;
      if not Result.Decode_Complete then
         return;
      end if;

      PNG_Inflation.Finish
        (Inflate, IDAT_Byte'Access, Inflate_Status);
      if Inflate_Status /= Decode_Ok
        or else PNG_Inflation.Produced_Length (Inflate) /= Expected
      then
         Set_Failure (Decode_Invalid_Byte);
         return;
      end if;

      if Interlace = 1 then
         Emit_Interlaced_Rows;
         if not Result.Decode_Complete then
            return;
         end if;
      end if;

      Result.Decoded_Length := RGBA_Bytes;
      Result.Decode_Complete := True;
      Result.Decode_Status := Decode_Ok;
   exception
      when Storage_Error =>
         Set_Failure (Decode_Allocation_Failed);
   end;
end Decode_PNG_RGBA_Source_Rows;
