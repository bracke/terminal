package body Terminal.App.Text_Blink is
   use type Terminal.Core.Cell_Array_Access;

   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural)
   is
   begin
      if Snapshot.Cells = null or else Current_Tick mod 2 = 0 then
         return;
      end if;

      for Index in Snapshot.Cells'Range loop
         if Snapshot.Cells (Index).Style.Blink then
            Snapshot.Cells (Index).Style.Conceal := True;
         end if;
      end loop;
   end Apply;
end Terminal.App.Text_Blink;
