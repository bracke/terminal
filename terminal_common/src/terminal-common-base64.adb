package body Terminal.Common.Base64 is
   use type Terminal.Common.Bytes.Byte;

   function Value (Ch : Character) return Integer is
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
   end Value;

   function Value (Ch : Terminal.Common.Bytes.Byte) return Integer is
   begin
      if Ch > Terminal.Common.Bytes.Byte (Character'Pos (Character'Last)) then
         return -1;
      end if;
      return Value (Character'Val (Ch));
   end Value;

   function Is_Whitespace (Ch : Character) return Boolean is
     (Ch in ' ' | ASCII.CR | ASCII.LF);

   function Is_Whitespace
     (Ch : Terminal.Common.Bytes.Byte) return Boolean
   is
     (Ch = Character'Pos (' ')
      or else Ch = Character'Pos (ASCII.CR)
      or else Ch = Character'Pos (ASCII.LF));

   function Is_Valid_Quantum
     (Values         : Quantum;
      Count          : Natural;
      Padding        : Natural;
      Allow_Unpadded : Boolean) return Boolean
   is
   begin
      if Count not in 2 .. 4 or else Padding > 2 then
         return False;
      elsif Padding > 0 and then Count /= 4 then
         return False;
      elsif Padding = 2 then
         return Values (2) mod 16 = 0;
      elsif Padding = 1 then
         return Values (3) mod 4 = 0;
      elsif Count = 2 then
         return Allow_Unpadded and then Values (2) mod 16 = 0;
      elsif Count = 3 then
         return Allow_Unpadded and then Values (3) mod 4 = 0;
      else
         return Count = 4;
      end if;
   end Is_Valid_Quantum;

   function Decoded_Length
     (Count   : Natural;
      Padding : Natural) return Natural
   is
   begin
      if Padding > Count or else Count < 2 then
         return 0;
      end if;
      return (Count * 6) / 8 - Padding;
   end Decoded_Length;

   function Decode_Byte
     (Values : Quantum;
      Index  : Positive) return Terminal.Common.Bytes.Byte
   is
   begin
      case Index is
         when 1 =>
            return Terminal.Common.Bytes.Byte
              (Values (1) * 4 + Values (2) / 16);
         when 2 =>
            return Terminal.Common.Bytes.Byte
              ((Values (2) mod 16) * 16 + Values (3) / 4);
         when 3 =>
            return Terminal.Common.Bytes.Byte
              ((Values (3) mod 4) * 64 + Values (4));
         when others =>
            raise Constraint_Error with "invalid Base64 byte index";
      end case;
   end Decode_Byte;
end Terminal.Common.Base64;
