package body Terminal.App.Graphics.Sixel_Support is
   function Byte_From_Percent
     (Value : Natural) return Terminal.Common.Bytes.Byte
   is
      Clamped : constant Natural := Natural'Min (Value, 100);
   begin
      return Terminal.Common.Bytes.Byte ((Clamped * 255 + 50) / 100);
   end Byte_From_Percent;

   function Sixel_HLS_Color
     (Hue, Lightness, Saturation : Natural) return Sixel_Color
   is
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

   procedure Skip_Sixel_Number (Text : String; Index : in out Natural) is
   begin
      while Index <= Text'Last and then Text (Index) in '0' .. '9' loop
         Index := Index + 1;
      end loop;
   end Skip_Sixel_Number;

   function Read_Sixel_Number
     (Text : String; Index : in out Natural) return Natural
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
end Terminal.App.Graphics.Sixel_Support;
