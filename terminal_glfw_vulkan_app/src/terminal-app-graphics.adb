with Ada.Streams;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Image_Decode;
with Terminal.App.Image_Media;
with Terminal.App.Zlib_Inflation;
with Ada.Finalization;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Jpeglib.Decoding;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;
with Zlib;

package body Terminal.App.Graphics is
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Jpeglib.Byte;
   use type Jpeglib.Results.Result;
   use type Jpeglib.Streams.Byte_Array_Access;
   use type Zlib.Status_Code;

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);
   procedure Free_JPEG_Data is new Ada.Unchecked_Deallocation
     (Jpeglib.Streams.Byte_Array,
      Jpeglib.Streams.Byte_Array_Access);
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

   function Valid_Natural_Text (Text : String) return Boolean is
      Value : Natural := 0;
   begin
      if Text'Length = 0 then
         return False;
      end if;
      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return False;
         end if;
         declare
            Digit : constant Natural :=
              Character'Pos (Ch) - Character'Pos ('0');
         begin
            if Value > (Natural'Last - Digit) / 10 then
               return False;
            end if;
            Value := Value * 10 + Digit;
         end;
      end loop;
      return True;
   end Valid_Natural_Text;

   function Parse_Graphics_ID
     (Text : String) return Terminal.Core.Graphics_ID
   is
      Value : Long_Long_Integer := 0;
      Limit : constant Long_Long_Integer :=
        Long_Long_Integer (Terminal.Core.Graphics_ID'Last);
   begin
      if Text'Length = 0 then
         return 0;
      end if;

      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return 0;
         end if;
         declare
            Digit : constant Long_Long_Integer :=
              Long_Long_Integer
                (Character'Pos (Ch) - Character'Pos ('0'));
         begin
            if Value > (Limit - Digit) / 10 then
               return 0;
            end if;
            Value := Value * 10 + Digit;
         end;
      end loop;
      return Terminal.Core.Graphics_ID (Value);
   end Parse_Graphics_ID;

   function Parse_Integer (Text : String) return Integer is
      Negative : Boolean := False;
      First    : Natural := Text'First;
      Value    : Long_Long_Integer := 0;
      Limit    : Long_Long_Integer := Long_Long_Integer (Integer'Last);
   begin
      if Text'Length = 0 then
         return 0;
      end if;

      if Text (First) = '-' then
         Negative := True;
         First := First + 1;
         Limit := -Long_Long_Integer (Integer'First);
      elsif Text (First) = '+' then
         First := First + 1;
      end if;

      if First > Text'Last then
         return 0;
      end if;

      for I in First .. Text'Last loop
         if Text (I) not in '0' .. '9' then
            return 0;
         end if;
         declare
            Digit : constant Long_Long_Integer :=
              Long_Long_Integer
                (Character'Pos (Text (I)) - Character'Pos ('0'));
         begin
            if Value > (Limit - Digit) / 10 then
               return 0;
            end if;
            Value := Value * 10 + Digit;
         end;
      end loop;

      if Negative then
         if Value = Limit then
            return Integer'First;
         else
            return Integer (-Value);
         end if;
      else
         return Integer (Value);
      end if;
   end Parse_Integer;

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
      if Raw_Format = 8 then
         return 1;
      elsif Raw_Format = 16 then
         return 2;
      elsif Raw_Format = 24 then
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

   function Is_JPEG
     (Data   : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean is
   begin
      return Length >= 2
        and then Data'Length >= 2
        and then Data (Data'First) = 16#FF#
        and then Data (Data'First + 1) = 16#D8#;
   end Is_JPEG;

   type Sixel_Info is record
      Width  : Natural := 0;
      Height : Natural := 0;
      Logical_Height : Natural := 0;
      Vertical_Aspect : Positive := 1;
      Transparent : Boolean := False;
   end record;

   type PNG_Info is record
      Width  : Natural := 0;
      Height : Natural := 0;
      Color_Type : Natural := 0;
   end record;

   subtype Sixel_Palette is Sixel_Palette_State;
   type PNG_Palette is array (Natural range 0 .. 255) of Sixel_Color;

   function Byte_From_Percent (Value : Natural) return Terminal.Common.Bytes.Byte
   is
      Clamped : constant Natural := Natural'Min (Value, 100);
   begin
      return Terminal.Common.Bytes.Byte ((Clamped * 255 + 50) / 100);
   end Byte_From_Percent;

   function Sixel_HLS_Color
     (Hue, Lightness, Saturation : Natural) return Sixel_Color
   is
      --  DEC's HLS wheel starts at blue: 0=blue, 120=red, 240=green.
      H : constant Float :=
        Float ((Natural'Min (Hue, 360) + 240) mod 360) / 360.0;
      L : constant Float := Float (Natural'Min (Lightness, 100)) / 100.0;
      S : constant Float := Float (Natural'Min (Saturation, 100)) / 100.0;
      M2 : constant Float :=
        (if L <= 0.5 then L * (1.0 + S) else L + S - L * S);
      M1 : constant Float := 2.0 * L - M2;

      function Hue_Value (Input : Float) return Terminal.Common.Bytes.Byte is
         T : Float := Input;
         Value : Float;
      begin
         while T < 0.0 loop
            T := T + 1.0;
         end loop;
         while T > 1.0 loop
            T := T - 1.0;
         end loop;
         if S = 0.0 then
            Value := L;
         elsif 6.0 * T < 1.0 then
            Value := M1 + (M2 - M1) * 6.0 * T;
         elsif 2.0 * T < 1.0 then
            Value := M2;
         elsif 3.0 * T < 2.0 then
            Value := M1 + (M2 - M1) * (2.0 / 3.0 - T) * 6.0;
         else
            Value := M1;
         end if;
         return Terminal.Common.Bytes.Byte
           (Natural'Min (255, Natural (Float'Rounding (Value * 255.0))));
      end Hue_Value;
   begin
      return
        (R => Hue_Value (H + 1.0 / 3.0),
         G => Hue_Value (H),
         B => Hue_Value (H - 1.0 / 3.0),
         A => 16#FF#);
   end Sixel_HLS_Color;

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

   function Default_Sixel_Palette return Sixel_Palette_State is
      Palette : Sixel_Palette_State :=
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
      Declared_Width : Natural := 0;
      Declared_Height : Natural := 0;
      Vertical_Aspect : Positive := 1;
      Transparent : Boolean := False;

      procedure Add_X (Amount : Natural) is
      begin
         if X > Natural'Last - Amount then
            X := Natural'Last;
         else
            X := X + Amount;
         end if;
      end Add_X;
   begin
      while I <= Text'Last and then Text (I) /= 'q' loop
         I := I + 1;
      end loop;
      if I > Text'Last then
         return
           (Width => 0,
            Height => 0,
            Logical_Height => 0,
            Vertical_Aspect => 1,
            Transparent => False);
      end if;

      --  The second DCS parameter is the background mode.  Value one means
      --  that unset pixels are transparent; zero and two erase to register 0.
      declare
         J : Natural := Text'First;
         Aspect_Code : Natural := 0;
      begin
         if J < I and then Text (J) in '0' .. '9' then
            Aspect_Code := Read_Sixel_Number (Text, J);
            Vertical_Aspect :=
              (case Aspect_Code is
                  when 0 | 1 | 5 | 6 => 2,
                  when 2 => 5,
                  when 3 | 4 => 3,
                  when others => 1);
         end if;
      end;

      declare
         J : Natural := Text'First;
         Parameter : Natural := 1;
      begin
         while J < I loop
            if Text (J) = ';' then
               Parameter := Parameter + 1;
               J := J + 1;
            elsif Parameter = 2 then
               Transparent := Read_Sixel_Number (Text, J) = 1;
               exit;
            else
               Skip_Sixel_Number (Text, J);
            end if;
         end loop;
      end;

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
            when '"' =>
               I := I + 1;
               --  Pan and Pad describe pixel aspect.  Ph and Pv declare a
               --  minimum canvas but never clip following sixel data.
               declare
                  Pan : constant Natural := Read_Sixel_Number (Text, I);
                  Pad : Natural := 0;
               begin
                  if I <= Text'Last and then Text (I) = ';' then
                     I := I + 1;
                     Pad := Read_Sixel_Number (Text, I);
                  end if;
                  if Pan > 0 and then Pad > 0 then
                     declare
                        Ratio : constant Natural :=
                          Pan / Pad + (if Pan mod Pad = 0 then 0 else 1);
                     begin
                        Vertical_Aspect :=
                          Positive (Natural'Max (Ratio, 1));
                     end;
                  end if;
               end;
               if I <= Text'Last and then Text (I) = ';' then
                  I := I + 1;
                  Declared_Width := Read_Sixel_Number (Text, I);
               end if;
               if I <= Text'Last and then Text (I) = ';' then
                  I := I + 1;
                  Declared_Height := Read_Sixel_Number (Text, I);
               end if;
            when '$' =>
               X := 0;
               I := I + 1;
            when '-' =>
               X := 0;
               if Y > Natural'Last - 6 then
                  Y := Natural'Last;
               else
                  Y := Y + 6;
               end if;
               Max_Y := Natural'Max (Max_Y, Y);
               I := I + 1;
            when '?' .. '~' =>
               declare
                  Bits : constant Natural := Character'Pos (Text (I)) - 63;
               begin
                  pragma Unreferenced (Bits);
                  if Y <= Natural'Last - 6 then
                     Max_Y := Natural'Max (Max_Y, Y + 6);
                  else
                     Max_Y := Natural'Last;
                  end if;
                  Add_X (Repeat_Count);
                  Max_X := Natural'Max (Max_X, X);
                  Repeat_Count := 1;
                  I := I + 1;
               end;
            when others =>
               Repeat_Count := 1;
               I := I + 1;
         end case;
      end loop;

      Max_X := Natural'Max (Max_X, Declared_Width);
      Max_Y := Natural'Max (Max_Y, Declared_Height);
      if Max_X = 0 or else Max_Y = 0 then
         return
           (Width => 0,
            Height => 0,
            Logical_Height => 0,
            Vertical_Aspect => Vertical_Aspect,
            Transparent => Transparent);
      end if;
      if Max_Y > Natural'Last / Vertical_Aspect then
         return
           (Width => Max_X,
            Height => Natural'Last,
            Logical_Height => Max_Y,
            Vertical_Aspect => Vertical_Aspect,
            Transparent => Transparent);
      end if;
      return
        (Width => Max_X,
         Height => Max_Y * Vertical_Aspect,
         Logical_Height => Max_Y,
         Vertical_Aspect => Vertical_Aspect,
         Transparent => Transparent);
   end Analyze_Sixel;

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

   procedure Decode_Sixel_Rows
     (Text   : String;
      Row_Sink : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension)
   is
      Palette : Sixel_Palette_State := Default_Sixel_Palette;
   begin
      Decode_Sixel_Rows
        (Text,
         Row_Sink,
         Palette,
         Reset_Palette => False,
         Result => Result,
         Maximum_Decoded_Bytes => Maximum_Decoded_Bytes,
         Maximum_Pixel_Dimension => Maximum_Pixel_Dimension);
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
   is separate;

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

   procedure Decode_JPEG_RGBA_Data
     (JPEG   : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Positive'Last)
   is
   begin
      if Length = 0 or else Length > JPEG'Length then
         Result.Decode_Status := Decode_Unsupported_Format;
         Result.Decode_Complete := False;
         return;
      elsif not Is_JPEG (JPEG, Length) then
         Result.Decode_Status := Decode_Unsupported_Format;
         Result.Decode_Complete := False;
         return;
      end if;

      declare
         Input : Jpeglib.Streams.Byte_Array_Access :=
           new Jpeglib.Streams.Byte_Array (1 .. Length);
         Source : aliased Jpeglib.Streams.Memory_Source;
         Decoder : Jpeglib.Decoding.Decoder;
         Decoder_Initialized : Boolean := False;
         Outcome : Jpeglib.Results.Result;
         Info : Jpeglib.Decoding.Image_Info;
      begin
         for I in Input'Range loop
            Input (I) := Jpeglib.Byte (JPEG (JPEG'First + I - Input'First));
         end loop;

         Jpeglib.Streams.Open
           (Source, Jpeglib.Streams.Const_Byte_Array_Access (Input));
         Jpeglib.Decoding.Initialize
           (Decoder,
            Source'Access,
           (Output_Format => Jpeglib.Images.RGBA_32,
             Alpha_Fill => 255,
             others => <>));
         Decoder_Initialized := True;

         Outcome := Jpeglib.Decoding.Read_Header (Decoder);
         if not Jpeglib.Results.Succeeded (Outcome) then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            Jpeglib.Decoding.Finalize (Decoder);
            Decoder_Initialized := False;
            Free_JPEG_Data (Input);
            return;
         end if;

         Info := Jpeglib.Decoding.Header (Decoder);
         if Natural (Info.Width) = 0
           or else Natural (Info.Height) = 0
           or else Natural (Info.Width) > Maximum_Pixel_Dimension
           or else Natural (Info.Height) > Maximum_Pixel_Dimension
           or else RGBA_Decoded_Length
             (Natural (Info.Width), Natural (Info.Height)) = 0
           or else RGBA_Decoded_Length
             (Natural (Info.Width), Natural (Info.Height)) >
               Maximum_Decoded_Bytes
         then
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            Result.Decoded_Length := Max_Data_Preview_Length;
            Jpeglib.Decoding.Finalize (Decoder);
            Decoder_Initialized := False;
            Free_JPEG_Data (Input);
            return;
         end if;

         declare
            Width : constant Natural := Natural (Info.Width);
            Height : constant Natural := Natural (Info.Height);
            RGBA_Bytes : constant Natural :=
              RGBA_Decoded_Length (Width, Height);
            Output : Jpeglib.Streams.Byte_Array_Access :=
              new Jpeglib.Streams.Byte_Array (1 .. RGBA_Bytes);
            View : Jpeglib.Images.Mutable_Image_View :=
              (Descriptor =>
                 (Width => Info.Width,
                  Height => Info.Height,
                  Format => Jpeglib.Images.RGBA_32,
                  Stride => Jpeglib.Row_Stride (Width * 4),
                  Accessible_Bytes => Jpeglib.Byte_Count (RGBA_Bytes)),
               Storage => Output);
         begin
            Output.all := (others => 0);
            Outcome := Jpeglib.Decoding.Decode_Image (Decoder, View);
            if not Jpeglib.Results.Succeeded (Outcome) then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               Free_JPEG_Data (Output);
               Jpeglib.Decoding.Finalize (Decoder);
               Decoder_Initialized := False;
               Free_JPEG_Data (Input);
               return;
            end if;

            Ensure_Bytes (Result, RGBA_Bytes);
            for I in 1 .. RGBA_Bytes loop
               Result.Bytes (I) := Terminal.Common.Bytes.Byte (Output (I));
            end loop;
            Free_JPEG_Data (Output);

            Result.Raw_Format := 32;
            Result.Pixel_Width := Width;
            Result.Pixel_Height := Height;
            Result.Decoded_Row_Stride_Bytes := Width * 4;
            Result.Decoded_Length := RGBA_Bytes;
            Result.Decode_Complete := True;
            Result.Decode_Status := Decode_Ok;
         exception
            when others =>
               if Output /= null then
                  Free_JPEG_Data (Output);
               end if;
               raise;
         end;

         Jpeglib.Decoding.Finalize (Decoder);
         Decoder_Initialized := False;
         Free_JPEG_Data (Input);
      exception
         when Storage_Error =>
            Result.Decode_Status := Decode_Allocation_Failed;
            Result.Decode_Complete := False;
            if Decoder_Initialized then
               Jpeglib.Decoding.Finalize (Decoder);
            end if;
            if Input /= null then
               Free_JPEG_Data (Input);
            end if;
         when Constraint_Error =>
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            Result.Decoded_Length := Max_Data_Preview_Length;
            if Decoder_Initialized then
               Jpeglib.Decoding.Finalize (Decoder);
            end if;
            if Input /= null then
               Free_JPEG_Data (Input);
            end if;
         when others =>
            if Decoder_Initialized then
               Jpeglib.Decoding.Finalize (Decoder);
            end if;
            if Input /= null then
               Free_JPEG_Data (Input);
            end if;
            raise;
      end;
   end Decode_JPEG_RGBA_Data;

   procedure Decode_Image_RGBA_Data
     (Data   : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Result : in out Graphics_Data_Preview)
   is
   begin
      Decode_PNG_RGBA (Data, Length, Result);
      if Result.Decode_Status = Decode_Unsupported_Format then
         Result.Decoded_Length := 0;
         Result.Decoded_Row_Stride_Bytes := 0;
         Result.Raw_Format := 0;
         Result.Pixel_Width := 0;
         Result.Pixel_Height := 0;
         Decode_JPEG_RGBA_Data (Data, Length, Result);
      end if;
      if Result.Decode_Status = Decode_Unsupported_Format
        and then Terminal.App.Image_Media.Available
      then
         declare
            Media : Terminal.App.Image_Media.Decoded_Image;
            Media_Status : Terminal.App.Image_Media.Decode_Status;
         begin
            Terminal.App.Image_Media.Decode
              (Data,
               Length,
               Max_Data_Preview_Length,
               Max_Sixel_Pixel_Dimension,
               Media,
               Media_Status);
            if Media_Status = Terminal.App.Image_Media.Decode_Ok
              and then Media.Bytes /= null
              and then Media.Frame_Bytes > 0
            then
               Release (Result);
               Result :=
                 (Header_Recognized => True,
                  Has_Data => True,
                  Raw_Format => 32,
                  Pixel_Width => Media.Pixel_Width,
                  Pixel_Height => Media.Pixel_Height,
                  Decoded_Length => Media.Frame_Bytes,
                  Decoded_Row_Stride_Bytes => Media.Pixel_Width * 4,
                  Decode_Complete => True,
                  Decode_Status => Decode_Ok,
                  Bytes =>
                    new Terminal.Common.Bytes.Byte_Array
                      (1 .. Media.Frame_Bytes),
                  others => <>);
               Result.Bytes.all :=
                 Media.Bytes
                   (Media.Bytes'First
                    .. Media.Bytes'First + Media.Frame_Bytes - 1);
            else
               Result.Decode_Status :=
                 (if Media_Status = Terminal.App.Image_Media.Decode_Ok
                  then Decode_Invalid_Data
                  else Media_Status);
            end if;
            Terminal.App.Image_Media.Release (Media);
         end;
      end if;
   end Decode_Image_RGBA_Data;

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

   procedure Decode_Base64_Data
     (Text                  : String;
      Maximum_Decoded_Bytes : Positive;
      Data                  : out Terminal.App.Render_Model.Image_Data_Access;
      Length                : out Natural;
      Status                : out Data_Decode_Status)
   is
      Encoded_Count : Natural := 0;
      Padding       : Natural := 0;
      Result : Graphics_Data_Preview :=
        (Header_Recognized => True,
         Has_Data          => Text'Length > 0,
         others            => <>);
      Expected : Natural := 0;
   begin
      Data := null;
      Length := 0;
      Status := Decode_Not_Attempted;
      for Ch of Text loop
         if Ch /= ASCII.CR and then Ch /= ASCII.LF and then Ch /= ' ' then
            Encoded_Count := Encoded_Count + 1;
            if Ch = '=' then
               Padding := Padding + 1;
            end if;
         end if;
      end loop;
      if Encoded_Count = 0
        or else Encoded_Count mod 4 /= 0
        or else Padding > 2
        or else Encoded_Count / 4 > Natural'Last / 3
      then
         Status := Decode_Invalid_Byte;
         return;
      end if;
      Expected := (Encoded_Count / 4) * 3 - Padding;
      if Expected = 0 or else Expected > Maximum_Decoded_Bytes then
         Status := Decode_Preview_Truncated;
         return;
      end if;
      Decode_Base64_Preview (Text, Result, Expected);
      Status := Result.Decode_Status;
      if Result.Decode_Complete
        and then Result.Decode_Status = Decode_Ok
        and then Result.Decoded_Length = Expected
        and then Result.Bytes /= null
      then
         Data := Result.Bytes;
         Result.Bytes := null;
         Length := Expected;
      end if;
      Release (Result);
   exception
      when Storage_Error =>
         Release (Result);
         Data := null;
         Length := 0;
         Status := Decode_Allocation_Failed;
   end Decode_Base64_Data;

   function JPEG_Data_Preview_Text
     (Text                    : String;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive) return Graphics_Data_Preview
   is
      H : constant Graphics_Header :=
        Header_Text (Terminal.Core.ITerm2_Graphics, Text);
      From : Natural := 0;
      Result : Graphics_Data_Preview :=
        (Header_Recognized => H.Recognized,
         Has_Data          => H.Has_Data,
         others            => <>);
   begin
      if not H.Recognized or else not H.Has_Data or else Text = "" then
         return Result;
      end if;

      From := Data_First (Terminal.Core.ITerm2_Graphics, Text);
      if From = 0 then
         Result.Has_Data := False;
         return Result;
      end if;

      Result.Encoded_Length := Text'Last - From + 1;
      declare
         Encoded_Length : constant Natural := Result.Encoded_Length;
         --  Base64 produces at most three bytes per four input bytes.  The
         --  expression is split to keep all arithmetic overflow-safe.
         Expected_Length : constant Natural :=
           (Encoded_Length / 4) * 3
           + Natural'Min ((Encoded_Length mod 4) * 3, 3);
      begin
         if Expected_Length = 0
           or else Expected_Length > Max_Data_Preview_Length
         then
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            return Result;
         end if;

         Decode_Base64_Preview
           (Text (From .. Text'Last), Result, Expected_Length);
      end;

      if Result.Decode_Complete and then Result.Bytes /= null then
         declare
            JPEG : Terminal.App.Render_Model.Image_Data_Access := Result.Bytes;
            JPEG_Length : constant Natural := Result.Decoded_Length;
         begin
            Result.Bytes := null;
            Result.Decoded_Length := 0;
            Result.Decoded_Row_Stride_Bytes := 0;
            Result.Raw_Format := 0;
            Result.Pixel_Width := 0;
            Result.Pixel_Height := 0;
            Decode_JPEG_RGBA_Data
              (JPEG.all,
               JPEG_Length,
               Result,
               Maximum_Decoded_Bytes,
               Maximum_Pixel_Dimension);
            Free_Image_Data (JPEG);
         exception
            when others =>
               if JPEG /= null then
                  Free_Image_Data (JPEG);
               end if;
               raise;
         end;
      end if;

      return Result;
   exception
      when Storage_Error =>
         Release (Result);
         Result.Decode_Status := Decode_Allocation_Failed;
         Result.Decode_Complete := False;
         return Result;
      when Constraint_Error =>
         Release (Result);
         Result.Decode_Status := Decode_Preview_Truncated;
         Result.Decode_Complete := False;
         return Result;
      when others =>
         Release (Result);
         raise;
   end JPEG_Data_Preview_Text;

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

   procedure Decode_Zlib_Data
     (Compressed      : Terminal.Common.Bytes.Byte_Array;
      Length          : Natural;
      Maximum_Length  : Natural;
      Exact_Length    : Boolean;
      Inflated        : out Terminal.App.Render_Model.Image_Data_Access;
      Inflated_Length : out Natural;
      Status          : out Data_Decode_Status)
   is
      Decoder : Terminal.App.Zlib_Inflation.Decoder;
      Continue : Boolean := True;
   begin
      Inflated := null;
      Inflated_Length := 0;
      Status := Decode_Invalid_Byte;
      if Length = 0
        or else Length > Compressed'Length
      then
         return;
      end if;
      Terminal.App.Zlib_Inflation.Start
        (Decoder, Maximum_Length, Exact_Length, Status);
      if Status /= Decode_Ok then
         return;
      end if;
      for I in 0 .. Length - 1 loop
         Terminal.App.Zlib_Inflation.Push
           (Decoder, Compressed (Compressed'First + I), Continue);
         exit when not Continue;
      end loop;
      Terminal.App.Zlib_Inflation.Finish
        (Decoder, Inflated, Inflated_Length, Status);
   end Decode_Zlib_Data;

   procedure Decode_Base64_Zlib_Chunks
     (Chunk_Count     : Natural;
      Chunk_Text      : not null access function
        (Index : Positive) return String;
      Maximum_Length  : Natural;
      Exact_Length    : Boolean;
      Inflated        : out Terminal.App.Render_Model.Image_Data_Access;
      Inflated_Length : out Natural;
      Encoded_Length  : out Natural;
      Status          : out Data_Decode_Status)
   is
      Base64_Result : Graphics_Data_Preview;
      Decoder       : Terminal.App.Zlib_Inflation.Decoder;

      procedure Accept_Compressed_Byte
        (Value    : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean)
      is
      begin
         Terminal.App.Zlib_Inflation.Push (Decoder, Value, Continue);
      end Accept_Compressed_Byte;
   begin
      Inflated := null;
      Inflated_Length := 0;
      Encoded_Length := 0;
      Status := Decode_Invalid_Byte;
      Terminal.App.Zlib_Inflation.Start
        (Decoder, Maximum_Length, Exact_Length, Status);
      if Status /= Decode_Ok then
         return;
      end if;

      Decode_Base64_Chunk_Bytes
        (Chunk_Count,
         Chunk_Text,
         Accept_Compressed_Byte'Access,
         Base64_Result);
      Encoded_Length := Base64_Result.Encoded_Length;
      if Base64_Result.Decode_Status /= Decode_Ok
        or else not Base64_Result.Decode_Complete
      then
         declare
            Discarded : Terminal.App.Render_Model.Image_Data_Access := null;
            Discarded_Length : Natural;
            Inflate_Status : Data_Decode_Status;
         begin
            Terminal.App.Zlib_Inflation.Finish
              (Decoder, Discarded, Discarded_Length, Inflate_Status);
            Free_Image_Data (Discarded);
            Status :=
              (if Inflate_Status in Decode_Too_Large
                   | Decode_Allocation_Failed
                   | Decode_Preview_Truncated
               then Inflate_Status
               elsif Base64_Result.Decode_Status in
                 Decode_Ok | Decode_Not_Attempted
               then Decode_Invalid_Byte
               else Base64_Result.Decode_Status);
         end;
         Release (Base64_Result);
         return;
      end if;

      Terminal.App.Zlib_Inflation.Finish
        (Decoder, Inflated, Inflated_Length, Status);
      Release (Base64_Result);
   exception
      when others =>
         Release (Base64_Result);
         raise;
   end Decode_Base64_Zlib_Chunks;

   procedure Decode_Base64_Zlib_Raw_Chunk_Rows
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
      Row_Stride : constant Natural := Raw_Row_Stride (Raw_Format, Pixel_Width);
      Expected   : constant Natural :=
        Raw_Decoded_Length (Raw_Format, Pixel_Width, Pixel_Height);
      Data       : Terminal.App.Render_Model.Image_Data_Access := null;
      Actual     : Natural := 0;
      Encoded    : Natural := 0;
      Status     : Data_Decode_Status := Decode_Not_Attempted;
   begin
      Release (Result);
      Result.Header_Recognized := True;
      Result.Raw_Format := Raw_Format;
      Result.Pixel_Width := Pixel_Width;
      Result.Pixel_Height := Pixel_Height;
      Result.Decoded_Row_Stride_Bytes := Row_Stride;
      if Row_Stride = 0 or else Expected = 0 then
         Result.Decode_Status := Decode_Unsupported_Format;
         return;
      end if;

      Decode_Base64_Zlib_Chunks
        (Chunk_Count,
         Chunk_Text,
         Expected,
         True,
         Data,
         Actual,
         Encoded,
         Status);
      Result.Encoded_Length := Encoded;
      Result.Has_Data := Encoded > 0;
      Result.Decode_Status := Status;
      if Status /= Decode_Ok or else Data = null then
         return;
      end if;

      for Y in 0 .. Pixel_Height - 1 loop
         declare
            First : constant Positive := Y * Row_Stride + 1;
            Last  : constant Positive := First + Row_Stride - 1;
            Continue : Boolean := True;
         begin
            Row_Sink (Y, Data (First .. Last), Continue);
            if not Continue then
               Result.Decode_Status := Decode_Invalid_Byte;
               Free_Image_Data (Data);
               return;
            end if;
         end;
      end loop;
      Result.Decoded_Length := Actual;
      Result.Decode_Complete := True;
      Free_Image_Data (Data);
   end Decode_Base64_Zlib_Raw_Chunk_Rows;

   procedure Decode_Base64_Zlib_PNG_Chunk_Rows
     (Chunk_Count    : Natural;
      Chunk_Text     : not null access function (Index : Positive) return String;
      Inflated_Length : Natural;
      Encoded_Length : out Natural;
      Row_Sink       : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result         : in out Graphics_Data_Preview)
   is
      PNG    : Terminal.App.Render_Model.Image_Data_Access := null;
      Actual : Natural := 0;
      Status : Data_Decode_Status := Decode_Not_Attempted;
   begin
      Release (Result);
      Decode_Base64_Zlib_Chunks
        (Chunk_Count,
         Chunk_Text,
         (if Inflated_Length = 0
          then Max_Data_Preview_Length
          else Inflated_Length),
         Inflated_Length /= 0,
         PNG,
         Actual,
         Encoded_Length,
         Status);
      Result.Header_Recognized := True;
      Result.Has_Data := Encoded_Length > 0;
      Result.Encoded_Length := Encoded_Length;
      Result.Decode_Status := Status;
      if Status /= Decode_Ok or else PNG = null then
         return;
      end if;

      Decode_PNG_RGBA_Rows (PNG.all, Actual, Row_Sink, Result);
      Result.Encoded_Length := Encoded_Length;
      Result.Has_Data := Encoded_Length > 0;
      Free_Image_Data (PNG);
   exception
      when Storage_Error =>
         if PNG /= null then
            Free_Image_Data (PNG);
         end if;
         Result.Decode_Status := Decode_Allocation_Failed;
         Result.Decode_Complete := False;
      when others =>
         if PNG /= null then
            Free_Image_Data (PNG);
         end if;
         raise;
   end Decode_Base64_Zlib_PNG_Chunk_Rows;

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
         Row : Image_Data_Holder;
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
            Row.Data (Row_Length) :=
              Terminal.Common.Bytes.Byte (Value mod 256);
            Result.Decoded_Length := Result.Decoded_Length + 1;

            if Row_Length = Row_Stride then
               Row_Sink (Y, Row.Data.all, Continue);
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
         Row.Data := new Terminal.Common.Bytes.Byte_Array (1 .. Row_Stride);
         Row.Data.all := (others => 0);
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
      exception
         when Storage_Error =>
            Result.Decode_Status := Decode_Allocation_Failed;
            Result.Decode_Complete := False;
            return;
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
      is (Terminal.App.Image_Decode.Suffix (Status));

   function Image_Decode_Status
     (Status : Data_Decode_Status)
      return Terminal.App.Render_Model.Image_Decode_Status
      is (Status);

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
         Color_Glyph_Rendered => True);
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
            return "kitty graphics; RGB/RGBA/indexed/PNG texture rendering";
         when ITerm2 =>
            return "iTerm2 images; PNG/JPEG/GIF/PICT texture rendering";
      end case;
   end Capability_Status_Label;

   function Valid_Integer_Text (Text : String) return Boolean is
      First : Natural := Text'First;
      Value : Long_Long_Integer := 0;
      Limit : Long_Long_Integer := Long_Long_Integer (Integer'Last);
   begin
      if Text'Length = 0 then
         return False;
      end if;
      if Text (First) = '-' then
         First := First + 1;
         Limit := -Long_Long_Integer (Integer'First);
      elsif Text (First) = '+' then
         First := First + 1;
      end if;
      if First > Text'Last then
         return False;
      end if;
      for I in First .. Text'Last loop
         if Text (I) not in '0' .. '9' then
            return False;
         end if;
         declare
            Digit : constant Long_Long_Integer :=
              Long_Long_Integer
                (Character'Pos (Text (I)) - Character'Pos ('0'));
         begin
            if Value > (Limit - Digit) / 10 then
               return False;
            end if;
            Value := Value * 10 + Digit;
         end;
      end loop;
      return True;
   end Valid_Integer_Text;

   function Valid_Graphics_ID_Text (Text : String) return Boolean is
      Value : Long_Long_Integer := 0;
      Limit : constant Long_Long_Integer :=
        Long_Long_Integer (Terminal.Core.Graphics_ID'Last);
   begin
      if Text'Length = 0 then
         return False;
      end if;
      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return False;
         end if;
         declare
            Digit : constant Long_Long_Integer :=
              Long_Long_Integer
                (Character'Pos (Ch) - Character'Pos ('0'));
         begin
            if Value > (Limit - Digit) / 10 then
               return False;
            end if;
            Value := Value * 10 + Digit;
         end;
      end loop;
      return True;
   end Valid_Graphics_ID_Text;

   function Valid_Kitty_Control_Data (Params : String) return Boolean is
      Seen : array (Character) of Boolean := (others => False);
      First : Natural := Params'First;

      function Valid_Field (From, To_Index : Natural) return Boolean is
         Eq : Natural := 0;
      begin
         if From > To_Index then
            return False;
         end if;
         for I in From .. To_Index loop
            if Params (I) = '=' then
               if Eq /= 0 then
                  return False;
               end if;
               Eq := I;
            end if;
         end loop;
         if Eq /= From + 1 or else Eq = To_Index then
            return False;
         end if;
         declare
            Key : constant Character := Params (From);
            Value : constant String := Params (Eq + 1 .. To_Index);
            Numeric : constant Boolean := Valid_Natural_Text (Value);
         begin
            if Seen (Key) then
               return False;
            end if;
            Seen (Key) := True;
            case Key is
               when 'a' =>
                  return Value'Length = 1
                    and then Value (Value'First) in
                      'a' | 'c' | 'd' | 'f' | 'p' | 'q' | 't' | 'T';
               when 't' =>
                  return Value'Length = 1
                    and then Value (Value'First) in 'd' | 'f' | 't' | 's';
               when 'o' =>
                  return Value = "z";
               when 'd' =>
                  return Value'Length = 1
                    and then Value (Value'First) in
                      'a' | 'A' | 'c' | 'C' | 'n' | 'N' | 'i' | 'I'
                      | 'p' | 'P' | 'q' | 'Q' | 'r' | 'R' | 'x' | 'X'
                      | 'y' | 'Y' | 'z' | 'Z' | 'f' | 'F';
               when 'i' | 'I' | 'p' | 'P' | 'Q' | 'Y' =>
                  return Valid_Graphics_ID_Text (Value);
               when 'z' | 'H' | 'V' =>
                  return Valid_Integer_Text (Value);
               when 'q' =>
                  return Numeric and then Parse_Natural (Value) <= 2;
               when 'f' =>
                  return Numeric
                    and then Parse_Natural (Value) in 8 | 16 | 24 | 32 | 100;
               when 'm' =>
                  return Value = "0" or else Value = "1";
               when 'x' | 'y' =>
                  return Valid_Graphics_ID_Text (Value);
               when 's' | 'v' | 'S' | 'O' | 'N' | 'w'
                  | 'h' | 'X' | 'c' | 'r' | 'C' | 'U' =>
                  return Numeric;
               when others =>
                  --  Preserve forward compatibility for unknown one-byte
                  --  controls while still requiring unambiguous key=value
                  --  syntax and rejecting duplicates.
                  return True;
            end case;
         end;
      end Valid_Field;
   begin
      if Params'Length = 0 then
         return True;
      end if;
      for I in Params'Range loop
         if Params (I) = ',' then
            if I = First or else not Valid_Field (First, I - 1) then
               return False;
            end if;
            First := I + 1;
         end if;
      end loop;
      return Valid_Field (First, Params'Last);
   end Valid_Kitty_Control_Data;

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
                  Result.Sixel_Transparent := Info.Transparent;
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
                     Result.Kitty_Control_Data_Valid :=
                       Valid_Kitty_Control_Data (Params);
                     Result.Kitty_Action :=
                       (if Action'Length > 0 then Action (Action'First)
                        else 't');
                     declare
                        Transmission : constant String :=
                          Field_Value (Params, "t");
                        Compression : constant String :=
                          Field_Value (Params, "o");
                        Delete_Selector : constant String :=
                          Field_Value (Params, "d");
                     begin
                        Result.Kitty_Transmission :=
                          (if Transmission'Length > 0
                           then Transmission (Transmission'First)
                           else ASCII.NUL);
                        Result.Kitty_Transmission_Specified :=
                          Transmission'Length > 0;
                        Result.Kitty_Transmission_Valid :=
                          Transmission'Length = 0
                          or else
                            (Transmission'Length = 1
                             and then Transmission (Transmission'First)
                               in 'd' | 'f' | 't' | 's');
                        Result.Kitty_Compression :=
                          (if Compression'Length > 0
                           then Compression (Compression'First)
                           else ASCII.NUL);
                        Result.Kitty_Compression_Specified :=
                          Compression'Length > 0;
                        Result.Kitty_Compression_Valid :=
                          Compression'Length = 0 or else Compression = "z";
                        Result.Kitty_Delete :=
                          (if Delete_Selector'Length > 0
                           then Delete_Selector (Delete_Selector'First)
                           else ASCII.NUL);
                     end;
                     Result.Kitty_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "i"));
                     Result.Kitty_Image_Number :=
                       Parse_Graphics_ID (Field_Value (Params, "I"));
                     Result.Kitty_Placement_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "p"));
                     Result.Kitty_Quiet :=
                       Parse_Natural (Field_Value (Params, "q"));
                     Result.Kitty_Usage_Hint :=
                       Parse_Natural (Field_Value (Params, "N"));
                     declare
                        Format_Text : constant String :=
                          Field_Value (Params, "f");
                     begin
                        Result.Kitty_Format :=
                          (if Format_Text'Length = 0
                           then 32
                           else Parse_Natural (Format_Text));
                     end;
                     declare
                        More : constant String := Field_Value (Params, "m");
                     begin
                        Result.Kitty_More_Specified := More'Length > 0;
                        Result.Kitty_More_Valid :=
                          More'Length = 0 or else More = "0" or else More = "1";
                        Result.Kitty_More := More = "1";
                     end;
                     Result.Raw_Format := Result.Kitty_Format;
                     Result.Pixel_Width :=
                       Parse_Natural (Field_Value (Params, "s"));
                     Result.Pixel_Height :=
                       Parse_Natural (Field_Value (Params, "v"));
                     declare
                        Size_Text : constant String := Field_Value (Params, "S");
                        Offset_Text : constant String := Field_Value (Params, "O");
                     begin
                        Result.Kitty_Data_Size_Specified := Size_Text'Length > 0;
                        Result.Kitty_Data_Size_Valid :=
                          Size_Text'Length = 0 or else Valid_Natural_Text (Size_Text);
                        Result.Kitty_Data_Size := Parse_Natural (Size_Text);
                        Result.Kitty_Data_Offset_Specified := Offset_Text'Length > 0;
                        Result.Kitty_Data_Offset_Valid :=
                          Offset_Text'Length = 0
                          or else Valid_Natural_Text (Offset_Text);
                        Result.Kitty_Data_Offset := Parse_Natural (Offset_Text);
                     end;
                     Result.Kitty_Source_X :=
                       Parse_Natural (Field_Value (Params, "x"));
                     Result.Kitty_Source_Y :=
                       Parse_Natural (Field_Value (Params, "y"));
                     Result.Kitty_Delete_Range_First :=
                       Parse_Graphics_ID (Field_Value (Params, "x"));
                     Result.Kitty_Delete_Range_Last :=
                       Parse_Graphics_ID (Field_Value (Params, "y"));
                     Result.Kitty_Source_Width :=
                       Parse_Natural (Field_Value (Params, "w"));
                     Result.Kitty_Source_Height :=
                       Parse_Natural (Field_Value (Params, "h"));
                     Result.Kitty_Cell_X :=
                       Parse_Natural (Field_Value (Params, "X"));
                     Result.Kitty_Cell_Y :=
                       Parse_Natural (Field_Value (Params, "Y"));
                     declare
                        X_Source : constant String := Field_Value (Params, "x");
                        Y_Source : constant String := Field_Value (Params, "y");
                        Width    : constant String := Field_Value (Params, "w");
                        Height   : constant String := Field_Value (Params, "h");
                        X_Cell   : constant String := Field_Value (Params, "X");
                        Y_Cell   : constant String := Field_Value (Params, "Y");
                     begin
                        Result.Kitty_Geometry_Controls_Valid :=
                          (X_Source'Length = 0
                           or else Valid_Natural_Text (X_Source))
                          and then
                            (Y_Source'Length = 0
                             or else Valid_Natural_Text (Y_Source))
                          and then
                            (Width'Length = 0
                             or else Valid_Natural_Text (Width))
                          and then
                            (Height'Length = 0
                             or else Valid_Natural_Text (Height))
                          and then
                            (X_Cell'Length = 0
                             or else Valid_Natural_Text (X_Cell))
                          and then
                            (Y_Cell'Length = 0
                             or else Valid_Natural_Text (Y_Cell));
                     end;
                     Result.Kitty_Z_Index :=
                       Parse_Integer (Field_Value (Params, "z"));
                     Result.Kitty_No_Cursor_Move :=
                       Field_Value (Params, "C") = "1";
                     Result.Kitty_Virtual_Placement :=
                       Field_Value (Params, "U") = "1";
                     Result.Kitty_Parent_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "P"));
                     Result.Kitty_Parent_Placement_ID :=
                       Parse_Graphics_ID (Field_Value (Params, "Q"));
                     Result.Kitty_Parent_Offset_X :=
                       Parse_Integer (Field_Value (Params, "H"));
                     Result.Kitty_Parent_Offset_Y :=
                       Parse_Integer (Field_Value (Params, "V"));
                     if Result.Kitty_Action = 'f' then
                        Result.Kitty_Frame_Number :=
                          Parse_Natural (Field_Value (Params, "r"));
                        Result.Kitty_Base_Frame :=
                          Parse_Natural (Field_Value (Params, "c"));
                        Result.Kitty_Frame_Gap :=
                          Parse_Integer (Field_Value (Params, "z"));
                        Result.Kitty_Composition_Mode :=
                          Parse_Natural (Field_Value (Params, "X"));
                        Result.Kitty_Background_Color :=
                          Parse_Graphics_ID (Field_Value (Params, "Y"));
                     elsif Result.Kitty_Action = 'a' then
                        Result.Kitty_Animation_State := Result.Pixel_Width;
                        Result.Kitty_Frame_Number :=
                          Parse_Natural (Field_Value (Params, "r"));
                        Result.Kitty_Base_Frame :=
                          Parse_Natural (Field_Value (Params, "c"));
                        Result.Kitty_Frame_Gap :=
                          Parse_Integer (Field_Value (Params, "z"));
                        Result.Kitty_Loop_Count := Result.Pixel_Height;
                     elsif Result.Kitty_Action = 'c' then
                        Result.Kitty_Frame_Number :=
                          Parse_Natural (Field_Value (Params, "c"));
                        Result.Kitty_Base_Frame :=
                          Parse_Natural (Field_Value (Params, "r"));
                        Result.Kitty_Composition_Mode :=
                          Parse_Natural (Field_Value (Params, "C"));
                     end if;
                     declare
                        Columns : constant String := Field_Value (Params, "c");
                        Rows    : constant String := Field_Value (Params, "r");
                        Column_Value : constant Natural := Parse_Natural (Columns);
                        Row_Value    : constant Natural := Parse_Natural (Rows);
                     begin
                        Result.Kitty_Columns_Specified := Columns'Length > 0;
                        Result.Kitty_Rows_Specified := Rows'Length > 0;
                        Result.Kitty_Columns_Valid :=
                          Columns'Length = 0 or else Column_Value > 0;
                        Result.Kitty_Rows_Valid :=
                          Rows'Length = 0 or else Row_Value > 0;
                        if Result.Kitty_Columns_Specified
                          and then Result.Kitty_Columns_Valid
                        then
                           Result.Placeholder_Cols := Positive (Column_Value);
                        else
                           Result.Placeholder_Cols := 6;
                        end if;
                        if Result.Kitty_Rows_Specified
                          and then Result.Kitty_Rows_Valid
                        then
                           Result.Placeholder_Rows := Positive (Row_Value);
                        else
                           Result.Placeholder_Rows := 3;
                        end if;
                     end;
                     declare
                        C_Text : constant String := Field_Value (Params, "C");
                        U_Text : constant String := Field_Value (Params, "U");
                        X_Text : constant String := Field_Value (Params, "X");
                        State_Text : constant String := Field_Value (Params, "s");
                        Frame_C_Text : constant String := Field_Value (Params, "c");
                        Frame_R_Text : constant String := Field_Value (Params, "r");
                        Delete_X_Text : constant String := Field_Value (Params, "x");
                        Delete_Y_Text : constant String := Field_Value (Params, "y");
                        Has_Identity : constant Boolean :=
                          (Result.Kitty_ID /= 0)
                          xor (Result.Kitty_Image_Number /= 0);
                     begin
                        Result.Kitty_Delete_Controls_Valid :=
                          (case Result.Kitty_Delete is
                             when ASCII.NUL | 'a' | 'A' | 'c' | 'C'
                                | 'z' | 'Z' => True,
                             when 'i' | 'I' =>
                                Result.Kitty_ID /= 0
                                and then Result.Kitty_Image_Number = 0,
                             when 'n' | 'N' =>
                                Result.Kitty_Image_Number /= 0
                                and then Result.Kitty_ID = 0,
                             when 'f' | 'F' => Has_Identity,
                             when 'p' | 'P' | 'q' | 'Q' =>
                                Valid_Natural_Text (Delete_X_Text)
                                and then Valid_Natural_Text (Delete_Y_Text)
                                and then Parse_Natural (Delete_X_Text) > 0
                                and then Parse_Natural (Delete_Y_Text) > 0,
                             when 'x' | 'X' =>
                                Valid_Natural_Text (Delete_X_Text)
                                and then Parse_Natural (Delete_X_Text) > 0,
                             when 'y' | 'Y' =>
                                Valid_Natural_Text (Delete_Y_Text)
                                and then Parse_Natural (Delete_Y_Text) > 0,
                             when 'r' | 'R' =>
                                Delete_X_Text'Length > 0
                                and then Delete_Y_Text'Length > 0
                                and then Valid_Graphics_ID_Text (Delete_X_Text)
                                and then Valid_Graphics_ID_Text (Delete_Y_Text)
                                and then Result.Kitty_Delete_Range_Last >=
                                  Result.Kitty_Delete_Range_First,
                             when others => False);
                        Result.Kitty_Action_Controls_Valid :=
                          Result.Kitty_Control_Data_Valid
                          and then not
                            (Result.Kitty_ID /= 0
                             and then Result.Kitty_Image_Number /= 0)
                          and then
                            (case Result.Kitty_Action is
                               when 't' | 'T' => Result.Has_Data,
                               when 'q' =>
                                  Result.Has_Data
                                  and then Result.Kitty_ID /= 0
                                  and then Result.Kitty_Image_Number = 0,
                               when 'p' =>
                                  not Result.Has_Data and then Has_Identity,
                               when 'd' =>
                                  not Result.Has_Data
                                  and then Result.Kitty_Delete_Controls_Valid,
                               when 'f' =>
                                  Result.Has_Data
                                  and then Has_Identity
                                  and then
                                    (X_Text'Length = 0
                                     or else X_Text = "0"
                                     or else X_Text = "1"),
                               when 'a' =>
                                  not Result.Has_Data
                                  and then Has_Identity
                                  and then
                                    (State_Text'Length = 0
                                     or else State_Text = "1"
                                     or else State_Text = "2"
                                     or else State_Text = "3"),
                               when 'c' =>
                                  not Result.Has_Data
                                  and then Has_Identity
                                  and then Parse_Natural (Frame_C_Text) > 0
                                  and then Parse_Natural (Frame_R_Text) > 0
                                  and then
                                    (C_Text'Length = 0
                                     or else C_Text = "0"
                                     or else C_Text = "1"),
                               when others => False)
                          and then
                            (if Result.Kitty_Action in 'T' | 'p'
                             then
                               (C_Text'Length = 0
                                or else C_Text = "0"
                                or else C_Text = "1")
                               and then
                                 (U_Text'Length = 0
                                  or else U_Text = "0"
                                  or else U_Text = "1")
                             else True);
                     end;
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
                     Width  : constant String := Field_Value (Params, "width");
                     Height : constant String := Field_Value (Params, "height");
                     Preserve : constant String :=
                       Field_Value (Params, "preserveAspectRatio");
                     Do_Not_Move : constant String :=
                       Field_Value (Params, "doNotMoveCursor");
                     Size_Text : constant String := Field_Value (Params, "size");

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
                           Numeric_Text : constant String :=
                             Value (Value'First .. Digits_Last);
                        begin
                           Valid := Valid_Natural_Text (Numeric_Text);
                           Number := Parse_Natural (Numeric_Text);
                           Valid := Valid and then Number > 0;
                        end;
                     end Parse_Size;
                  begin
                     Result.ITerm2_Inline := Inline = "1";
                     Result.ITerm2_Declared_Size_Valid :=
                       Size_Text'Length = 0
                       or else Valid_Natural_Text (Size_Text);
                     Result.ITerm2_Control_Data_Valid :=
                       (Inline'Length = 0 or else Inline in "0" | "1")
                       and then
                         (Preserve'Length = 0
                          or else Preserve in "0" | "1")
                       and then
                         (Do_Not_Move'Length = 0
                          or else Do_Not_Move in "0" | "1")
                       and then Result.ITerm2_Declared_Size_Valid;
                     Result.ITerm2_Name_Length := Name'Length;
                     Result.ITerm2_Declared_Size :=
                       Parse_Natural (Size_Text);
                     Result.ITerm2_Preserve_Aspect_Ratio := Preserve /= "0";
                     Result.ITerm2_Do_Not_Move_Cursor := Do_Not_Move = "1";
                     Parse_Size
                       (Width,
                        Result.ITerm2_Width_Specified,
                        Result.ITerm2_Width_Valid,
                        Result.ITerm2_Width_Value,
                        Result.ITerm2_Width_Unit);
                     Parse_Size
                       (Height,
                        Result.ITerm2_Height_Specified,
                        Result.ITerm2_Height_Valid,
                        Result.ITerm2_Height_Value,
                        Result.ITerm2_Height_Unit);
                     if Result.ITerm2_Width_Unit = ITerm2_Cells
                       and then Result.ITerm2_Width_Valid
                     then
                        Result.Placeholder_Cols := Clamp_Positive
                          (Result.ITerm2_Width_Value, 6, 80);
                     end if;
                     if Result.ITerm2_Height_Unit = ITerm2_Cells
                       and then Result.ITerm2_Height_Valid
                     then
                        Result.Placeholder_Rows := Clamp_Positive
                          (Result.ITerm2_Height_Value, 3, 40);
                     end if;
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
               if H.Kitty_Compression /= ASCII.NUL then
                  --  The renderer uses the bounded streaming zlib row paths.
                  --  Do not interpret compressed bytes as raw preview pixels.
                  Result.Decode_Status :=
                    (if H.Kitty_Compression = 'z'
                     then Decode_Not_Attempted
                     else Decode_Unsupported_Format);
                  Result.Decode_Complete := False;
                  return Result;
               elsif Has_Raw_Metadata and then Expected_Decoded_Length = 0 then
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
                  --  Kitty f=100 is specifically PNG.  JPEG remains valid
                  --  for the iTerm2 File protocol, but accepting it here
                  --  would advertise a non-standard Kitty extension.
                  Decode_PNG_RGBA_Data (PNG.all, PNG_Length, Result);
                  Free_Image_Data (PNG);
               end;
            end if;
            if H.Kitty_Format in Kitty_JPEG_Format | Kitty_GIF_Format
              and then Result.Decode_Complete
              and then Result.Bytes /= null
            then
               declare
                  Encoded : Terminal.App.Render_Model.Image_Data_Access := Result.Bytes;
                  Length  : constant Natural := Result.Decoded_Length;

                  function Byte (Index : Positive) return Natural is
                    (if Index <= Length then Natural (Encoded (Encoded'First + Index - 1)) else 256);

                  --  The payload must be what its format code says: a JPEG
                  --  starts FF D8 FF, a GIF with GIF8.
                  Matches : constant Boolean :=
                    (if H.Kitty_Format = Kitty_JPEG_Format
                     then Byte (1) = 16#FF# and then Byte (2) = 16#D8# and then Byte (3) = 16#FF#
                     else Byte (1) = Character'Pos ('G') and then Byte (2) = Character'Pos ('I')
                       and then Byte (3) = Character'Pos ('F') and then Byte (4) = Character'Pos ('8'));
               begin
                  Result.Bytes := null;
                  Result.Decoded_Length := 0;
                  Result.Decoded_Row_Stride_Bytes := 0;
                  Result.Raw_Format := 0;
                  Result.Pixel_Width := 0;
                  Result.Pixel_Height := 0;

                  if Matches then
                     Decode_Image_RGBA_Data (Encoded.all, Length, Result);
                  else
                     Result.Decode_Status := Decode_Unsupported_Format;
                     Result.Decode_Complete := False;
                  end if;

                  Free_Image_Data (Encoded);
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
                  Decode_Image_RGBA_Data (PNG.all, PNG_Length, Result);
                  Free_Image_Data (PNG);
               end;
            end if;
         when Terminal.Core.Sixel_Graphics =>
            Decode_Sixel_Raster
              (Text,
               (Width       => H.Pixel_Width,
                Height      => H.Pixel_Height,
                Logical_Height => H.Pixel_Height,
                Vertical_Aspect => 1,
                Transparent => H.Sixel_Transparent),
               Result);
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
