with Terminal.Core;

package Terminal.App.Render_Policy is
   Max_Status_Label_Length : constant := 96;

   function Should_Defer_Render
     (Modes                : Terminal.Core.Mode_Snapshot;
      Scrollback_Offset    : Natural;
      Selection_Active     : Boolean;
      Local_Redraw_Request : Boolean) return Boolean;
   function Status_Label
     (Modes                : Terminal.Core.Mode_Snapshot;
      Scrollback_Offset    : Natural;
      Selection_Active     : Boolean;
      Local_Redraw_Request : Boolean) return String;
end Terminal.App.Render_Policy;
