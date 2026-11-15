with Terminal.Common.Base64;

package body Terminal.App.Graphics.Base64_Sizing is
   function Decoded_Length
     (Text : String; Length : out Natural) return Boolean
   is
      Encoded_Count : Natural := 0;
      Padding       : Natural := 0;
      Remainder     : Natural;
   begin
      Length := 0;
      for Ch of Text loop
         if not Terminal.Common.Base64.Is_Whitespace (Ch) then
            Encoded_Count := Encoded_Count + 1;
            if Ch = '=' then
               Padding := Padding + 1;
            end if;
         end if;
      end loop;
      Remainder := Encoded_Count mod 4;
      if Encoded_Count = 0
        or else Padding > 2
        or else Remainder = 1
        or else (Padding > 0 and then Remainder /= 0)
      then
         return False;
      end if;
      Length := (Encoded_Count / 4) * 3;
      if Padding > 0 then
         if Padding > Length then
            Length := 0;
            return False;
         end if;
         Length := Length - Padding;
      elsif Remainder = 2 then
         Length := Length + 1;
      elsif Remainder = 3 then
         Length := Length + 2;
      end if;
      return Length > 0;
   end Decoded_Length;
end Terminal.App.Graphics.Base64_Sizing;
