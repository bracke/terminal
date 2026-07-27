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

   function Status_Label
     (Modes                : Terminal.Core.Mode_Snapshot;
      Scrollback_Offset    : Natural;
      Selection_Active     : Boolean;
      Local_Redraw_Request : Boolean) return String is
   begin
      if Should_Defer_Render
        (Modes, Scrollback_Offset, Selection_Active, Local_Redraw_Request)
      then
         return "Synchronized update defers live rendering";
      elsif Modes.Synchronized_Update then
         return "Local redraw bypasses synchronized update deferral";
      else
         return "Live rendering active";
      end if;
   end Status_Label;
end Terminal.App.Render_Policy;
