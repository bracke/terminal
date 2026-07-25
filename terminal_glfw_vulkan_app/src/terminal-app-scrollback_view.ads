with Terminal.Core;

package Terminal.App.Scrollback_View is
   function Max_Offset (T : Terminal.Core.Terminal) return Natural;

   function Clamp_Offset
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Natural;

   function Snapshot
     (T      : Terminal.Core.Terminal;
      Offset : Natural) return Terminal.Core.Render_Snapshot;
end Terminal.App.Scrollback_View;
