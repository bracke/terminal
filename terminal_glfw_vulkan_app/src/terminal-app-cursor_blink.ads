with Terminal.Core;

package Terminal.App.Cursor_Blink is
   Blink_Period : constant Duration := 0.5;
   Max_Status_Label_Length : constant := 64;

   function Tick (Elapsed : Duration) return Natural;

   function Status_Label
     (Cursor       : Terminal.Core.Cursor_State;
      Current_Tick : Natural) return String;

   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural);
end Terminal.App.Cursor_Blink;
