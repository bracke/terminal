with Terminal.Core;

package Terminal.App.Scrollback_View is
   Max_Status_Label_Length : constant := 64;

   function Max_Offset (T : Terminal.Core.Terminal) return Natural;

   function Clamp_Offset
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Natural;

   function Snapshot
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Terminal.Core.Render_Snapshot;

   function Status_Label
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return String;
end Terminal.App.Scrollback_View;
