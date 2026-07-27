package body Terminal.Common.Status is
   function Hex_Nibble (Value : Natural) return Character is
   begin
      if Value < 10 then
         return Character'Val (Character'Pos ('0') + Value);
      else
         return Character'Val (Character'Pos ('A') + Value - 10);
      end if;
   end Hex_Nibble;

   function Preview_Bytes_Label
     (Bytes  : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Limit  : Natural := 4) return String
   is
      Count  : constant Natural :=
        Natural'Min (Natural'Min (Length, Limit), Bytes'Length);
      Result : String (1 .. 7 + Count * 2);
      Pos    : Positive := Result'First;
   begin
      if Count = 0 then
         return "";
      end if;

      Result (1 .. 7) := " bytes=";
      Pos := 8;
      for I in Bytes'First .. Bytes'First + Count - 1 loop
         declare
            Value : constant Natural := Natural (Bytes (I));
         begin
            Result (Pos) := Hex_Nibble (Value / 16);
            Result (Pos + 1) := Hex_Nibble (Value mod 16);
            Pos := Pos + 2;
         end;
      end loop;
      return Result;
   end Preview_Bytes_Label;
end Terminal.Common.Status;
