with Terminal.Core;

package Terminal.App.Render_Policy is
   function Should_Defer_Render
     (Modes                : Terminal.Core.Mode_Snapshot;
      Scrollback_Offset    : Natural;
      Selection_Active     : Boolean;
      Local_Redraw_Request : Boolean) return Boolean;
end Terminal.App.Render_Policy;
