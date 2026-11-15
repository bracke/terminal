with Interfaces;
with Terminal.App.Graphics.PNG_Support;

package body Terminal.App.Graphics.PNG_Chunks is
   use type Interfaces.Unsigned_32;
   use type Terminal.Common.Bytes.Byte;

   procedure Parse
     (Length   : Natural;
      PNG_Byte : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Parsed   : out Parsed_Image;
      Status   : out Data_Decode_Status)
   is
      Signature : constant Terminal.Common.Bytes.Byte_Array (1 .. 8) :=
        (1 => 16#89#, 2 => 16#50#, 3 => 16#4E#, 4 => 16#47#,
         5 => 16#0D#, 6 => 16#0A#, 7 => 16#1A#, 8 => 16#0A#);
      Pos           : Natural := 9;
      Compression   : Natural := 0;
      Filter_Method : Natural := 0;
      Seen_IHDR     : Boolean := False;
      Seen_PLTE     : Boolean := False;
      Seen_TRNS     : Boolean := False;
      Seen_IDAT     : Boolean := False;
      IDAT_Closed   : Boolean := False;
      Seen_IEND     : Boolean := False;

      function U32_BE_Source (First : Positive) return Natural is
         Value : Interfaces.Unsigned_32 := 0;
      begin
         if First + 3 > Length then
            return 0;
         end if;
         for I in First .. First + 3 loop
            Value := Interfaces.Shift_Left (Value, 8)
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
            Value := Interfaces.Shift_Left (Value, 8)
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
            Value := Interfaces.Shift_Left (Value, 8)
              or Interfaces.Unsigned_32 (PNG_Byte (I));
         end loop;
         return Value;
      end U32_BE_Source_Unsigned;

      function Chunk_CRC
        (First : Positive; Last : Natural) return Interfaces.Unsigned_32
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

      procedure Fail (Reason : Data_Decode_Status) is
      begin
         Status := Reason;
      end Fail;
   begin
      Parsed := (others => <>);
      Status := Decode_Not_Attempted;
      if Length < Signature'Length then
         Fail (Decode_Unsupported_Format);
         return;
      end if;
      for I in Signature'Range loop
         if PNG_Byte (I) /= Signature (I) then
            Fail (Decode_Unsupported_Format);
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
               then Data_First + Chunk_Length - 1 else Data_First - 1);
            Next_Pos : constant Natural :=
              (if Chunk_Bounds_Valid then Pos + 12 + Chunk_Length else Pos);
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
            if not Chunk_Bounds_Valid or else not Chunk_Type_Valid then
               Fail (Decode_Invalid_Byte);
               return;
            elsif Chunk_CRC (Type_First, Data_Last) /=
              U32_BE_Source_Unsigned (Data_Last + 1)
            then
               Fail (Decode_Invalid_Byte);
               return;
            elsif (not Seen_IHDR and then not Is_IHDR)
              or else (Seen_IHDR and then Is_IHDR)
              or else (Seen_IDAT and then not Is_IDAT and then not Is_IEND
                       and then (Is_PLTE or else Is_TRNS))
              or else (IDAT_Closed and then Is_IDAT)
            then
               Fail (Decode_Invalid_Byte);
               return;
            end if;

            if Seen_IDAT and then not Is_IDAT then
               IDAT_Closed := True;
            end if;

            if Is_IHDR then
               if Chunk_Length /= 13 then
                  Fail (Decode_Invalid_Byte);
                  return;
               end if;
               Parsed.Info.Width := U32_BE_Source (Data_First);
               Parsed.Info.Height := U32_BE_Source (Data_First + 4);
               Parsed.Bit_Depth := Natural (PNG_Byte (Data_First + 8));
               Parsed.Info.Color_Type := Natural (PNG_Byte (Data_First + 9));
               Compression := Natural (PNG_Byte (Data_First + 10));
               Filter_Method := Natural (PNG_Byte (Data_First + 11));
               Parsed.Interlace := Natural (PNG_Byte (Data_First + 12));
               Seen_IHDR := True;
               if Parsed.Info.Width = 0
                 or else Parsed.Info.Height = 0
                 or else not PNG_Support.Bit_Depth_Allowed
                   (Parsed.Info.Color_Type, Parsed.Bit_Depth)
                 or else Compression /= 0
                 or else Filter_Method /= 0
                 or else Parsed.Interlace > 1
               then
                  Fail (Decode_Unsupported_Format);
                  return;
               end if;
            elsif Is_IDAT then
               if Chunk_Length > Max_Data_Preview_Length - Parsed.IDAT_Length
               then
                  Fail (Decode_Preview_Truncated);
                  return;
               elsif Chunk_Length > 0 then
                  if Parsed.IDAT_Count = Max_IDAT_Ranges then
                     Fail (Decode_Preview_Truncated);
                     return;
                  end if;
                  Parsed.IDAT_Count := Parsed.IDAT_Count + 1;
                  Parsed.IDAT_First (Parsed.IDAT_Count) := Data_First;
                  Parsed.IDAT_Size (Parsed.IDAT_Count) := Chunk_Length;
               end if;
               Parsed.IDAT_Length := Parsed.IDAT_Length + Chunk_Length;
               Seen_IDAT := True;
            elsif Is_PLTE then
               if Seen_PLTE or else Parsed.Info.Color_Type in 0 | 4
                 or else Chunk_Length = 0 or else Chunk_Length mod 3 /= 0
                 or else Chunk_Length / 3 > 256
                 or else (Parsed.Info.Color_Type = 3
                          and then Chunk_Length / 3 > 2 ** Parsed.Bit_Depth)
               then
                  Fail (Decode_Invalid_Byte);
                  return;
               end if;
               Parsed.Palette_Count := Chunk_Length / 3;
               for Index in 0 .. Parsed.Palette_Count - 1 loop
                  Parsed.Palette (Index) :=
                    (R => PNG_Byte (Data_First + Index * 3),
                     G => PNG_Byte (Data_First + Index * 3 + 1),
                     B => PNG_Byte (Data_First + Index * 3 + 2),
                     A => 16#FF#);
               end loop;
               Seen_PLTE := True;
            elsif Is_TRNS then
               if Seen_TRNS or else Parsed.Info.Color_Type in 4 | 6
                 or else (Parsed.Info.Color_Type = 0 and then Chunk_Length /= 2)
                 or else (Parsed.Info.Color_Type = 2 and then Chunk_Length /= 6)
                 or else (Parsed.Info.Color_Type = 3
                          and then (not Seen_PLTE or else Chunk_Length = 0
                                    or else Chunk_Length > Parsed.Palette_Count))
               then
                  Fail (Decode_Invalid_Byte);
                  return;
               elsif Parsed.Info.Color_Type = 0 then
                  Parsed.Gray_Transparent :=
                    Natural (PNG_Byte (Data_First)) * 256
                    + Natural (PNG_Byte (Data_First + 1));
               elsif Parsed.Info.Color_Type = 2 then
                  Parsed.Red_Transparent :=
                    Natural (PNG_Byte (Data_First)) * 256
                    + Natural (PNG_Byte (Data_First + 1));
                  Parsed.Green_Transparent :=
                    Natural (PNG_Byte (Data_First + 2)) * 256
                    + Natural (PNG_Byte (Data_First + 3));
                  Parsed.Blue_Transparent :=
                    Natural (PNG_Byte (Data_First + 4)) * 256
                    + Natural (PNG_Byte (Data_First + 5));
               else
                  for Index in 0 .. Natural'Min (Chunk_Length, 256) - 1 loop
                     Parsed.Palette (Index).A := PNG_Byte (Data_First + Index);
                  end loop;
               end if;
               Seen_TRNS := True;
            elsif Is_IEND then
               if Chunk_Length /= 0 or else not Seen_IDAT then
                  Fail (Decode_Invalid_Byte);
                  return;
               end if;
               Seen_IEND := True;
            elsif PNG_Byte (Type_First) in 16#41# .. 16#5A# then
               Fail (Decode_Unsupported_Format);
               return;
            end if;
            Pos := Next_Pos;
         end;
      end loop;

      if Seen_IEND and then Pos /= Length + 1 then
         Fail (Decode_Trailing_Data);
      elsif not Seen_IHDR or else not Seen_IEND
        or else Parsed.IDAT_Length = 0 or else Parsed.IDAT_Count = 0
        or else (Parsed.Info.Color_Type = 3 and then not Seen_PLTE)
      then
         Fail (Decode_Unsupported_Format);
      else
         Status := Decode_Ok;
      end if;
   end Parse;
end Terminal.App.Graphics.PNG_Chunks;
