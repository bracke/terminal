package body Terminal.App.Render_Policy is
   function Should_Defer_Render
     (Modes                : Terminal.Core.Mode_Snapshot;
      Scrollback_Offset    : Natural;
      Selection_Active     : Boolean;
      Local_Redraw_Request : Boolean) return Boolean
   is
   begin
      return Modes.Synchronized_Update
        and then Scrollback_Offset = 0
        and then not Selection_Active
        and then not Local_Redraw_Request;
   end Should_Defer_Render;
end Terminal.App.Render_Policy;
