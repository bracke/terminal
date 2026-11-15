with Terminal.Core;

package Terminal.App.Blink_Activity is
   type Activity is private;

   procedure Reset (State : out Activity);
   procedure Include
     (State    : in out Activity;
      Snapshot : Terminal.Core.Render_Snapshot);
   function Active (State : Activity) return Boolean;
   function Requires_Redraw
     (State         : Activity;
      Previous_Tick : Natural;
      Current_Tick  : Natural) return Boolean;

private
   type Activity is record
      Text   : Boolean := False;
      Cursor : Boolean := False;
   end record;
end Terminal.App.Blink_Activity;
