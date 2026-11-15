package body Terminal.App.Number_Parsing is
   function Try_Unsigned
     (Text  : String;
      Limit : Long_Long_Integer;
      Value : out Long_Long_Integer) return Boolean
   is
   begin
      Value := 0;
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
   end Try_Unsigned;

   function Try_Natural
     (Text  : String;
      Value : out Natural) return Boolean
   is
      Parsed : Long_Long_Integer;
      Valid : constant Boolean :=
        Try_Unsigned (Text, Long_Long_Integer (Natural'Last), Parsed);
   begin
      Value := (if Valid then Natural (Parsed) else 0);
      return Valid;
   end Try_Natural;

   function Try_Graphics_ID
     (Text  : String;
      Value : out Terminal.Core.Graphics_ID) return Boolean
   is
      Parsed : Long_Long_Integer;
      Valid : constant Boolean :=
        Try_Unsigned
          (Text,
           Long_Long_Integer (Terminal.Core.Graphics_ID'Last),
           Parsed);
   begin
      Value :=
        (if Valid then Terminal.Core.Graphics_ID (Parsed) else 0);
      return Valid;
   end Try_Graphics_ID;

   function Try_Integer
     (Text  : String;
      Value : out Integer) return Boolean
   is
      Negative : Boolean := False;
      First : Natural := Text'First;
      Parsed : Long_Long_Integer;
      Limit : Long_Long_Integer := Long_Long_Integer (Integer'Last);
      Valid : Boolean;
   begin
      Value := 0;
      if Text'Length = 0 then
         return False;
      end if;
      if Text (First) = '-' then
         Negative := True;
         First := First + 1;
         Limit := -Long_Long_Integer (Integer'First);
      elsif Text (First) = '+' then
         First := First + 1;
      end if;
      if First > Text'Last then
         return False;
      end if;
      Valid := Try_Unsigned (Text (First .. Text'Last), Limit, Parsed);
      if not Valid then
         return False;
      elsif Negative and then Parsed = Limit then
         Value := Integer'First;
      elsif Negative then
         Value := Integer (-Parsed);
      else
         Value := Integer (Parsed);
      end if;
      return True;
   end Try_Integer;
end Terminal.App.Number_Parsing;
