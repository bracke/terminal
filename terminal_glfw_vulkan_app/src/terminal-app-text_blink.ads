with Terminal.Core;

package Terminal.App.Text_Blink is
   function Contains_Blinking_Text
     (Snapshot : Terminal.Core.Render_Snapshot) return Boolean;

   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural);
end Terminal.App.Text_Blink;
