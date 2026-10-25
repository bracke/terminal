separate (Terminal.App.Graphics)
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
      use type Terminal.Common.Bytes.Byte;
      Signature : constant Terminal.Common.Bytes.Byte_Array (1 .. 8) :=
        (1 => 16#89#, 2 => 16#50#, 3 => 16#4E#, 4 => 16#47#,
         5 => 16#0D#, 6 => 16#0A#, 7 => 16#1A#, 8 => 16#0A#);
      Pos : Natural := 9;
      Info : PNG_Info;
      Bit_Depth : Natural := 0;
      Compression : Natural := 0;
      Filter_Method : Natural := 0;
      Interlace : Natural := 0;
      Max_IDAT_Ranges : constant Positive := 1024;
      IDAT_First : array (1 .. Max_IDAT_Ranges) of Natural := (others => 0);
      IDAT_Size : array (1 .. Max_IDAT_Ranges) of Natural := (others => 0);
      IDAT_Count : Natural := 0;
      IDAT_Length : Natural := 0;
      Palette : PNG_Palette :=
        (others => (R => 0, G => 0, B => 0, A => 16#FF#));
      Palette_Count : Natural := 0;
      Gray_Transparent : Natural := 256;
      Red_Transparent : Natural := 256;
      Green_Transparent : Natural := 256;
      Blue_Transparent : Natural := 256;
      Seen_IHDR : Boolean := False;
      Seen_PLTE : Boolean := False;
      Seen_TRNS : Boolean := False;
      Seen_IDAT : Boolean := False;
      IDAT_Closed : Boolean := False;
      Seen_IEND : Boolean := False;

      function U32_BE_Source (First : Positive) return Natural is
         Value : Interfaces.Unsigned_32 := 0;
      begin
         if First + 3 > Length then
            return 0;
         end if;
         for I in First .. First + 3 loop
            Value :=
              Interfaces.Shift_Left (Value, 8)
              or Interfaces.Unsigned_32 (PNG_Byte (I));
         end loop;
         if Value > Interfaces.Unsigned_32 (Natural'Last) then
            return 0;
         end if;
         return Natural (Value);
      end U32_BE_Source;

      function U32_BE_Source_Valid (First : Positive) return Boolean is
         Value : Interfaces.Unsigned_32 := 0;
      begin
         if First > Length or else Length - First < 3 then
            return False;
         end if;
         for I in First .. First + 3 loop
            Value :=
              Interfaces.Shift_Left (Value, 8)
              or Interfaces.Unsigned_32 (PNG_Byte (I));
         end loop;
         return Value <= Interfaces.Unsigned_32 (Natural'Last);
      end U32_BE_Source_Valid;

      function U32_BE_Source_Unsigned
        (First : Positive) return Interfaces.Unsigned_32
      is
         Value : Interfaces.Unsigned_32 := 0;
      begin
         for I in First .. First + 3 loop
            Value :=
              Interfaces.Shift_Left (Value, 8)
              or Interfaces.Unsigned_32 (PNG_Byte (I));
         end loop;
         return Value;
      end U32_BE_Source_Unsigned;

      function Chunk_CRC
        (First : Positive;
         Last  : Natural) return Interfaces.Unsigned_32
      is
         Value : Interfaces.Unsigned_32 := 16#FFFF_FFFF#;
      begin
         for I in First .. Last loop
            Value := Value xor Interfaces.Unsigned_32 (PNG_Byte (I));
            for Bit in 1 .. 8 loop
               Value :=
                 (if (Value and 1) /= 0
                  then Interfaces.Shift_Right (Value, 1) xor 16#EDB8_8320#
                  else Interfaces.Shift_Right (Value, 1));
            end loop;
         end loop;
         return Value xor 16#FFFF_FFFF#;
      end Chunk_CRC;
   begin
      if Length < 8 then
         Result.Decode_Status := Decode_Unsupported_Format;
         Result.Decode_Complete := False;
         return;
      end if;

      for I in Signature'Range loop
         if PNG_Byte (I) /= Signature (I) then
            Result.Decode_Status := Decode_Unsupported_Format;
            Result.Decode_Complete := False;
            return;
         end if;
      end loop;

      while Pos + 11 <= Length and then not Seen_IEND loop
         declare
            Chunk_Length : constant Natural := U32_BE_Source (Pos);
            Chunk_Bounds_Valid : constant Boolean :=
              U32_BE_Source_Valid (Pos)
              and then Chunk_Length <= Length - Pos - 11;
            Type_First : constant Natural := Pos + 4;
            Data_First : constant Natural := Pos + 8;
            Data_Last  : constant Natural :=
              (if Chunk_Bounds_Valid
               then Data_First + Chunk_Length - 1
               else Data_First - 1);
            Next_Pos   : constant Natural :=
              (if Chunk_Bounds_Valid
               then Pos + 12 + Chunk_Length
               else Pos);
            Is_IHDR : constant Boolean :=
              PNG_Byte (Type_First) = 16#49#
              and then PNG_Byte (Type_First + 1) = 16#48#
              and then PNG_Byte (Type_First + 2) = 16#44#
              and then PNG_Byte (Type_First + 3) = 16#52#;
            Is_IDAT : constant Boolean :=
              PNG_Byte (Type_First) = 16#49#
              and then PNG_Byte (Type_First + 1) = 16#44#
              and then PNG_Byte (Type_First + 2) = 16#41#
              and then PNG_Byte (Type_First + 3) = 16#54#;
            Is_PLTE : constant Boolean :=
              PNG_Byte (Type_First) = 16#50#
              and then PNG_Byte (Type_First + 1) = 16#4C#
              and then PNG_Byte (Type_First + 2) = 16#54#
              and then PNG_Byte (Type_First + 3) = 16#45#;
            Is_TRNS : constant Boolean :=
              PNG_Byte (Type_First) = 16#74#
              and then PNG_Byte (Type_First + 1) = 16#52#
              and then PNG_Byte (Type_First + 2) = 16#4E#
              and then PNG_Byte (Type_First + 3) = 16#53#;
            Is_IEND : constant Boolean :=
              PNG_Byte (Type_First) = 16#49#
              and then PNG_Byte (Type_First + 1) = 16#45#
              and then PNG_Byte (Type_First + 2) = 16#4E#
              and then PNG_Byte (Type_First + 3) = 16#44#;
            Chunk_Type_Valid : constant Boolean :=
              (for all Offset in 0 .. 3 =>
                 PNG_Byte (Type_First + Offset) in
                   16#41# .. 16#5A# | 16#61# .. 16#7A#)
              and then PNG_Byte (Type_First + 2) in 16#41# .. 16#5A#;
         begin
            if not Chunk_Bounds_Valid then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               return;
            end if;
            if not Chunk_Type_Valid then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               return;
            end if;
            if Chunk_CRC (Type_First, Data_Last) /=
              U32_BE_Source_Unsigned (Data_Last + 1)
            then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               return;
            end if;

            if (not Seen_IHDR and then not Is_IHDR)
              or else (Seen_IHDR and then Is_IHDR)
              or else (Seen_IDAT and then not Is_IDAT and then not Is_IEND
                       and then (Is_PLTE or else Is_TRNS))
              or else (IDAT_Closed and then Is_IDAT)
            then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               return;
            end if;

            if Seen_IDAT and then not Is_IDAT then
               IDAT_Closed := True;
            end if;

            if Is_IHDR then
               if Chunk_Length /= 13 then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  return;
               end if;
               Info.Width := U32_BE_Source (Data_First);
               Info.Height := U32_BE_Source (Data_First + 4);
               Bit_Depth := Natural (PNG_Byte (Data_First + 8));
               Info.Color_Type := Natural (PNG_Byte (Data_First + 9));
               Compression := Natural (PNG_Byte (Data_First + 10));
               Filter_Method := Natural (PNG_Byte (Data_First + 11));
               Interlace := Natural (PNG_Byte (Data_First + 12));
               Seen_IHDR := True;
            elsif Is_IDAT then
               if Chunk_Length > Max_Data_Preview_Length - IDAT_Length then
                  Result.Decode_Status := Decode_Preview_Truncated;
                  Result.Decode_Complete := False;
                  return;
               end if;
               if Chunk_Length > 0 then
                  if IDAT_Count = Max_IDAT_Ranges then
                     Result.Decode_Status := Decode_Preview_Truncated;
                     Result.Decode_Complete := False;
                     return;
                  end if;
                  IDAT_Count := IDAT_Count + 1;
                  IDAT_First (IDAT_Count) := Data_First;
                  IDAT_Size (IDAT_Count) := Chunk_Length;
               end if;
               IDAT_Length := IDAT_Length + Chunk_Length;
               Seen_IDAT := True;
            elsif Is_PLTE then
               if Seen_PLTE
                 or else Info.Color_Type in 0 | 4
                 or else Chunk_Length = 0
                 or else Chunk_Length mod 3 /= 0
                 or else Chunk_Length / 3 > 256
                 or else
                   (Info.Color_Type = 3
                    and then Chunk_Length / 3 > 2 ** Bit_Depth)
               then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  return;
               end if;
               Palette_Count := Chunk_Length / 3;
               for Index in 0 .. Palette_Count - 1 loop
                  Palette (Index) :=
                    (R => PNG_Byte (Data_First + Index * 3),
                     G => PNG_Byte (Data_First + Index * 3 + 1),
                     B => PNG_Byte (Data_First + Index * 3 + 2),
                     A => 16#FF#);
               end loop;
               Seen_PLTE := True;
            elsif Is_TRNS then
               if Seen_TRNS
                 or else Info.Color_Type in 4 | 6
                 or else (Info.Color_Type = 0 and then Chunk_Length /= 2)
                 or else (Info.Color_Type = 2 and then Chunk_Length /= 6)
                 or else
                   (Info.Color_Type = 3
                    and then
                      (not Seen_PLTE
                       or else Chunk_Length = 0
                       or else Chunk_Length > Palette_Count))
               then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  return;
               elsif Info.Color_Type = 0 then
                  Gray_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First), 4 => PNG_Byte (Data_First + 1)), 1);
               elsif Info.Color_Type = 2 then
                  Red_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First), 4 => PNG_Byte (Data_First + 1)), 1);
                  Green_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First + 2), 4 => PNG_Byte (Data_First + 3)), 1);
                  Blue_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First + 4), 4 => PNG_Byte (Data_First + 5)), 1);
               elsif Info.Color_Type = 3 then
                  for Index in 0 .. Natural'Min (Chunk_Length, 256) - 1 loop
                     Palette (Index).A := PNG_Byte (Data_First + Index);
                  end loop;
               end if;
               Seen_TRNS := True;
            elsif Is_IEND then
               if Chunk_Length /= 0 or else not Seen_IDAT then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  return;
               end if;
               Seen_IEND := True;
            elsif PNG_Byte (Type_First) in 16#41# .. 16#5A# then
               --  Unknown critical chunks cannot be ignored safely.
               Result.Decode_Status := Decode_Unsupported_Format;
               Result.Decode_Complete := False;
               return;
            end if;

            Pos := Next_Pos;
         end;
      end loop;

      if Seen_IEND and then Pos /= Length + 1 then
         Result.Decode_Status := Decode_Trailing_Data;
         Result.Decode_Complete := False;
         return;
      end if;

      if not Seen_IHDR
        or else not Seen_IEND
        or else IDAT_Length = 0
        or else IDAT_Count = 0
        or else Info.Width = 0
        or else Info.Height = 0
        or else not PNG_Bit_Depth_Allowed (Info.Color_Type, Bit_Depth)
        or else Compression /= 0
        or else Filter_Method /= 0
        or else Interlace > 1
        or else
          (Info.Color_Type /= 0
           and then Info.Color_Type /= 2
           and then Info.Color_Type /= 3
           and then Info.Color_Type /= 4
           and then Info.Color_Type /= 6)
        or else (Info.Color_Type = 3 and then not Seen_PLTE)
      then
         Result.Decode_Status := Decode_Unsupported_Format;
         Result.Decode_Complete := False;
         return;
      end if;

      declare
         function IDAT_Byte (Logical_Pos : Natural)
            return Terminal.Common.Bytes.Byte
         is
            Remaining : Natural := Logical_Pos;
         begin
            for Index in 1 .. IDAT_Count loop
               if Remaining <= IDAT_Size (Index) then
                  return PNG_Byte (IDAT_First (Index) + Remaining - 1);
               end if;
               Remaining := Remaining - IDAT_Size (Index);
            end loop;
            return 0;
         end IDAT_Byte;

         CMF : constant Natural :=
           (if IDAT_Length >= 2 then Natural (IDAT_Byte (1)) else 0);
         FLG : constant Natural :=
           (if IDAT_Length >= 2 then Natural (IDAT_Byte (2)) else 0);
         Zlib_Header_Ok : constant Boolean :=
           IDAT_Length >= 6
           and then CMF mod 16 = 8
           and then (CMF / 16) <= 7
           and then FLG / 32 mod 2 = 0
           and then (CMF * 256 + FLG) mod 31 = 0;
         Filter_BPP : constant Natural :=
           PNG_Filter_BPP (Info.Color_Type, Bit_Depth);
         Expected : constant Natural :=
           PNG_Inflated_Length
             (Info.Width, Info.Height, Info.Color_Type, Bit_Depth, Interlace);
         RGBA_Bytes : constant Natural :=
           RGBA_Decoded_Length (Info.Width, Info.Height);
         Deflate_Pos : Natural := 3;
         Deflate_Last : constant Natural := IDAT_Length - 4;
         Inflate : Inflate_Filter_Holder;
         Inflated_Count : Natural := 0;
         Inflate_Ended : Boolean := False;
         Inflate_Failed : Boolean := False;
         Out_Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
         Out_Last : Ada.Streams.Stream_Element_Offset :=
           Out_Buffer'First - 1;
         Out_Pos : Ada.Streams.Stream_Element_Offset := Out_Buffer'First;
         Interlaced_Image : Image_Data_Holder;
         Output_Row : Image_Data_Holder;

         procedure Mark_Inflate_Invalid is
         begin
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            Inflate_Failed := True;
         end Mark_Inflate_Invalid;

         procedure Refill_Inflated is
         begin
            if Inflate_Ended or else Inflate_Failed then
               return;
            end if;
            if Zlib.Stream_End (Inflate.Filter) then
               Inflate_Ended := True;
               return;
            end if;

            while Out_Pos > Out_Last loop
               Out_Buffer := (others => 0);
               Out_Last := Out_Buffer'First - 1;
               Out_Pos := Out_Buffer'First;

               if Deflate_Pos <= Deflate_Last then
                  declare
                     In_Count : constant Natural :=
                       Natural'Min (Deflate_Last - Deflate_Pos + 1, 4096);
                     In_Data : Ada.Streams.Stream_Element_Array
                       (1 .. Ada.Streams.Stream_Element_Offset (In_Count));
                     In_Last : Ada.Streams.Stream_Element_Offset;
                  begin
                     for I in In_Data'Range loop
                        In_Data (I) :=
                          Ada.Streams.Stream_Element
                            (IDAT_Byte
                               (Deflate_Pos + Natural (I - In_Data'First)));
                     end loop;
                     Zlib.Translate
                       (Inflate.Filter,
                        In_Data,
                        In_Last,
                        Out_Buffer,
                        Out_Last,
                        Zlib.No_Flush);
                     if In_Last >= In_Data'First then
                        Deflate_Pos :=
                          Deflate_Pos
                          + Natural (In_Last - In_Data'First + 1);
                     elsif Out_Last < Out_Buffer'First then
                        Mark_Inflate_Invalid;
                        return;
                     end if;
                     if Zlib.Stream_End (Inflate.Filter) then
                        Inflate_Ended := True;
                     end if;
                  end;
               else
                  Zlib.Flush
                    (Inflate.Filter, Out_Buffer, Out_Last, Zlib.Finish);
                  if Out_Last < Out_Buffer'First then
                     if Zlib.Stream_End (Inflate.Filter) then
                        Inflate_Ended := True;
                        return;
                     else
                        Mark_Inflate_Invalid;
                        return;
                     end if;
                  end if;
               end if;

               if Out_Last >= Out_Buffer'First then
                  return;
               end if;
            end loop;
         exception
            when Zlib.Zlib_Error | Zlib.Status_Error =>
               Mark_Inflate_Invalid;
         end Refill_Inflated;

         function Next_Inflated_Byte return Terminal.Common.Bytes.Byte is
         begin
            if Out_Pos > Out_Last then
               Refill_Inflated;
            end if;

            if Inflate_Failed or else Out_Pos > Out_Last then
               Mark_Inflate_Invalid;
               return 0;
            end if;

            declare
               Value : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte (Out_Buffer (Out_Pos));
            begin
               Out_Pos := Out_Pos + 1;
               Inflated_Count := Inflated_Count + 1;
               if Inflated_Count > Expected then
                  Mark_Inflate_Invalid;
               end if;
               return Value;
            end;
         end Next_Inflated_Byte;

         procedure Finish_Inflate is
         begin
            if Inflate_Failed then
               return;
            end if;

            loop
               if Out_Pos <= Out_Last then
                  Mark_Inflate_Invalid;
                  return;
               end if;

               exit when Inflate_Ended;
               Refill_Inflated;
               exit when Inflate_Failed;
            end loop;

            if Inflate_Failed
              or else Inflated_Count /= Expected
              or else not Inflate_Ended
            then
               Mark_Inflate_Invalid;
            end if;
         end Finish_Inflate;

         procedure Write_Row_Pixels
           (This_Row : Terminal.Common.Bytes.Byte_Array;
            Pass_Width : Natural;
            X_Start    : Natural;
            Y          : Natural;
            X_Step     : Natural)
         is
            Continue : Boolean := True;
         begin
            Output_Row.Data.all := (others => 0);
            for X in 0 .. Pass_Width - 1 loop
               declare
                  Actual_X : constant Natural := X_Start + X * X_Step;
                  Out_Pos : constant Natural :=
                    (if Interlace = 0
                     then Actual_X * 4 + 1
                     else (Y * Info.Width + Actual_X) * 4 + 1);
                  Src_8 : constant Natural :=
                    X * PNG_Filter_BPP (Info.Color_Type, 8) + 1;
                  Src_16 : constant Natural :=
                    X * PNG_Filter_BPP (Info.Color_Type, 16) + 1;
                  Gray : Natural;
                  Red  : Natural;
                  Green : Natural;
                  Blue : Natural;
                  Alpha : Natural := 255;
               begin
                  case Info.Color_Type is
                     when 0 =>
                        if Bit_Depth = 16 then
                           Gray := PNG_Sample_16 (This_Row, Src_16);
                        elsif Bit_Depth = 8 then
                           Gray := Natural (This_Row (Src_8));
                        else
                           Gray := PNG_Packed_Sample (This_Row, Bit_Depth, X);
                        end if;
                        Red := PNG_Scale_Sample (Gray, Bit_Depth);
                        Green := Red;
                        Blue := Red;
                        if Gray = Gray_Transparent then
                           Alpha := 0;
                        end if;
                     when 2 =>
                        if Bit_Depth = 16 then
                           Red := PNG_Sample_16 (This_Row, Src_16);
                           Green := PNG_Sample_16 (This_Row, Src_16 + 2);
                           Blue := PNG_Sample_16 (This_Row, Src_16 + 4);
                        else
                           Red := Natural (This_Row (Src_8));
                           Green := Natural (This_Row (Src_8 + 1));
                           Blue := Natural (This_Row (Src_8 + 2));
                        end if;
                        if Red = Red_Transparent
                          and then Green = Green_Transparent
                          and then Blue = Blue_Transparent
                        then
                           Alpha := 0;
                        end if;
                        Red := PNG_Scale_Sample (Red, Bit_Depth);
                        Green := PNG_Scale_Sample (Green, Bit_Depth);
                        Blue := PNG_Scale_Sample (Blue, Bit_Depth);
                     when 3 =>
                        declare
                           Index : constant Natural :=
                             (if Bit_Depth = 8
                              then Natural (This_Row (Src_8))
                              else PNG_Packed_Sample (This_Row, Bit_Depth, X));
                        begin
                           if Index >= Palette_Count then
                              Result.Decode_Status := Decode_Invalid_Byte;
                              Result.Decode_Complete := False;
                              return;
                           end if;
                           Red := Natural (Palette (Index).R);
                           Green := Natural (Palette (Index).G);
                           Blue := Natural (Palette (Index).B);
                           Alpha := Natural (Palette (Index).A);
                        end;
                     when 4 =>
                        if Bit_Depth = 16 then
                           Gray := PNG_Sample_16 (This_Row, Src_16);
                           Alpha := PNG_Sample_16 (This_Row, Src_16 + 2);
                        else
                           Gray := Natural (This_Row (Src_8));
                           Alpha := Natural (This_Row (Src_8 + 1));
                        end if;
                        Red := PNG_Scale_Sample (Gray, Bit_Depth);
                        Green := Red;
                        Blue := Red;
                        Alpha := PNG_Scale_Sample (Alpha, Bit_Depth);
                     when others =>
                        if Bit_Depth = 16 then
                           Red := PNG_Sample_16 (This_Row, Src_16);
                           Green := PNG_Sample_16 (This_Row, Src_16 + 2);
                           Blue := PNG_Sample_16 (This_Row, Src_16 + 4);
                           Alpha := PNG_Sample_16 (This_Row, Src_16 + 6);
                        else
                           Red := Natural (This_Row (Src_8));
                           Green := Natural (This_Row (Src_8 + 1));
                           Blue := Natural (This_Row (Src_8 + 2));
                           Alpha := Natural (This_Row (Src_8 + 3));
                        end if;
                        Red := PNG_Scale_Sample (Red, Bit_Depth);
                        Green := PNG_Scale_Sample (Green, Bit_Depth);
                        Blue := PNG_Scale_Sample (Blue, Bit_Depth);
                        Alpha := PNG_Scale_Sample (Alpha, Bit_Depth);
                  end case;

                  if Interlace = 0 then
                     Output_Row.Data (Out_Pos) :=
                       Terminal.Common.Bytes.Byte (Red);
                     Output_Row.Data (Out_Pos + 1) :=
                       Terminal.Common.Bytes.Byte (Green);
                     Output_Row.Data (Out_Pos + 2) :=
                       Terminal.Common.Bytes.Byte (Blue);
                     Output_Row.Data (Out_Pos + 3) :=
                       Terminal.Common.Bytes.Byte (Alpha);
                  else
                     Interlaced_Image.Data (Out_Pos) :=
                       Terminal.Common.Bytes.Byte (Red);
                     Interlaced_Image.Data (Out_Pos + 1) :=
                       Terminal.Common.Bytes.Byte (Green);
                     Interlaced_Image.Data (Out_Pos + 2) :=
                       Terminal.Common.Bytes.Byte (Blue);
                     Interlaced_Image.Data (Out_Pos + 3) :=
                       Terminal.Common.Bytes.Byte (Alpha);
                  end if;
               end;
            end loop;

            if Interlace = 0 then
               Row_Sink (Y, Output_Row.Data.all, Continue);
               if not Continue then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
               end if;
            end if;
         end Write_Row_Pixels;

         procedure Decode_Pass
           (Pass_Width  : Natural;
            Pass_Height : Natural;
            X_Start     : Natural;
            Y_Start     : Natural;
            X_Step      : Natural;
            Y_Step      : Natural)
         is
            Pass_Row_Bytes : constant Natural :=
              PNG_Row_Bytes (Pass_Width, Info.Color_Type, Bit_Depth);
         begin
            if Pass_Width = 0 or else Pass_Height = 0 then
               return;
            elsif Pass_Row_Bytes = 0 then
               Result.Decode_Status := Decode_Preview_Truncated;
               Result.Decode_Complete := False;
               return;
            end if;

            declare
               Prev_Row : Image_Data_Holder;
               This_Row : Image_Data_Holder;
            begin
               Prev_Row.Data :=
                 new Terminal.Common.Bytes.Byte_Array (1 .. Pass_Row_Bytes);
               This_Row.Data :=
                 new Terminal.Common.Bytes.Byte_Array (1 .. Pass_Row_Bytes);
               Prev_Row.Data.all := (others => 0);
               This_Row.Data.all := (others => 0);
               for Row in 0 .. Pass_Height - 1 loop
                  declare
                     Filter : constant Natural :=
                       Natural (Next_Inflated_Byte);
                  begin
                     if not Result.Decode_Complete then
                        return;
                     end if;
                     if Filter > 4 then
                        Result.Decode_Status := Decode_Invalid_Byte;
                        Result.Decode_Complete := False;
                        return;
                     end if;

                     for I in 1 .. Pass_Row_Bytes loop
                        declare
                           Raw : constant Natural :=
                             Natural (Next_Inflated_Byte);
                           Left : constant Natural :=
                             (if I > Filter_BPP
                              then Natural (This_Row.Data (I - Filter_BPP))
                              else 0);
                           Up : constant Natural :=
                             Natural (Prev_Row.Data (I));
                           Upper_Left : constant Natural :=
                             (if I > Filter_BPP
                              then Natural (Prev_Row.Data (I - Filter_BPP))
                              else 0);
                           Predictor : constant Natural :=
                             (case Filter is
                                when 0 => 0,
                                when 1 => Left,
                                when 2 => Up,
                                when 3 => (Left + Up) / 2,
                                when others => Paeth (Left, Up, Upper_Left));
                        begin
                           if not Result.Decode_Complete then
                              return;
                           end if;
                           This_Row.Data (I) :=
                             Terminal.Common.Bytes.Byte
                               ((Raw + Predictor) mod 256);
                        end;
                     end loop;

                     Write_Row_Pixels
                       (This_Row.Data.all,
                        Pass_Width,
                        X_Start,
                        Y_Start + Row * Y_Step,
                        X_Step);
                     if not Result.Decode_Complete
                       and then Result.Decode_Status = Decode_Invalid_Byte
                     then
                        return;
                     end if;

                     Prev_Row.Data.all := This_Row.Data.all;
                  end;
               end loop;
            end;
         end Decode_Pass;

         procedure Emit_Interlaced_Rows is
         begin
            for Y in 0 .. Info.Height - 1 loop
               declare
                  Row_Stride : constant Natural := Raw_Row_Stride (32, Info.Width);
                  Source_First : constant Natural := Y * Row_Stride + 1;
                  Continue : Boolean := True;
               begin
                  for I in Output_Row.Data'Range loop
                     Output_Row.Data (I) :=
                       Interlaced_Image.Data
                         (Source_First + I - Output_Row.Data'First);
                  end loop;
                  Row_Sink (Y, Output_Row.Data.all, Continue);
                  if not Continue then
                     Result.Decode_Status := Decode_Invalid_Byte;
                     Result.Decode_Complete := False;
                     return;
                  end if;
               end;
            end loop;
         end Emit_Interlaced_Rows;

      begin
         if Expected = 0 or else RGBA_Bytes = 0 then
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            Result.Decoded_Length := Max_Data_Preview_Length;
            return;
         elsif not Zlib_Header_Ok then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            return;
         elsif RGBA_Bytes > Max_Data_Preview_Length then
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            Result.Decoded_Length := Max_Data_Preview_Length;
            return;
         end if;

         Result.Raw_Format := 32;
         Result.Pixel_Width := Info.Width;
         Result.Pixel_Height := Info.Height;
         Result.Decoded_Row_Stride_Bytes := Info.Width * 4;
         Result.Decode_Complete := True;
         Output_Row.Data :=
           new Terminal.Common.Bytes.Byte_Array
             (1 .. Result.Decoded_Row_Stride_Bytes);
         Zlib.Inflate_Init (Inflate.Filter, Zlib.Raw_Deflate);
         Inflate.Opened := True;
         if Interlace = 1 then
            Interlaced_Image.Data :=
              new Terminal.Common.Bytes.Byte_Array (1 .. RGBA_Bytes);
            Interlaced_Image.Data.all := (others => 0);
         end if;

         if Interlace = 0 then
            Decode_Pass (Info.Width, Info.Height, 0, 0, 1, 1);
         else
            Decode_Pass
              (PNG_Pass_Size (Info.Width, 0, 8),
               PNG_Pass_Size (Info.Height, 0, 8), 0, 0, 8, 8);
            if not Result.Decode_Complete then
               return;
            end if;
            Decode_Pass
              (PNG_Pass_Size (Info.Width, 4, 8),
               PNG_Pass_Size (Info.Height, 0, 8), 4, 0, 8, 8);
            if not Result.Decode_Complete then
               return;
            end if;
            Decode_Pass
              (PNG_Pass_Size (Info.Width, 0, 4),
               PNG_Pass_Size (Info.Height, 4, 8), 0, 4, 4, 8);
            if not Result.Decode_Complete then
               return;
            end if;
            Decode_Pass
              (PNG_Pass_Size (Info.Width, 2, 4),
               PNG_Pass_Size (Info.Height, 0, 4), 2, 0, 4, 4);
            if not Result.Decode_Complete then
               return;
            end if;
            Decode_Pass
              (PNG_Pass_Size (Info.Width, 0, 2),
               PNG_Pass_Size (Info.Height, 2, 4), 0, 2, 2, 4);
            if not Result.Decode_Complete then
               return;
            end if;
            Decode_Pass
              (PNG_Pass_Size (Info.Width, 1, 2),
               PNG_Pass_Size (Info.Height, 0, 2), 1, 0, 2, 2);
            if not Result.Decode_Complete then
               return;
            end if;
            Decode_Pass
              (PNG_Pass_Size (Info.Width, 0, 1),
               PNG_Pass_Size (Info.Height, 1, 2), 0, 1, 1, 2);
         end if;

         if not Result.Decode_Complete then
            return;
         end if;

         Finish_Inflate;
         if not Result.Decode_Complete then
            return;
         end if;

         if Inflated_Count /= Expected then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
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
            Result.Decode_Status := Decode_Allocation_Failed;
            Result.Decode_Complete := False;
      end;
end Decode_PNG_RGBA_Source_Rows;
