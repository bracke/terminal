with Terminal.Core;

package Terminal.App.Text_Blink is
   Max_Status_Label_Length : constant := 64;

   function Contains_Blinking_Text
     (Snapshot : Terminal.Core.Render_Snapshot) return Boolean;

   function Status_Label
     (Snapshot     : Terminal.Core.Render_Snapshot;
      Current_Tick : Natural) return String;

   procedure Apply
     (Snapshot     : in out Terminal.Core.Render_Snapshot;
      Current_Tick : Natural);
end Terminal.App.Text_Blink;
