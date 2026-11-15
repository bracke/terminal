with Terminal.App.Text_Blink;

package body Terminal.App.Blink_Activity is
   procedure Reset (State : out Activity) is
   begin
      State := (others => False);
   end Reset;

   procedure Include
     (State    : in out Activity;
      Snapshot : Terminal.Core.Render_Snapshot) is
   begin
      State.Text := State.Text or else
        Terminal.App.Text_Blink.Contains_Blinking_Text (Snapshot);
      State.Cursor := State.Cursor or else
        (Snapshot.Cursor.Visible and then Snapshot.Cursor.Blinking);
   end Include;

   function Active (State : Activity) return Boolean is
     (State.Text or else State.Cursor);

   function Requires_Redraw
     (State         : Activity;
      Previous_Tick : Natural;
      Current_Tick  : Natural) return Boolean is
     (Current_Tick /= Previous_Tick and then Active (State));
end Terminal.App.Blink_Activity;
