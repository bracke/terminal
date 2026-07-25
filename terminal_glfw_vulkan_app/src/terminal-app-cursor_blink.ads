with Terminal.Core;

package Terminal.App.Cursor_Blink is
   Blink_Period : constant Duration := 0.5;

   function Tick (Elapsed : Duration) return Natural;

   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural);
end Terminal.App.Cursor_Blink;
