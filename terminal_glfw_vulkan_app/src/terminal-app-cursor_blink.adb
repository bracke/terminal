package body Terminal.App.Cursor_Blink is
   function Shape_Label (Shape : Terminal.Core.Cursor_Shape) return String is
   begin
      case Shape is
         when Terminal.Core.Cursor_Block =>
            return "block";
         when Terminal.Core.Cursor_Underline =>
            return "underline";
         when Terminal.Core.Cursor_Bar =>
            return "bar";
      end case;
   end Shape_Label;

   function Tick (Elapsed : Duration) return Natural is
      Ticks    : Long_Long_Integer;
      Quotient : Duration;
      Saturation_Elapsed : constant Duration :=
        Duration (Natural'Last) * Blink_Period;
   begin
      if Elapsed <= 0.0 then
         return 0;
      elsif Elapsed >= Saturation_Elapsed then
         return Natural'Last;
      end if;
      Quotient := Elapsed / Blink_Period;
      Ticks := Long_Long_Integer (Quotient);
      --  Fixed-point-to-integer conversion rounds to the nearest integer.
      --  Correct a rounded-up quotient to obtain floor without iterating.
      if Duration (Ticks) * Blink_Period > Elapsed then
         Ticks := Ticks - 1;
      end if;
      return Natural (Ticks);
   end Tick;

   function Status_Label
     (Cursor       : Terminal.Core.Cursor_State;
      Current_Tick : Natural) return String
   is
      Visible : constant Boolean :=
        Cursor.Visible
        and then (not Cursor.Blinking or else Current_Tick mod 2 = 0);
      Blink : constant String :=
        (if Cursor.Blinking then "blinking" else "steady");
      Phase : constant String :=
        (if Visible then "visible" else "hidden");
   begin
      return "Cursor: " & Shape_Label (Cursor.Shape) & ", " & Blink & ", " & Phase;
   end Status_Label;

   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural)
   is
   begin
      if Snapshot.Cursor.Blinking and then Current_Tick mod 2 = 1 then
         Snapshot.Cursor.Visible := False;
      end if;
   end Apply;
end Terminal.App.Cursor_Blink;
