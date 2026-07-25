package body Terminal.App.Cursor_Blink is
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
