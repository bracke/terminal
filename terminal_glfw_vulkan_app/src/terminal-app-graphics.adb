with Ada.Streams;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Ada.Finalization;
with Ada.Unchecked_Deallocation;
with Zlib;

package body Terminal.App.Graphics is
   use type Ada.Streams.Stream_Element_Offset;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Zlib.Status_Code;

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);
   type Inflate_Filter_Holder is
     new Ada.Finalization.Limited_Controlled with record
      Filter : Zlib.Filter_Type;
      Opened : Boolean := False;
   end record;
   overriding procedure Finalize (Holder : in out Inflate_Filter_Holder);

   type Image_Data_Holder is new Ada.Finalization.Limited_Controlled with record
      Data : Terminal.App.Render_Model.Image_Data_Access := null;
   end record;
   overriding procedure Finalize (Holder : in out Image_Data_Holder);

   overriding procedure Finalize (Holder : in out Inflate_Filter_Holder) is
   begin
      if Holder.Opened then
         begin
            Zlib.Close (Holder.Filter, Ignore_Error => True);
         exception
            when others =>
               null;
         end;
         Holder.Opened := False;
      end if;
   end Finalize;

   overriding procedure Finalize (Holder : in out Image_Data_Holder) is
   begin
      if Holder.Data /= null then
         Free_Image_Data (Holder.Data);
         Holder.Data := null;
      end if;
   end Finalize;

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Preview_Text (Event : Terminal.Core.Graphics_Event) return String is
   begin
      if Event.Preview_Length = 0 then
         return "";
      end if;
      return Event.Preview (1 .. Event.Preview_Length);
   end Preview_Text;

   procedure Ensure_Bytes (Result : in out Graphics_Data_Preview) is
   begin
      if Result.Bytes = null then
         Result.Bytes :=
           new Terminal.Common.Bytes.Byte_Array (1 .. Max_Data_Preview_Length);
         Result.Bytes.all := (others => 0);
      end if;
   end Ensure_Bytes;

   procedure Ensure_Bytes
     (Result   : in out Graphics_Data_Preview;
      Capacity : Natural)
   is
      Actual : constant Natural :=
        Natural'Min (Natural'Max (Capacity, 1), Max_Data_Preview_Length);
   begin
      if Result.Bytes = null then
         Result.Bytes :=
           new Terminal.Common.Bytes.Byte_Array (1 .. Actual);
         Result.Bytes.all := (others => 0);
      elsif Result.Bytes'Length < Actual then
         Free_Image_Data (Result.Bytes);
         Result.Bytes :=
           new Terminal.Common.Bytes.Byte_Array (1 .. Actual);
         Result.Bytes.all := (others => 0);
      end if;
   end Ensure_Bytes;

   procedure Reset_Bytes (Result : in out Graphics_Data_Preview) is
   begin
      if Result.Bytes /= null then
         Result.Bytes.all := (others => 0);
      end if;
   end Reset_Bytes;

   procedure Release (Data : in out Graphics_Data_Preview) is
   begin
      if Data.Bytes /= null then
         Free_Image_Data (Data.Bytes);
         Data.Bytes := null;
      end if;
      Data.Decoded_Length := 0;
      Data.Decoded_Row_Stride_Bytes := 0;
   end Release;

   function Parse_Natural (Text : String) return Natural is
      Value : Natural := 0;
   begin
      if Text'Length = 0 then
         return 0;
      end if;

      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return 0;
         end if;
         declare
            Digit : constant Natural :=
              Character'Pos (Ch) - Character'Pos ('0');
         begin
            if Value > (Natural'Last - Digit) / 10 then
               return 0;
            end if;
            Value := Value * 10 + Digit;
         end;
      end loop;
      return Value;
   end Parse_Natural;

   function Clamp_Positive
     (Value    : Natural;
      Fallback : Positive;
      Max      : Positive) return Positive
   is
   begin
      if Value = 0 then
         return Fallback;
      elsif Value > Max then
         return Max;
      else
         return Positive (Value);
      end if;
   end Clamp_Positive;

   function Raw_Bytes_Per_Pixel (Raw_Format : Natural) return Natural is
   begin
      if Raw_Format = 24 then
         return 3;
      elsif Raw_Format = 32 then
         return 4;
      else
         return 0;
      end if;
   end Raw_Bytes_Per_Pixel;

   function Raw_Row_Stride
     (Raw_Format  : Natural;
      Pixel_Width : Natural) return Natural
   is
      Bytes_Per_Pixel : constant Natural := Raw_Bytes_Per_Pixel (Raw_Format);
   begin
      if Bytes_Per_Pixel = 0
        or else Pixel_Width = 0
        or else Pixel_Width > Natural'Last / Bytes_Per_Pixel
      then
         return 0;
      end if;

      return Pixel_Width * Bytes_Per_Pixel;
   end Raw_Row_Stride;

   function Raw_Decoded_Length
     (Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural) return Natural
   is
      Row_Stride : constant Natural := Raw_Row_Stride (Raw_Format, Pixel_Width);
   begin
      if Row_Stride = 0
        or else Pixel_Height = 0
        or else Pixel_Height > Max_Data_Preview_Length / Row_Stride
      then
         return 0;
      end if;

      return Pixel_Height * Row_Stride;
   end Raw_Decoded_Length;

   function RGBA_Decoded_Length
     (Pixel_Width  : Natural;
      Pixel_Height : Natural) return Natural is
   begin
      return Raw_Decoded_Length (32, Pixel_Width, Pixel_Height);
   end RGBA_Decoded_Length;

   type Sixel_Info is record
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   type PNG_Info is record
      Width  : Natural := 0;
      Height : Natural := 0;
      Color_Type : Natural := 0;
   end record;

   type Sixel_Color is record
      R : Terminal.Common.Bytes.Byte := 16#FF#;
      G : Terminal.Common.Bytes.Byte := 16#FF#;
      B : Terminal.Common.Bytes.Byte := 16#FF#;
      A : Terminal.Common.Bytes.Byte := 16#FF#;
   end record;

   type Sixel_Palette is array (Natural range 0 .. 255) of Sixel_Color;
   type PNG_Palette is array (Natural range 0 .. 255) of Sixel_Color;

   function Byte_From_Percent (Value : Natural) return Terminal.Common.Bytes.Byte
   is
      Clamped : constant Natural := Natural'Min (Value, 100);
   begin
      return Terminal.Common.Bytes.Byte ((Clamped * 255 + 50) / 100);
   end Byte_From_Percent;

   function U32_BE
     (Bytes : Terminal.Common.Bytes.Byte_Array;
      First : Positive) return Natural
   is
      use type Terminal.Common.Bytes.Byte;
   begin
      if First + 3 > Bytes'Last then
         return 0;
      end if;
      return Natural (Bytes (First)) * 16#1000000#
        + Natural (Bytes (First + 1)) * 16#10000#
        + Natural (Bytes (First + 2)) * 16#100#
        + Natural (Bytes (First + 3));
   end U32_BE;

   function Paeth (A, B, C : Natural) return Natural is
      P  : constant Integer := Integer (A) + Integer (B) - Integer (C);
      PA : constant Natural := Natural (abs (P - Integer (A)));
      PB : constant Natural := Natural (abs (P - Integer (B)));
      PC : constant Natural := Natural (abs (P - Integer (C)));
   begin
      if PA <= PB and then PA <= PC then
         return A;
      elsif PB <= PC then
         return B;
      else
         return C;
      end if;
   end Paeth;

   function PNG_Bit_Depth_Allowed
     (Color_Type : Natural;
      Bit_Depth  : Natural) return Boolean is
   begin
      case Color_Type is
         when 0 =>
            return Bit_Depth = 1
              or else Bit_Depth = 2
              or else Bit_Depth = 4
              or else Bit_Depth = 8
              or else Bit_Depth = 16;
         when 2 | 4 | 6 =>
            return Bit_Depth = 8 or else Bit_Depth = 16;
         when 3 =>
            return Bit_Depth = 1
              or else Bit_Depth = 2
              or else Bit_Depth = 4
              or else Bit_Depth = 8;
         when others =>
            return False;
      end case;
   end PNG_Bit_Depth_Allowed;

   function PNG_Bits_Per_Pixel
     (Color_Type : Natural;
      Bit_Depth  : Natural) return Natural is
   begin
      case Color_Type is
         when 0 | 3 =>
            return Bit_Depth;
         when 2 =>
            return Bit_Depth * 3;
         when 4 =>
            return Bit_Depth * 2;
         when others =>
            return Bit_Depth * 4;
      end case;
   end PNG_Bits_Per_Pixel;

   function PNG_Filter_BPP
     (Color_Type : Natural;
      Bit_Depth  : Natural) return Natural is
      Bits : constant Natural := PNG_Bits_Per_Pixel (Color_Type, Bit_Depth);
   begin
      return Natural'Max (1, (Bits + 7) / 8);
   end PNG_Filter_BPP;

   function PNG_Row_Bytes
     (Width      : Natural;
      Color_Type : Natural;
      Bit_Depth  : Natural) return Natural
   is
      Bits_Per_Pixel : constant Natural :=
        PNG_Bits_Per_Pixel (Color_Type, Bit_Depth);
   begin
      if Bits_Per_Pixel = 0
        or else Width > (Natural'Last - 7) / Bits_Per_Pixel
      then
         return 0;
      end if;

      return (Width * Bits_Per_Pixel + 7) / 8;
   end PNG_Row_Bytes;

   function PNG_Pass_Size
     (Full_Size : Natural;
      Start     : Natural;
      Step      : Natural) return Natural is
   begin
      if Full_Size <= Start then
         return 0;
      end if;
      return (Full_Size - Start + Step - 1) / Step;
   end PNG_Pass_Size;

   function PNG_Inflated_Length
     (Width      : Natural;
      Height     : Natural;
      Color_Type : Natural;
      Bit_Depth  : Natural;
      Interlace  : Natural) return Natural
   is
      function Pass_Bytes
        (X_Start : Natural;
         Y_Start : Natural;
         X_Step  : Natural;
         Y_Step  : Natural) return Natural
      is
         Pass_Width : constant Natural :=
           PNG_Pass_Size (Width, X_Start, X_Step);
         Pass_Height : constant Natural :=
           PNG_Pass_Size (Height, Y_Start, Y_Step);
      begin
         if Pass_Width = 0 or else Pass_Height = 0 then
            return 0;
         end if;

         declare
            Row_Length : constant Natural :=
              PNG_Row_Bytes (Pass_Width, Color_Type, Bit_Depth);
         begin
            if Row_Length = 0
              or else Row_Length = Natural'Last
              or else Pass_Height > Natural'Last / (Row_Length + 1)
            then
               return 0;
            end if;

            return (Row_Length + 1) * Pass_Height;
         end;
      end Pass_Bytes;
   begin
      if Interlace = 0 then
         declare
            Row_Length : constant Natural :=
              PNG_Row_Bytes (Width, Color_Type, Bit_Depth);
         begin
            if Row_Length = 0
              or else Row_Length = Natural'Last
              or else Height > Natural'Last / (Row_Length + 1)
            then
               return 0;
            end if;

            return (Row_Length + 1) * Height;
         end;
      end if;

      declare
         Total : Natural := 0;
         Overflow : Boolean := False;

         procedure Add_Pass (Value : Natural) is
         begin
            if Overflow or else Value = 0 then
               null;
            elsif Total > Natural'Last - Value then
               Overflow := True;
            else
               Total := Total + Value;
            end if;
         end Add_Pass;
      begin
         Add_Pass (Pass_Bytes (0, 0, 8, 8));
         Add_Pass (Pass_Bytes (4, 0, 8, 8));
         Add_Pass (Pass_Bytes (0, 4, 4, 8));
         Add_Pass (Pass_Bytes (2, 0, 4, 4));
         Add_Pass (Pass_Bytes (0, 2, 2, 4));
         Add_Pass (Pass_Bytes (1, 0, 2, 2));
         Add_Pass (Pass_Bytes (0, 1, 1, 2));
         return (if Overflow then 0 else Total);
      end;
   end PNG_Inflated_Length;

   function PNG_Packed_Sample
     (Row          : Terminal.Common.Bytes.Byte_Array;
      Bit_Depth    : Natural;
      Sample_Index : Natural) return Natural
   is
      Bit_Offset : constant Natural := Sample_Index * Bit_Depth;
      Byte_Index : constant Positive := Row'First + Bit_Offset / 8;
      Shift      : constant Natural := 8 - Bit_Depth - (Bit_Offset mod 8);
      Mask       : constant Natural := 2 ** Bit_Depth - 1;
   begin
      return (Natural (Row (Byte_Index)) / (2 ** Shift)) mod (Mask + 1);
   end PNG_Packed_Sample;

   function PNG_Sample_16
     (Row   : Terminal.Common.Bytes.Byte_Array;
      First : Positive) return Natural is
   begin
      return Natural (Row (First)) * 256 + Natural (Row (First + 1));
   end PNG_Sample_16;

   function PNG_Scale_Sample
     (Value     : Natural;
      Bit_Depth : Natural) return Natural
   is
      Max_Value : constant Natural := 2 ** Bit_Depth - 1;
   begin
      if Bit_Depth = 8 then
         return Value;
      elsif Bit_Depth = 16 then
         return (Value * 255 + 32767) / 65535;
      else
         return (Value * 255 + Max_Value / 2) / Max_Value;
      end if;
   end PNG_Scale_Sample;

   function Default_Sixel_Palette return Sixel_Palette is
      Palette : Sixel_Palette :=
        (others => (R => 16#FF#, G => 16#FF#, B => 16#FF#, A => 16#FF#));
   begin
      Palette (0) := (R => 16#00#, G => 16#00#, B => 16#00#, A => 16#FF#);
      Palette (1) := (R => 16#FF#, G => 16#FF#, B => 16#FF#, A => 16#FF#);
      Palette (2) := (R => 16#FF#, G => 16#00#, B => 16#00#, A => 16#FF#);
      Palette (3) := (R => 16#00#, G => 16#FF#, B => 16#00#, A => 16#FF#);
      Palette (4) := (R => 16#00#, G => 16#00#, B => 16#FF#, A => 16#FF#);
      return Palette;
   end Default_Sixel_Palette;

   procedure Skip_Sixel_Number
     (Text  : String;
      Index : in out Natural)
   is
   begin
      while Index <= Text'Last and then Text (Index) in '0' .. '9' loop
         Index := Index + 1;
      end loop;
   end Skip_Sixel_Number;

   function Read_Sixel_Number
     (Text  : String;
      Index : in out Natural) return Natural
   is
      Value : Natural := 0;
      Seen  : Boolean := False;
   begin
      while Index <= Text'Last and then Text (Index) in '0' .. '9' loop
         Seen := True;
         declare
            Digit : constant Natural :=
              Character'Pos (Text (Index)) - Character'Pos ('0');
         begin
            if Value > (Natural'Last - Digit) / 10 then
               Value := Natural'Last;
            elsif Value < Natural'Last then
               Value := Value * 10 + Digit;
            end if;
         end;
         Index := Index + 1;
      end loop;

      return (if Seen then Value else 0);
   end Read_Sixel_Number;

   function Analyze_Sixel (Text : String) return Sixel_Info is
      I : Natural := Text'First;
      X : Natural := 0;
      Y : Natural := 0;
      Max_X : Natural := 0;
      Max_Y : Natural := 0;
      Repeat_Count : Natural := 1;
   begin
      while I <= Text'Last and then Text (I) /= 'q' loop
         I := I + 1;
      end loop;
      if I > Text'Last then
         return (others => 0);
      end if;

      I := I + 1;
      while I <= Text'Last loop
         case Text (I) is
            when '!' =>
               I := I + 1;
               Repeat_Count := Natural'Max (Read_Sixel_Number (Text, I), 1);
            when '#' =>
               I := I + 1;
               Skip_Sixel_Number (Text, I);
               while I <= Text'Last and then Text (I) = ';' loop
                  I := I + 1;
                  Skip_Sixel_Number (Text, I);
               end loop;
            when '$' =>
               X := 0;
               I := I + 1;
            when '-' =>
               X := 0;
               Y := Y + 6;
               Max_Y := Natural'Max (Max_Y, Y);
               I := I + 1;
            when '?' .. '~' =>
               declare
                  Bits : constant Natural := Character'Pos (Text (I)) - 63;
               begin
                  for Bit in 0 .. 5 loop
                     if (Bits / (2 ** Bit)) mod 2 = 1 then
                        Max_Y := Natural'Max (Max_Y, Y + Bit + 1);
                     end if;
                  end loop;
                  X := X + Repeat_Count;
                  Max_X := Natural'Max (Max_X, X);
                  Repeat_Count := 1;
                  I := I + 1;
               end;
            when others =>
               Repeat_Count := 1;
               I := I + 1;
         end case;
      end loop;

      if Max_X = 0 or else Max_Y = 0 then
         return (others => 0);
      end if;
      return (Width => Max_X, Height => Max_Y);
   end Analyze_Sixel;

   procedure Decode_Sixel_Rows
     (Text   : String;
      Row_Sink : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is
      Info : constant Sixel_Info := Analyze_Sixel (Text);
      I : Natural := Text'First;
      X : Natural := 0;
      Y : Natural := 0;
      Repeat_Count : Natural := 1;
      Palette : Sixel_Palette := Default_Sixel_Palette;
      Color_Index : Natural range 0 .. 255 := 1;
      Byte_Count : constant Natural :=
        RGBA_Decoded_Length (Info.Width, Info.Height);
      Row_Bytes : constant Natural := Raw_Row_Stride (32, Info.Width);
      Band : Terminal.Common.Bytes.Byte_Array (1 .. Natural'Max (Row_Bytes * 6, 1)) :=
        (others => 0);

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

         Offset := Bit_Row * Row_Bytes + PX * 4 + 1;
         Band (Offset) := Color.R;
         Band (Offset + 1) := Color.G;
         Band (Offset + 2) := Color.B;
         Band (Offset + 3) := Color.A;
      end Write_Pixel;

      procedure Flush_Band is
      begin
         for Band_Row in 0 .. 5 loop
            exit when Y + Band_Row >= Info.Height;
            declare
               Row : Terminal.Common.Bytes.Byte_Array (1 .. Row_Bytes);
               Source_First : constant Natural := Band_Row * Row_Bytes + 1;
               Continue : Boolean := True;
            begin
               for I in Row'Range loop
                  Row (I) := Band (Source_First + I - Row'First);
               end loop;
               Row_Sink (Y + Band_Row, Row, Continue);
               if not Continue then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  return;
               end if;
            end;
         end loop;
         Band := (others => 0);
      end Flush_Band;
   begin
      if Info.Width = 0 or else Info.Height = 0 then
         Result.Decode_Status := Decode_Invalid_Byte;
         Result.Decode_Complete := False;
         return;
      elsif Byte_Count = 0 or else Row_Bytes = 0 then
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
                        if Mode = 2 and then Index <= 255 then
                           Palette (Index) :=
                             (R => Byte_From_Percent (R),
                              G => Byte_From_Percent (G),
                              B => Byte_From_Percent (B),
                              A => 16#FF#);
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

      Flush_Band;
      if not Result.Decode_Complete then
         return;
      end if;

      Result.Decoded_Length := Byte_Count;
      Result.Decoded_Row_Stride_Bytes := Info.Width * 4;
      Result.Decode_Complete := True;
      Result.Decode_Status := Decode_Ok;
   end Decode_Sixel_Rows;

   procedure Decode_Sixel_Raster
     (Text   : String;
      Info   : Sixel_Info;
      Result : in out Graphics_Data_Preview)
   is
      pragma Unreferenced (Info);

      procedure Capture_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         Needed : constant Natural :=
           RGBA_Decoded_Length (Result.Pixel_Width, Result.Pixel_Height);
         Offset : Natural := 0;
      begin
         if Needed = 0
           or else Row'Length = 0
           or else Y > (Natural'Last - 1) / Row'Length
         then
            Continue := False;
            return;
         end if;

         Offset := Y * Row'Length + 1;
         Ensure_Bytes (Result, Needed);
         if Offset > Result.Bytes'Last
           or else Row'Length > Result.Bytes'Last - Offset + 1
         then
            Continue := False;
            return;
         end if;
         for I in Row'Range loop
            Result.Bytes (Offset + I - Row'First) := Row (I);
         end loop;
      end Capture_Row;
   begin
      Decode_Sixel_Rows (Text, Capture_Row'Access, Result);
   end Decode_Sixel_Raster;

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
      Seen_IEND : Boolean := False;

      function U32_BE_Source (First : Positive) return Natural is
      begin
         if First + 3 > Length then
            return 0;
         end if;
         return Natural (PNG_Byte (First)) * 16#1000000#
           + Natural (PNG_Byte (First + 1)) * 16#10000#
           + Natural (PNG_Byte (First + 2)) * 16#100#
           + Natural (PNG_Byte (First + 3));
      end U32_BE_Source;
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
            Type_First : constant Natural := Pos + 4;
            Data_First : constant Natural := Pos + 8;
            Data_Last  : constant Natural := Data_First + Chunk_Length - 1;
            Next_Pos   : constant Natural := Data_Last + 5;
         begin
            if Chunk_Length > Length
              or else Data_First > Length + 1
              or else Data_Last + 4 > Length
            then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               return;
            end if;

            if PNG_Byte (Type_First) = 16#49#
              and then PNG_Byte (Type_First + 1) = 16#48#
              and then PNG_Byte (Type_First + 2) = 16#44#
              and then PNG_Byte (Type_First + 3) = 16#52#
            then
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
            elsif PNG_Byte (Type_First) = 16#49#
              and then PNG_Byte (Type_First + 1) = 16#44#
              and then PNG_Byte (Type_First + 2) = 16#41#
              and then PNG_Byte (Type_First + 3) = 16#54#
            then
               if IDAT_Length + Chunk_Length > Max_Data_Preview_Length then
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
            elsif PNG_Byte (Type_First) = 16#50#
              and then PNG_Byte (Type_First + 1) = 16#4C#
              and then PNG_Byte (Type_First + 2) = 16#54#
              and then PNG_Byte (Type_First + 3) = 16#45#
            then
               if Chunk_Length mod 3 /= 0 or else Chunk_Length / 3 > 256 then
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
            elsif PNG_Byte (Type_First) = 16#74#
              and then PNG_Byte (Type_First + 1) = 16#52#
              and then PNG_Byte (Type_First + 2) = 16#4E#
              and then PNG_Byte (Type_First + 3) = 16#53#
            then
               if Info.Color_Type = 0 and then Chunk_Length >= 2 then
                  Gray_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First), 4 => PNG_Byte (Data_First + 1)), 1);
               elsif Info.Color_Type = 2 and then Chunk_Length >= 6 then
                  Red_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First), 4 => PNG_Byte (Data_First + 1)), 1);
                  Green_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First + 2), 4 => PNG_Byte (Data_First + 3)), 1);
                  Blue_Transparent := U32_BE ((1 => 0, 2 => 0, 3 => PNG_Byte (Data_First + 4), 4 => PNG_Byte (Data_First + 5)), 1);
               elsif Info.Color_Type = 3 then
                  for Index in 0 .. Natural'Min (Chunk_Length, 256) - 1 loop
                     Palette (Index).A := PNG_Byte (Data_First + Index);
                  end loop;
               end if;
            elsif PNG_Byte (Type_First) = 16#49#
              and then PNG_Byte (Type_First + 1) = 16#45#
              and then PNG_Byte (Type_First + 2) = 16#4E#
              and then PNG_Byte (Type_First + 3) = 16#44#
            then
               Seen_IEND := True;
            end if;

            Pos := Next_Pos;
         end;
      end loop;

      if not Seen_IHDR
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
        or else (Info.Color_Type = 3 and then Palette_Count = 0)
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
            Row_Stride : constant Natural := Raw_Row_Stride (32, Info.Width);
            Out_Row : Terminal.Common.Bytes.Byte_Array (1 .. Row_Stride) :=
              (others => 0);
            Continue : Boolean := True;
         begin
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
                     Out_Row (Out_Pos) := Terminal.Common.Bytes.Byte (Red);
                     Out_Row (Out_Pos + 1) :=
                       Terminal.Common.Bytes.Byte (Green);
                     Out_Row (Out_Pos + 2) :=
                       Terminal.Common.Bytes.Byte (Blue);
                     Out_Row (Out_Pos + 3) :=
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
               Row_Sink (Y, Out_Row, Continue);
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
               Prev_Row : Terminal.Common.Bytes.Byte_Array
                 (1 .. Pass_Row_Bytes) := (others => 0);
               This_Row : Terminal.Common.Bytes.Byte_Array
                 (1 .. Pass_Row_Bytes) := (others => 0);
            begin
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
                              then Natural (This_Row (I - Filter_BPP))
                              else 0);
                           Up : constant Natural := Natural (Prev_Row (I));
                           Upper_Left : constant Natural :=
                             (if I > Filter_BPP
                              then Natural (Prev_Row (I - Filter_BPP))
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
                           This_Row (I) :=
                             Terminal.Common.Bytes.Byte
                               ((Raw + Predictor) mod 256);
                        end;
                     end loop;

                     Write_Row_Pixels
                       (This_Row,
                        Pass_Width,
                        X_Start,
                        Y_Start + Row * Y_Step,
                        X_Step);
                     if not Result.Decode_Complete
                       and then Result.Decode_Status = Decode_Invalid_Byte
                     then
                        return;
                     end if;

                     Prev_Row := This_Row;
                  end;
               end loop;
            end;
         end Decode_Pass;

         procedure Emit_Interlaced_Rows is
         begin
            for Y in 0 .. Info.Height - 1 loop
               declare
                  Row_Stride : constant Natural := Raw_Row_Stride (32, Info.Width);
                  Row : Terminal.Common.Bytes.Byte_Array (1 .. Row_Stride);
                  Source_First : constant Natural := Y * Row_Stride + 1;
                  Continue : Boolean := True;
               begin
                  for I in Row'Range loop
                     Row (I) :=
                       Interlaced_Image.Data (Source_First + I - Row'First);
                  end loop;
                  Row_Sink (Y, Row, Continue);
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
      end;
   end Decode_PNG_RGBA_Source_Rows;

   procedure Decode_PNG_RGBA_Rows
     (PNG    : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Row_Sink : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is
      function Source_Byte
        (Index : Positive) return Terminal.Common.Bytes.Byte
      is
      begin
         if Index > PNG'Last then
            return 0;
         end if;
         return PNG (Index);
      end Source_Byte;
   begin
      Decode_PNG_RGBA_Source_Rows
        (Length, Source_Byte'Access, Row_Sink, Result);
   end Decode_PNG_RGBA_Rows;

   procedure Decode_PNG_RGBA
     (PNG    : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Result : in out Graphics_Data_Preview)
   is
      procedure Capture_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         Needed : constant Natural :=
           RGBA_Decoded_Length (Result.Pixel_Width, Result.Pixel_Height);
         Offset : Natural := 0;
      begin
         if Needed = 0
           or else Row'Length = 0
           or else Y > (Natural'Last - 1) / Row'Length
         then
            Continue := False;
            return;
         end if;

         Offset := Y * Row'Length + 1;
         Ensure_Bytes (Result, Needed);
         if Offset > Result.Bytes'Last
           or else Row'Length > Result.Bytes'Last - Offset + 1
         then
            Continue := False;
            return;
         end if;
         for I in Row'Range loop
            Result.Bytes (Offset + I - Row'First) := Row (I);
         end loop;
      end Capture_Row;
   begin
      Decode_PNG_RGBA_Rows (PNG, Length, Capture_Row'Access, Result);
   end Decode_PNG_RGBA;

   procedure Decode_PNG_RGBA_Data
     (PNG    : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Result : in out Graphics_Data_Preview) is
   begin
      Decode_PNG_RGBA (PNG, Length, Result);
   end Decode_PNG_RGBA_Data;

   function Field_Value
     (Header : String;
      Name   : String) return String
   is
      I : Natural := Header'First;
   begin
      while I <= Header'Last loop
         declare
            Start : constant Natural := I;
            Stop  : Natural := I;
            Eq    : Natural := 0;
         begin
            while Stop <= Header'Last
              and then Header (Stop) /= ','
              and then Header (Stop) /= ';'
            loop
               if Header (Stop) = '=' and then Eq = 0 then
                  Eq := Stop;
               end if;
               Stop := Stop + 1;
            end loop;

            if Eq /= 0
              and then Eq - Start = Name'Length
              and then Header (Start .. Eq - 1) = Name
            then
               return Header (Eq + 1 .. Stop - 1);
            end if;

            I := Stop + 1;
         end;
      end loop;
      return "";
   end Field_Value;

   function Data_First
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Text  : String) return Natural
   is
      Delimiter : Character := ASCII.NUL;
   begin
      case Protocol is
         when Terminal.Core.Sixel_Graphics =>
            Delimiter := 'q';
         when Terminal.Core.Kitty_Graphics =>
            Delimiter := ';';
         when Terminal.Core.ITerm2_Graphics =>
            Delimiter := ':';
         when Terminal.Core.No_Graphics =>
            return 0;
      end case;

      for I in Text'Range loop
         if Text (I) = Delimiter then
            if I < Text'Last then
               return I + 1;
            else
               return 0;
            end if;
         end if;
      end loop;

      return 0;
   end Data_First;

   function Base64_Value (Ch : Character) return Integer is
   begin
      case Ch is
         when 'A' .. 'Z' =>
            return Character'Pos (Ch) - Character'Pos ('A');
         when 'a' .. 'z' =>
            return 26 + Character'Pos (Ch) - Character'Pos ('a');
         when '0' .. '9' =>
            return 52 + Character'Pos (Ch) - Character'Pos ('0');
         when '+' =>
            return 62;
         when '/' =>
            return 63;
         when others =>
            return -1;
      end case;
   end Base64_Value;

   procedure Decode_Base64_Preview
     (Text   : String;
      Result : in out Graphics_Data_Preview;
      Expected_Decoded_Length : Natural := 0)
   is
      Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Count  : Natural := 0;
      Padding : Natural := 0;
      Done   : Boolean := False;

      procedure Append_Byte (Value : Natural) is
      begin
         if Result.Decoded_Length = Max_Data_Preview_Length then
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         if Expected_Decoded_Length > 0 then
            Ensure_Bytes (Result, Expected_Decoded_Length);
         else
            Ensure_Bytes (Result);
         end if;
         Result.Decoded_Length := Result.Decoded_Length + 1;
         Result.Bytes (Result.Decoded_Length) :=
           Terminal.Common.Bytes.Byte (Value mod 256);
      end Append_Byte;

      procedure Flush_Group is
      begin
         if Count = 0 then
            return;
         elsif Count = 1 or else Padding > 2 then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         Append_Byte ((Values (1) * 4) + (Values (2) / 16));
         if Done then
            return;
         end if;

         if Count >= 3 and then Padding < 2 then
            Append_Byte (((Values (2) mod 16) * 16) + (Values (3) / 4));
            if Done then
               return;
            end if;
         end if;

         if Count = 4 and then Padding = 0 then
            Append_Byte (((Values (3) mod 4) * 64) + Values (4));
         end if;
      end Flush_Group;
   begin
      for Ch of Text loop
         declare
            V : constant Integer := Base64_Value (Ch);
         begin
            if Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
               null;
            elsif Done then
               Result.Decode_Status := Decode_Trailing_Data;
               Result.Decode_Complete := False;
               return;
            elsif Ch = '=' then
               Count := Count + 1;
               if Count > 4 then
                  Result.Decode_Status := Decode_Trailing_Data;
                  Result.Decode_Complete := False;
                  return;
               end if;
               Padding := Padding + 1;
               Values (Count) := 0;
               if Count = 4 then
                  Flush_Group;
                  if Done then
                     return;
                  end if;
                  Done := True;
               end if;
            elsif V < 0 or else Padding > 0 then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               return;
            else
               Count := Count + 1;
               if Count > 4 then
                  Result.Decode_Status := Decode_Trailing_Data;
                  Result.Decode_Complete := False;
                  return;
               end if;
               Values (Count) := Natural (V);
               if Count = 4 then
                  Flush_Group;
                  if Done then
                     return;
                  end if;
                  Values := (others => 0);
                  Count := 0;
               end if;
            end if;
         end;
      end loop;

      if Count > 0 and then not Done then
         Flush_Group;
         if Done and then Result.Decode_Status /= Decode_Preview_Truncated then
            return;
         end if;
      end if;

      Result.Decode_Complete := Result.Has_Data;
      Result.Decode_Status :=
        (if Result.Decode_Complete then Decode_Ok else Decode_Not_Attempted);
   end Decode_Base64_Preview;

   procedure Decode_Base64_Chunk_Bytes
     (Chunk_Count : Natural;
      Chunk_Text  : not null access function (Index : Positive) return String;
      Byte_Sink   : not null access procedure
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      Result      : in out Graphics_Data_Preview)
   is
      Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Count  : Natural := 0;
      Padding : Natural := 0;
      Done   : Boolean := False;

      procedure Append_Byte (Value : Natural) is
         Continue : Boolean := True;
      begin
         if Result.Decoded_Length = Max_Data_Preview_Length then
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         Byte_Sink (Terminal.Common.Bytes.Byte (Value mod 256), Continue);
         if not Continue then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         Result.Decoded_Length := Result.Decoded_Length + 1;
      end Append_Byte;

      procedure Flush_Group is
      begin
         if Count = 0 then
            return;
         elsif Count = 1 or else Padding > 2 then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         Append_Byte ((Values (1) * 4) + (Values (2) / 16));
         if Done then
            return;
         end if;

         if Count >= 3 and then Padding < 2 then
            Append_Byte (((Values (2) mod 16) * 16) + (Values (3) / 4));
            if Done then
               return;
            end if;
         end if;

         if Count = 4 and then Padding = 0 then
            Append_Byte (((Values (3) mod 4) * 64) + Values (4));
         end if;
      end Flush_Group;
   begin
      Release (Result);
      Result.Header_Recognized := True;

      for Index in 1 .. Chunk_Count loop
         declare
            Text : constant String := Chunk_Text (Index);
         begin
            Result.Encoded_Length := Result.Encoded_Length + Text'Length;
            if Text'Length > 0 then
               Result.Has_Data := True;
            end if;
         end;
      end loop;

      for Index in 1 .. Chunk_Count loop
         declare
            Text : constant String := Chunk_Text (Index);
         begin
            for Ch of Text loop
               declare
                  V : constant Integer := Base64_Value (Ch);
               begin
                  if Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                     null;
                  elsif Done then
                     Result.Decode_Status := Decode_Trailing_Data;
                     Result.Decode_Complete := False;
                     return;
                  elsif Ch = '=' then
                     Count := Count + 1;
                     if Count > 4 then
                        Result.Decode_Status := Decode_Trailing_Data;
                        Result.Decode_Complete := False;
                        return;
                     end if;
                     Padding := Padding + 1;
                     Values (Count) := 0;
                     if Count = 4 then
                        Flush_Group;
                        if Done then
                           return;
                        end if;
                        Done := True;
                     end if;
                  elsif V < 0 or else Padding > 0 then
                     Result.Decode_Status := Decode_Invalid_Byte;
                     Result.Decode_Complete := False;
                     return;
                  else
                     Count := Count + 1;
                     if Count > 4 then
                        Result.Decode_Status := Decode_Trailing_Data;
                        Result.Decode_Complete := False;
                        return;
                     end if;
                     Values (Count) := Natural (V);
                     if Count = 4 then
                        Flush_Group;
                        if Done then
                           return;
                        end if;
                        Values := (others => 0);
                        Count := 0;
                     end if;
                  end if;
               end;
            end loop;
         end;
      end loop;

      if Count > 0 and then not Done then
         Flush_Group;
         if Done
           and then Result.Decode_Status /= Decode_Preview_Truncated
         then
            return;
         end if;
      end if;

      Result.Decode_Complete := Result.Has_Data;
      Result.Decode_Status :=
        (if Result.Decode_Complete then Decode_Ok else Decode_Not_Attempted);
   end Decode_Base64_Chunk_Bytes;

   procedure Decode_Base64_PNG_Chunk_Rows
     (Chunk_Count    : Natural;
      Chunk_Text     : not null access function (Index : Positive) return String;
      Encoded_Length : out Natural;
      PNG_Length     : out Natural;
      Row_Sink       : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result         : in out Graphics_Data_Preview)
   is
      Cursor_Chunk : Positive := 1;
      Cursor_Offset : Natural := 0;
      Cursor_Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Cursor_Count : Natural := 0;
      Cursor_Padding : Natural := 0;
      Cursor_Done : Boolean := False;
      Cursor_Invalid : Boolean := False;
      Decoded_Position : Natural := 0;
      Window_First : Natural := 0;
      Window_Last : Natural := 0;
      Window_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 3) := (others => 0);

      function Base64_Group_Decoded_Length
        (Count   : Natural;
         Padding : Natural) return Natural
      is
      begin
         if Count = 0 then
            return 0;
         elsif Count = 1 or else Padding > 2 then
            return 0;
         elsif Count = 2 then
            return 1;
         elsif Count = 3 then
            return (if Padding = 0 then 2 else 1);
         else
            return 3 - Padding;
         end if;
      end Base64_Group_Decoded_Length;

      function Base64_Group_Byte
        (Values : Terminal.Common.Bytes.Byte_Array;
         Index  : Positive) return Terminal.Common.Bytes.Byte
      is
         V1 : constant Natural := Natural (Values (1));
         V2 : constant Natural := Natural (Values (2));
         V3 : constant Natural := Natural (Values (3));
         V4 : constant Natural := Natural (Values (4));
      begin
         case Index is
            when 1 =>
               return Terminal.Common.Bytes.Byte ((V1 * 4) + (V2 / 16));
            when 2 =>
               return Terminal.Common.Bytes.Byte
                 (((V2 mod 16) * 16) + (V3 / 4));
            when others =>
               return Terminal.Common.Bytes.Byte (((V3 mod 4) * 64) + V4);
         end case;
      end Base64_Group_Byte;

      procedure Measure_Base64_PNG is
         Count : Natural := 0;
         Padding : Natural := 0;
         Done : Boolean := False;

         procedure Append_Byte is
         begin
            if PNG_Length = Max_Data_Preview_Length then
               Result.Decode_Status := Decode_Preview_Truncated;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;
            PNG_Length := PNG_Length + 1;
         end Append_Byte;

         procedure Flush_Group is
            Group_Length : constant Natural :=
              Base64_Group_Decoded_Length (Count, Padding);
         begin
            if Count = 0 then
               return;
            elsif Group_Length = 0 then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;

            for I in 1 .. Group_Length loop
               Append_Byte;
               if Done then
                  return;
               end if;
            end loop;
         end Flush_Group;
      begin
         Result.Header_Recognized := True;

         for Index in 1 .. Chunk_Count loop
            declare
               Text : constant String := Chunk_Text (Index);
            begin
               Encoded_Length := Encoded_Length + Text'Length;
               if Text'Length > 0 then
                  Result.Has_Data := True;
               end if;
            end;
         end loop;

         for Index in 1 .. Chunk_Count loop
            declare
               Text : constant String := Chunk_Text (Index);
            begin
               for Ch of Text loop
                  declare
                     V : constant Integer := Base64_Value (Ch);
                  begin
                     if Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                        null;
                     elsif Done then
                        Result.Decode_Status := Decode_Trailing_Data;
                        Result.Decode_Complete := False;
                        return;
                     elsif Ch = '=' then
                        Count := Count + 1;
                        if Count > 4 then
                           Result.Decode_Status := Decode_Trailing_Data;
                           Result.Decode_Complete := False;
                           return;
                        end if;
                        Padding := Padding + 1;
                        if Count = 4 then
                           Flush_Group;
                           if Done then
                              return;
                           end if;
                           Done := True;
                        end if;
                     elsif V < 0 or else Padding > 0 then
                        Result.Decode_Status := Decode_Invalid_Byte;
                        Result.Decode_Complete := False;
                        return;
                     else
                        Count := Count + 1;
                        if Count > 4 then
                           Result.Decode_Status := Decode_Trailing_Data;
                           Result.Decode_Complete := False;
                           return;
                        end if;
                        if Count = 4 then
                           Flush_Group;
                           if Done then
                              return;
                           end if;
                           Count := 0;
                        end if;
                     end if;
                  end;
               end loop;
            end;
         end loop;

         if Count > 0 and then not Done then
            Flush_Group;
            if Done
              and then Result.Decode_Status /= Decode_Preview_Truncated
            then
               return;
            end if;
         end if;

         Result.Decode_Complete := Result.Has_Data;
         Result.Decode_Status :=
           (if Result.Decode_Complete then Decode_Ok else Decode_Not_Attempted);
      end Measure_Base64_PNG;

      procedure Reset_Base64_Cursor is
      begin
         Cursor_Chunk := 1;
         Cursor_Offset := 0;
         Cursor_Values := (others => 0);
         Cursor_Count := 0;
         Cursor_Padding := 0;
         Cursor_Done := False;
         Cursor_Invalid := False;
         Decoded_Position := 0;
         Window_First := 0;
         Window_Last := 0;
         Window_Bytes := (others => 0);
      end Reset_Base64_Cursor;

      procedure Append_Window_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Count : in out Natural)
      is
      begin
         Count := Count + 1;
         if Count <= Window_Bytes'Length then
            Window_Bytes (Count) := Value;
         else
            Cursor_Invalid := True;
         end if;
      end Append_Window_Byte;

      procedure Flush_Cursor_Group is
         Group_Count : constant Natural :=
           Base64_Group_Decoded_Length (Cursor_Count, Cursor_Padding);
         Emitted_Count : Natural := 0;
      begin
         if Cursor_Count = 0 then
            return;
         elsif Group_Count = 0 then
            Cursor_Invalid := True;
            return;
         end if;

         Window_First := Decoded_Position + 1;
         Window_Last := 0;
         Window_Bytes := (others => 0);

         for I in 1 .. Group_Count loop
            Append_Window_Byte
              (Base64_Group_Byte
                 ((1 => Terminal.Common.Bytes.Byte (Cursor_Values (1)),
                   2 => Terminal.Common.Bytes.Byte (Cursor_Values (2)),
                   3 => Terminal.Common.Bytes.Byte (Cursor_Values (3)),
                   4 => Terminal.Common.Bytes.Byte (Cursor_Values (4))),
                  I),
               Emitted_Count);
         end loop;

         if Cursor_Invalid then
            return;
         end if;

         Decoded_Position := Decoded_Position + Emitted_Count;
         Window_Last := Decoded_Position;
      end Flush_Cursor_Group;

      function Base64_PNG_Byte
        (Target : Positive) return Terminal.Common.Bytes.Byte
      is
      begin
         if Target > PNG_Length then
            return 0;
         end if;

         if Target >= Window_First and then Target <= Window_Last then
            return Window_Bytes (Target - Window_First + 1);
         elsif Target <= Decoded_Position then
            Reset_Base64_Cursor;
         end if;

         while Decoded_Position < Target
           and then not Cursor_Done
           and then not Cursor_Invalid
           and then Cursor_Chunk <= Chunk_Count
         loop
            declare
               Text : constant String := Chunk_Text (Cursor_Chunk);
            begin
               if Cursor_Offset = 0 then
                  Cursor_Offset := Text'First;
               end if;

               while Cursor_Offset <= Text'Last
                 and then Decoded_Position < Target
                 and then not Cursor_Done
                 and then not Cursor_Invalid
               loop
                  declare
                     Ch : constant Character := Text (Cursor_Offset);
                     V : constant Integer := Base64_Value (Ch);
                  begin
                     Cursor_Offset := Cursor_Offset + 1;
                     if Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                        null;
                     elsif Ch = '=' then
                        Cursor_Count := Cursor_Count + 1;
                        if Cursor_Count > 4 then
                           return 0;
                        end if;
                        Cursor_Padding := Cursor_Padding + 1;
                        Cursor_Values (Cursor_Count) := 0;
                        if Cursor_Count = 4 then
                           Flush_Cursor_Group;
                           Cursor_Done := True;
                        end if;
                     elsif V < 0 or else Cursor_Padding > 0 then
                        return 0;
                     else
                        Cursor_Count := Cursor_Count + 1;
                        if Cursor_Count > 4 then
                           return 0;
                        end if;
                        Cursor_Values (Cursor_Count) := Natural (V);
                        if Cursor_Count = 4 then
                           Flush_Cursor_Group;
                           Cursor_Values := (others => 0);
                           Cursor_Count := 0;
                        end if;
                     end if;
                  end;
               end loop;

               if Cursor_Offset > Text'Last then
                  Cursor_Chunk := Cursor_Chunk + 1;
                  Cursor_Offset := 0;
               end if;
            end;
         end loop;

         if Decoded_Position < Target
           and then not Cursor_Done
           and then not Cursor_Invalid
           and then Cursor_Count > 0
         then
            Flush_Cursor_Group;
            Cursor_Done := True;
         end if;

         if Target >= Window_First and then Target <= Window_Last then
            return Window_Bytes (Target - Window_First + 1);
         else
            return 0;
         end if;
      end Base64_PNG_Byte;
   begin
      Encoded_Length := 0;
      PNG_Length := 0;
      Release (Result);

      Measure_Base64_PNG;
      if not Result.Decode_Complete or else PNG_Length = 0 then
         Result.Encoded_Length := Encoded_Length;
         Result.Decode_Complete := False;
         return;
      end if;

      Decode_PNG_RGBA_Source_Rows
        (PNG_Length, Base64_PNG_Byte'Access, Row_Sink, Result);
   end Decode_Base64_PNG_Chunk_Rows;

   procedure Decode_Base64_Raw_Chunk_Rows
     (Chunk_Count  : Natural;
      Chunk_Text   : not null access function (Index : Positive) return String;
      Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Sink     : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result       : in out Graphics_Data_Preview)
   is
      Bytes_Per_Pixel : constant Natural :=
        Raw_Bytes_Per_Pixel (Raw_Format);
      Row_Stride : constant Natural := Raw_Row_Stride (Raw_Format, Pixel_Width);
      Expected_Decoded_Length : constant Natural :=
        Raw_Decoded_Length (Raw_Format, Pixel_Width, Pixel_Height);
      Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Count  : Natural := 0;
      Padding : Natural := 0;
      Done   : Boolean := False;
   begin
      Release (Result);
      Result.Header_Recognized := True;
      Result.Raw_Format := Raw_Format;
      Result.Pixel_Width := Pixel_Width;
      Result.Pixel_Height := Pixel_Height;
      Result.Decoded_Row_Stride_Bytes := Row_Stride;

      for Index in 1 .. Chunk_Count loop
         declare
            Text : constant String := Chunk_Text (Index);
         begin
            Result.Encoded_Length := Result.Encoded_Length + Text'Length;
            if Text'Length > 0 then
               Result.Has_Data := True;
            end if;
         end;
      end loop;

      if Bytes_Per_Pixel = 0
        or else Pixel_Width = 0
        or else Pixel_Height = 0
        or else Row_Stride = 0
      then
         Result.Decode_Status := Decode_Unsupported_Format;
         Result.Decode_Complete := False;
         return;
      elsif Expected_Decoded_Length > Max_Data_Preview_Length then
         Result.Decode_Status := Decode_Preview_Truncated;
         Result.Decode_Complete := False;
         return;
      elsif Expected_Decoded_Length = 0 then
         Result.Decode_Status := Decode_Preview_Truncated;
         Result.Decode_Complete := False;
         return;
      end if;

      declare
         Row : Terminal.Common.Bytes.Byte_Array (1 .. Row_Stride) :=
           (others => 0);
         Row_Length : Natural := 0;
         Y : Natural := 0;

         procedure Append_Byte (Value : Natural) is
            Continue : Boolean := True;
         begin
            if Result.Decoded_Length >= Expected_Decoded_Length
              or else Y >= Pixel_Height
            then
               Result.Decode_Status := Decode_Trailing_Data;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;

            Row_Length := Row_Length + 1;
            Row (Row_Length) := Terminal.Common.Bytes.Byte (Value mod 256);
            Result.Decoded_Length := Result.Decoded_Length + 1;

            if Row_Length = Row_Stride then
               Row_Sink (Y, Row, Continue);
               if not Continue then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  Done := True;
                  return;
               end if;
               Row_Length := 0;
               Y := Y + 1;
            end if;
         end Append_Byte;

         procedure Flush_Group is
         begin
            if Count = 0 then
               return;
            elsif Count = 1 or else Padding > 2 then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;

            Append_Byte ((Values (1) * 4) + (Values (2) / 16));
            if Done then
               return;
            end if;

            if Count >= 3 and then Padding < 2 then
               Append_Byte (((Values (2) mod 16) * 16) + (Values (3) / 4));
               if Done then
                  return;
               end if;
            end if;

            if Count = 4 and then Padding = 0 then
               Append_Byte (((Values (3) mod 4) * 64) + Values (4));
            end if;
         end Flush_Group;
      begin
         for Index in 1 .. Chunk_Count loop
            declare
               Text : constant String := Chunk_Text (Index);
            begin
               for Ch of Text loop
                  declare
                     V : constant Integer := Base64_Value (Ch);
                  begin
                     if Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                        null;
                     elsif Done then
                        Result.Decode_Status := Decode_Trailing_Data;
                        Result.Decode_Complete := False;
                        return;
                     elsif Ch = '=' then
                        Count := Count + 1;
                        if Count > 4 then
                           Result.Decode_Status := Decode_Trailing_Data;
                           Result.Decode_Complete := False;
                           return;
                        end if;
                        Padding := Padding + 1;
                        Values (Count) := 0;
                        if Count = 4 then
                           Flush_Group;
                           if Done
                             and then Result.Decode_Status /= Decode_Trailing_Data
                           then
                              return;
                           end if;
                           Done := True;
                        end if;
                     elsif V < 0 or else Padding > 0 then
                        Result.Decode_Status := Decode_Invalid_Byte;
                        Result.Decode_Complete := False;
                        return;
                     else
                        Count := Count + 1;
                        if Count > 4 then
                           Result.Decode_Status := Decode_Trailing_Data;
                           Result.Decode_Complete := False;
                           return;
                        end if;
                        Values (Count) := Natural (V);
                        if Count = 4 then
                           Flush_Group;
                           if Done then
                              return;
                           end if;
                           Values := (others => 0);
                           Count := 0;
                        end if;
                     end if;
                  end;
               end loop;
            end;
         end loop;

         if Count > 0 and then not Done then
            Flush_Group;
            if Done
              and then Result.Decode_Status /= Decode_Trailing_Data
            then
               return;
            end if;
         end if;

         if Result.Decoded_Length /= Expected_Decoded_Length
           or else Row_Length /= 0
           or else Y /= Pixel_Height
         then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            return;
         end if;
      end;

      Result.Decode_Complete := True;
      Result.Decode_Status := Decode_Ok;
   end Decode_Base64_Raw_Chunk_Rows;

   procedure Decode_Base64_Raw_Rows
     (Text         : String;
      Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Sink     : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result       : in out Graphics_Data_Preview)
   is
      function Single_Chunk (Index : Positive) return String is
      begin
         if Index = 1 then
            return Text;
         else
            return "";
         end if;
      end Single_Chunk;
   begin
      Decode_Base64_Raw_Chunk_Rows
        (1,
         Single_Chunk'Access,
         Raw_Format,
         Pixel_Width,
         Pixel_Height,
         Row_Sink,
         Result);
   end Decode_Base64_Raw_Rows;

   function Data_Decode_Status_Suffix
     (Status : Data_Decode_Status) return String
   is
   begin
      case Status is
         when Decode_Not_Attempted | Decode_Ok =>
            return "";
         when Decode_Invalid_Byte =>
            return " invalid-byte";
         when Decode_Trailing_Data =>
            return " trailing-data";
         when Decode_Preview_Truncated =>
            return " truncated";
         when Decode_Unsupported_Format =>
            return " unsupported-format";
      end case;
   end Data_Decode_Status_Suffix;

   function Image_Decode_Status
     (Status : Data_Decode_Status)
      return Terminal.App.Render_Model.Image_Decode_Status
   is
      package RM renames Terminal.App.Render_Model;
   begin
      case Status is
         when Decode_Not_Attempted =>
            return RM.Image_Decode_Not_Attempted;
         when Decode_Ok =>
            return RM.Image_Decode_Ok;
         when Decode_Invalid_Byte =>
            return RM.Image_Decode_Invalid_Byte;
         when Decode_Trailing_Data =>
            return RM.Image_Decode_Trailing_Data;
         when Decode_Preview_Truncated =>
            return RM.Image_Decode_Preview_Truncated;
         when Decode_Unsupported_Format =>
            return RM.Image_Decode_Unsupported_Format;
      end case;
   end Image_Decode_Status;

   function Capability
     (Protocol : Graphics_Protocol) return Protocol_Capability
   is
   begin
      case Protocol is
         when Kitty =>
            return
              (Recognized => True,
               Decoded    => True,
               Rendered   => True);
         when Sixel | ITerm2 =>
            return
              (Recognized => True,
               Decoded    => True,
               Rendered   => True);
      end case;
   end Capability;

   function Color_Emoji return Emoji_Capability is
   begin
      return
        (Cluster_Preserved    => True,
         Monochrome_Fallback  => True,
         Color_Glyph_Rendered => False);
   end Color_Emoji;

   function Name (Protocol : Graphics_Protocol) return String is
   begin
      case Protocol is
         when Sixel =>
            return "sixel";
         when Kitty =>
            return "kitty";
         when ITerm2 =>
            return "iTerm2";
      end case;
   end Name;

   function Name (Protocol : Terminal.Core.Ignored_Graphics_Protocol)
                  return String is
   begin
      case Protocol is
         when Terminal.Core.No_Graphics =>
            return "";
         when Terminal.Core.Sixel_Graphics =>
            return "sixel";
         when Terminal.Core.Kitty_Graphics =>
            return "kitty";
         when Terminal.Core.ITerm2_Graphics =>
            return "iTerm2";
      end case;
   end Name;

   function Capability_Status_Label
     (Protocol : Graphics_Protocol) return String is
   begin
      case Protocol is
         when Sixel =>
            return "sixel graphics recognized; raster texture rendering available";
         when Kitty =>
            return "kitty graphics recognized; raw/PNG texture rendering available";
         when ITerm2 =>
            return "iTerm2 images recognized; PNG texture rendering available";
      end case;
   end Capability_Status_Label;

   function Header_Text
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Text     : String) return Graphics_Header
   is
      Result : Graphics_Header;
   begin
      if Text = "" then
         return Result;
      end if;

      case Protocol is
         when Terminal.Core.Sixel_Graphics =>
            Result.Recognized := Text (Text'First) = 'q'
              or else Text (Text'First) in '0' .. '9'
              or else Text (Text'First) = '?';
            Result.Has_Data := Text'Length > 0;
            if Result.Recognized then
               declare
                  Info : constant Sixel_Info := Analyze_Sixel (Text);
               begin
                  Result.Raw_Format := (if Info.Width > 0 then 32 else 0);
                  Result.Pixel_Width := Info.Width;
                  Result.Pixel_Height := Info.Height;
               end;
            end if;
         when Terminal.Core.Kitty_Graphics =>
            if Text (Text'First) /= 'G' then
               return Result;
            end if;
            Result.Recognized := True;
            declare
               Header_Last : Natural := Text'Last;
            begin
               for I in Text'Range loop
                  if Text (I) = ';' then
                     Header_Last := I - 1;
                     Result.Has_Data := I < Text'Last;
                     exit;
                  end if;
               end loop;
               if Header_Last > Text'First then
                  declare
                     Params : constant String :=
                       Text (Text'First + 1 .. Header_Last);
                     Action : constant String := Field_Value (Params, "a");
                  begin
                     Result.Kitty_Action :=
                       (if Action'Length > 0 then Action (Action'First)
                        else ASCII.NUL);
                     Result.Kitty_ID :=
                       Parse_Natural (Field_Value (Params, "i"));
                     Result.Kitty_Format :=
                       Parse_Natural (Field_Value (Params, "f"));
                     Result.Kitty_More :=
                       Field_Value (Params, "m") = "1";
                     Result.Raw_Format := Result.Kitty_Format;
                     Result.Pixel_Width :=
                       Parse_Natural (Field_Value (Params, "s"));
                     Result.Pixel_Height :=
                       Parse_Natural (Field_Value (Params, "v"));
                     Result.Placeholder_Cols :=
                       Clamp_Positive
                         (Parse_Natural (Field_Value (Params, "c")), 6, 80);
                     Result.Placeholder_Rows :=
                       Clamp_Positive
                         (Parse_Natural (Field_Value (Params, "r")), 3, 40);
                  end;
               end if;
            end;
         when Terminal.Core.ITerm2_Graphics =>
            if Text'Length < 5 or else Text (Text'First .. Text'First + 4) /= "File=" then
               return Result;
            end if;
            Result.Recognized := True;
            declare
               Header_Last : Natural := Text'Last;
            begin
               for I in Text'Range loop
                  if Text (I) = ':' then
                     Header_Last := I - 1;
                     Result.Has_Data := I < Text'Last;
                     exit;
                  end if;
               end loop;
               if Header_Last >= Text'First + 5 then
                  declare
                     Params : constant String := Text (Text'First + 5 .. Header_Last);
                     Inline : constant String := Field_Value (Params, "inline");
                     Name   : constant String := Field_Value (Params, "name");
                     Width  : constant Natural :=
                       Parse_Natural (Field_Value (Params, "width"));
                     Height : constant Natural :=
                       Parse_Natural (Field_Value (Params, "height"));
                  begin
                     Result.ITerm2_Inline := Inline = "1";
                     Result.ITerm2_Name_Length := Name'Length;
                     Result.Placeholder_Cols := Clamp_Positive (Width, 6, 80);
                     Result.Placeholder_Rows := Clamp_Positive (Height, 3, 40);
                  end;
               end if;
            end;
         when Terminal.Core.No_Graphics =>
            null;
      end case;

      return Result;
   end Header_Text;

   function Header (Event : Terminal.Core.Graphics_Event) return Graphics_Header is
   begin
      if not Event.Pending then
         return (others => <>);
      end if;
      return Header_Text (Event.Protocol, Preview_Text (Event));
   end Header;

   function Data_Preview_Text
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Text     : String) return Graphics_Data_Preview
   is
      H    : constant Graphics_Header := Header_Text (Protocol, Text);
      From : Natural;
      Result : Graphics_Data_Preview :=
        (Header_Recognized => H.Recognized,
         Has_Data          => H.Has_Data,
         Raw_Format        => H.Raw_Format,
         Pixel_Width       => H.Pixel_Width,
         Pixel_Height      => H.Pixel_Height,
         others            => <>);
   begin
      if not H.Recognized or else not H.Has_Data or else Text = "" then
         return Result;
      end if;

      From := Data_First (Protocol, Text);
      if From = 0 then
         Result.Has_Data := False;
         return Result;
      end if;

      Result.Encoded_Length := Text'Last - From + 1;

      case Protocol is
         when Terminal.Core.Kitty_Graphics =>
            declare
               Bytes_Per_Pixel : constant Natural :=
                 Raw_Bytes_Per_Pixel (H.Kitty_Format);
               Has_Raw_Metadata : constant Boolean :=
                 Bytes_Per_Pixel > 0
                 and then H.Pixel_Width > 0
                 and then H.Pixel_Height > 0;
               Expected_Decoded_Length : constant Natural :=
                 Raw_Decoded_Length
                   (H.Kitty_Format, H.Pixel_Width, H.Pixel_Height);
            begin
               if Has_Raw_Metadata and then Expected_Decoded_Length = 0 then
                  Result.Decode_Status := Decode_Preview_Truncated;
                  Result.Decode_Complete := False;
                  return Result;
               else
                  Decode_Base64_Preview
                    (Text (From .. Text'Last),
                     Result,
                     (if Has_Raw_Metadata then Expected_Decoded_Length else 0));
               end if;
            end;
            if H.Kitty_Format = 100
              and then Result.Decode_Complete
              and then Result.Bytes /= null
            then
               declare
                  PNG : Terminal.App.Render_Model.Image_Data_Access :=
                    Result.Bytes;
                  PNG_Length : constant Natural := Result.Decoded_Length;
               begin
                  Result.Bytes := null;
                 Result.Decoded_Length := 0;
                  Result.Decoded_Row_Stride_Bytes := 0;
                  Result.Raw_Format := 0;
                  Result.Pixel_Width := 0;
                  Result.Pixel_Height := 0;
                  Decode_PNG_RGBA (PNG.all, PNG_Length, Result);
                  Free_Image_Data (PNG);
               end;
            end if;
         when Terminal.Core.ITerm2_Graphics =>
            Decode_Base64_Preview (Text (From .. Text'Last), Result);
            if Result.Decode_Complete and then Result.Bytes /= null then
               declare
                  PNG : Terminal.App.Render_Model.Image_Data_Access :=
                    Result.Bytes;
                  PNG_Length : constant Natural := Result.Decoded_Length;
               begin
                  Result.Bytes := null;
                 Result.Decoded_Length := 0;
                  Result.Decoded_Row_Stride_Bytes := 0;
                  Result.Raw_Format := 0;
                  Result.Pixel_Width := 0;
                  Result.Pixel_Height := 0;
                  Decode_PNG_RGBA (PNG.all, PNG_Length, Result);
                  Free_Image_Data (PNG);
               end;
            end if;
         when Terminal.Core.Sixel_Graphics =>
            Decode_Sixel_Raster
              (Text, (Width => H.Pixel_Width, Height => H.Pixel_Height), Result);
         when Terminal.Core.No_Graphics =>
            null;
      end case;

      return Result;
   end Data_Preview_Text;

   function Data_Preview
     (Event : Terminal.Core.Graphics_Event) return Graphics_Data_Preview
   is
   begin
      if not Event.Pending then
         return (others => <>);
      end if;
      return Data_Preview_Text (Event.Protocol, Preview_Text (Event));
   end Data_Preview;

   function Data_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String
   is
      Data : Graphics_Data_Preview := Data_Preview (Event);

      function Build_Label return String is
      begin
         if not Data.Header_Recognized then
            return "";
         elsif not Data.Has_Data then
            return Name (Event.Protocol) & " data preview unavailable";
         end if;

         case Event.Protocol is
            when Terminal.Core.Sixel_Graphics =>
               return "sixel raster decoded="
              & Trimmed_Natural (Data.Decoded_Length)
              & "/"
              & Trimmed_Natural (Data.Encoded_Length)
              & (if Data.Bytes = null
                 then ""
                 else Terminal.Common.Status.Preview_Bytes_Label
                   (Data.Bytes.all, Data.Decoded_Length))
              & (if Data.Decode_Complete then " decoded" else " partial")
              & Data_Decode_Status_Suffix (Data.Decode_Status);
            when Terminal.Core.Kitty_Graphics =>
               return "kitty data preview decoded="
              & Trimmed_Natural (Data.Decoded_Length)
              & "/"
              & Trimmed_Natural (Data.Encoded_Length)
              & (if Data.Bytes = null
                 then ""
                 else Terminal.Common.Status.Preview_Bytes_Label
                   (Data.Bytes.all, Data.Decoded_Length))
              & (if Data.Decode_Complete then " decoded" else " partial")
              & Data_Decode_Status_Suffix (Data.Decode_Status);
            when Terminal.Core.ITerm2_Graphics =>
               return "iTerm2 data preview decoded="
              & Trimmed_Natural (Data.Decoded_Length)
              & "/"
              & Trimmed_Natural (Data.Encoded_Length)
              & (if Data.Bytes = null
                 then ""
                 else Terminal.Common.Status.Preview_Bytes_Label
                   (Data.Bytes.all, Data.Decoded_Length))
              & (if Data.Decode_Complete then " decoded" else " partial")
              & Data_Decode_Status_Suffix (Data.Decode_Status);
            when Terminal.Core.No_Graphics =>
               return "";
         end case;
      end Build_Label;
   begin
      declare
         Label : constant String := Build_Label;
      begin
         Release (Data);
         return Label;
      end;
   end Data_Status_Label;

   function Header_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String
   is
      H : constant Graphics_Header := Header (Event);
   begin
      if not H.Recognized then
         return "";
      end if;

      case Event.Protocol is
         when Terminal.Core.Sixel_Graphics =>
            return "sixel header ready; payload="
              & Trimmed_Natural (Event.Payload_Length)
              & (if H.Pixel_Width > 0 and then H.Pixel_Height > 0
                 then
                   "; pixels=" & Trimmed_Natural (H.Pixel_Width)
                   & "x" & Trimmed_Natural (H.Pixel_Height)
                 else "");
         when Terminal.Core.Kitty_Graphics =>
            return "kitty header ready; format="
              & Trimmed_Natural (H.Kitty_Format)
              & (if H.Pixel_Width > 0 and then H.Pixel_Height > 0
                 then
                   "; pixels=" & Trimmed_Natural (H.Pixel_Width)
                   & "x" & Trimmed_Natural (H.Pixel_Height)
                 else "")
              & (if H.Has_Data then "; data previewed" else "; no data preview");
         when Terminal.Core.ITerm2_Graphics =>
            return "iTerm2 header ready; inline="
              & (if H.ITerm2_Inline then "yes" else "no")
              & "; name bytes="
              & Trimmed_Natural (H.ITerm2_Name_Length);
         when Terminal.Core.No_Graphics =>
            return "";
      end case;
   end Header_Status_Label;

   function Placeholder_Cols
     (Event : Terminal.Core.Graphics_Event) return Positive
   is
      H : constant Graphics_Header := Header (Event);
   begin
      return H.Placeholder_Cols;
   end Placeholder_Cols;

   function Placeholder_Rows
     (Event : Terminal.Core.Graphics_Event) return Positive
   is
      H : constant Graphics_Header := Header (Event);
   begin
      return H.Placeholder_Rows;
   end Placeholder_Rows;

   function Ignored_Status_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String
   is
      Last : Natural := 0;
      Result : String (1 .. Max_Status_Label_Length);

      procedure Append (Ch : Character) is
      begin
         if Last < Result'Last then
            Last := Last + 1;
            Result (Last) := Ch;
         end if;
      end Append;

      procedure Append_Natural (Value : Natural) is
         Text : constant String := Natural'Image (Value);
      begin
         for I in Text'First + 1 .. Text'Last loop
            Append (Text (I));
         end loop;
      end Append_Natural;

      procedure Append_String (Text : String) is
      begin
         for Ch of Text loop
            Append (Ch);
         end loop;
      end Append_String;
   begin
      if Diagnostics.Graphics_Protocol_Ignored = 0
        or else Diagnostics.Last_Graphics_Protocol = Terminal.Core.No_Graphics
      then
         return "";
      end if;

      Append_String ("Ignored ");
      case Diagnostics.Last_Graphics_Protocol is
         when Terminal.Core.No_Graphics =>
            null;
         when Terminal.Core.Sixel_Graphics =>
            Append_String ("sixel graphics");
         when Terminal.Core.Kitty_Graphics =>
            Append_String ("kitty graphics");
         when Terminal.Core.ITerm2_Graphics =>
            Append_String ("iTerm2 image");
      end case;
      Append_String (" payload");
      if Diagnostics.Last_Graphics_Payload_Length > 0 then
         Append_String (" (");
         Append_Natural (Diagnostics.Last_Graphics_Payload_Length);
         Append_String (" bytes)");
      end if;

      return Result (1 .. Last);
   end Ignored_Status_Label;
end Terminal.App.Graphics;
