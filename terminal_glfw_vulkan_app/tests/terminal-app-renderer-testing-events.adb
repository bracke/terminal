with AUnit.Assertions;
with Terminal.App.Renderer.Event_Tracking;
with Terminal.Core;

package body Terminal.App.Renderer.Testing.Events is
   procedure Verify_Event_Payload_Borrow_Guard is
      use AUnit.Assertions;
      R : Renderer;
      Event : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Payload_Length => 1,
         Preview_Length => 1,
         Preview        => (1 => 'x', others => ASCII.NUL),
         others         => <>);
      Rejected : Boolean := False;

      procedure Try_Clear (Text : String) is
      begin
         Assert (Text = "x", "borrowed event text is intact");
         begin
            Terminal.App.Renderer.Event_Tracking.Clear (R);
         exception
            when Program_Error =>
               Rejected := True;
         end;
      end Try_Clear;
   begin
      Terminal.App.Renderer.Event_Tracking.With_Complete_Event_Text
        (R, Event, Try_Clear'Access);
      Assert (Rejected, "event cleanup is rejected during payload callback");
      Assert
        (R.Graphics_State.Transaction.Staged_Payload_Borrows = 0,
         "event payload borrow is released after callback");
      Terminal.App.Renderer.Event_Tracking.Clear (R);
   end Verify_Event_Payload_Borrow_Guard;
end Terminal.App.Renderer.Testing.Events;
