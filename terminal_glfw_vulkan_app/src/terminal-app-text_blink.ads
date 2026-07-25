with Terminal.Core;

package Terminal.App.Text_Blink is
   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural);
end Terminal.App.Text_Blink;
