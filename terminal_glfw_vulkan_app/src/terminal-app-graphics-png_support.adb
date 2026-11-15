package body Terminal.App.Graphics.PNG_Support is
   function U32_BE
     (Bytes : Terminal.Common.Bytes.Byte_Array;
      First : Positive) return Natural is
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

   function Bit_Depth_Allowed
     (Color_Type, Bit_Depth : Natural) return Boolean is
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
   end Bit_Depth_Allowed;

   function Bits_Per_Pixel
     (Color_Type, Bit_Depth : Natural) return Natural is
   begin
      case Color_Type is
         when 0 | 3 => return Bit_Depth;
         when 2     => return Bit_Depth * 3;
         when 4     => return Bit_Depth * 2;
         when others => return Bit_Depth * 4;
      end case;
   end Bits_Per_Pixel;

   function Filter_BPP
     (Color_Type, Bit_Depth : Natural) return Natural is
     (Natural'Max (1, (Bits_Per_Pixel (Color_Type, Bit_Depth) + 7) / 8));

   function Row_Bytes
     (Width, Color_Type, Bit_Depth : Natural) return Natural
   is
      Bits : constant Natural := Bits_Per_Pixel (Color_Type, Bit_Depth);
   begin
      if Bits = 0 or else Width > (Natural'Last - 7) / Bits then
         return 0;
      end if;
      return (Width * Bits + 7) / 8;
   end Row_Bytes;

   function Pass_Size
     (Full_Size, Start, Step : Natural) return Natural is
     (if Full_Size <= Start then 0
      else (Full_Size - Start + Step - 1) / Step);

   function Inflated_Length
     (Width, Height, Color_Type, Bit_Depth, Interlace : Natural)
      return Natural
   is
      function Pass_Bytes
        (X_Start, Y_Start, X_Step, Y_Step : Natural) return Natural
      is
         Pass_Width  : constant Natural :=
           Pass_Size (Width, X_Start, X_Step);
         Pass_Height : constant Natural :=
           Pass_Size (Height, Y_Start, Y_Step);
      begin
         if Pass_Width = 0 or else Pass_Height = 0 then
            return 0;
         end if;
         declare
            Row_Length : constant Natural :=
              Row_Bytes (Pass_Width, Color_Type, Bit_Depth);
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
              Row_Bytes (Width, Color_Type, Bit_Depth);
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
   end Inflated_Length;

   function Packed_Sample
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
   end Packed_Sample;

   function Sample_16
     (Row : Terminal.Common.Bytes.Byte_Array;
      First : Positive) return Natural is
     (Natural (Row (First)) * 256 + Natural (Row (First + 1)));

   function Scale_Sample
     (Value, Bit_Depth : Natural) return Natural
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
   end Scale_Sample;
end Terminal.App.Graphics.PNG_Support;
