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
      Remaining : Duration := Elapsed;
      Result    : Natural := 0;
   begin
      while Remaining >= Blink_Period loop
         Result := Result + 1;
         Remaining := Remaining - Blink_Period;
      end loop;

      return Result;
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
