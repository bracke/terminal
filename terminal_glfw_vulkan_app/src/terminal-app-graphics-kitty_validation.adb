with Terminal.App.Number_Parsing;
with Terminal.Core;

package body Terminal.App.Graphics.Kitty_Validation is
   use type Terminal.Core.Graphics_ID;

   function Parse_Natural (Text : String) return Natural is
      Result : Natural;
   begin
      return
        (if Terminal.App.Number_Parsing.Try_Natural (Text, Result)
         then Result else 0);
   end Parse_Natural;

   function Valid_Natural_Text (Text : String) return Boolean is
      Result : Natural;
   begin
      return Terminal.App.Number_Parsing.Try_Natural (Text, Result);
   end Valid_Natural_Text;

   function Parse_Integer (Text : String) return Integer is
      Result : Integer;
   begin
      return
        (if Terminal.App.Number_Parsing.Try_Integer (Text, Result)
         then Result else 0);
   end Parse_Integer;

   function Parse_Graphics_ID
     (Text : String) return Terminal.Core.Graphics_ID is
      Result : Terminal.Core.Graphics_ID;
   begin
      return
        (if Terminal.App.Number_Parsing.Try_Graphics_ID (Text, Result)
         then Result else 0);
   end Parse_Graphics_ID;

   function Valid_Graphics_ID_Text (Text : String) return Boolean is
      Result : Terminal.Core.Graphics_ID;
   begin
      return Terminal.App.Number_Parsing.Try_Graphics_ID (Text, Result);
   end Valid_Graphics_ID_Text;

   procedure Index_Fields
     (Params : String;
      Fields : out Control_Fields;
      Valid  : out Boolean)
   is
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
            Natural_Value : Natural := 0;
            Integer_Value : Integer := 0;
            ID_Value : Terminal.Core.Graphics_ID := 0;
            Numeric : constant Boolean :=
              Terminal.App.Number_Parsing.Try_Natural
                (Value, Natural_Value);
         begin
            if Fields (Key).Present then
               return False;
            end if;
            Fields (Key) :=
              (Present => True, First => Eq + 1, Last => To_Index);
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
               when 'i' | 'I' | 'p' | 'P' | 'Q' | 'Y' | 'x' | 'y' =>
                  return Terminal.App.Number_Parsing.Try_Graphics_ID
                    (Value, ID_Value);
               when 'z' | 'H' | 'V' =>
                  return Terminal.App.Number_Parsing.Try_Integer
                    (Value, Integer_Value);
               when 'q' =>
                  return Numeric and then Natural_Value <= 2;
               when 'f' =>
                  return Numeric
                    and then Natural_Value in
                      8 | 16 | 24 | 32 | 100
                        | Kitty_JPEG_Format | Kitty_GIF_Format;
               when 'm' =>
                  return Value = "0" or else Value = "1";
               when 's' | 'v' | 'S' | 'O' | 'N' | 'w'
                  | 'h' | 'X' | 'c' | 'r' | 'C' | 'U' =>
                  return Numeric;
               when others =>
                  --  Unknown one-byte controls remain forward compatible,
                  --  while the common syntax and duplicate checks still
                  --  apply.
                  return True;
            end case;
         end;
      end Valid_Field;
   begin
      Fields := (others => <>);
      Valid := True;
      if Params'Length = 0 then
         return;
      end if;
      for I in Params'Range loop
         if Params (I) = ',' then
            if I = First then
               Valid := False;
            elsif not Valid_Field (First, I - 1) then
               Valid := False;
            end if;
            First := I + 1;
         end if;
      end loop;
      if First > Params'Last then
         Valid := False;
      elsif not Valid_Field (First, Params'Last) then
         Valid := False;
      end if;
   end Index_Fields;

   function Value
     (Params : String;
      Fields : Control_Fields;
      Key    : Character) return String is
   begin
      if not Fields (Key).Present then
         return "";
      end if;
      return Params (Fields (Key).First .. Fields (Key).Last);
   end Value;

   procedure Populate_Base_Controls
     (Params : String;
      Fields : Control_Fields;
      Result : in out Graphics_Header) is separate;

   procedure Populate_Action_Controls
     (Params : String;
      Fields : Control_Fields;
      Result : in out Graphics_Header) is separate;

   procedure Validate_Action_Controls
     (Params : String;
      Fields : Control_Fields;
      Result : in out Graphics_Header) is separate;

   procedure Parse_Header
     (Params   : String;
      Has_Data : Boolean;
      Result   : out Graphics_Header)
   is separate;

end Terminal.App.Graphics.Kitty_Validation;
