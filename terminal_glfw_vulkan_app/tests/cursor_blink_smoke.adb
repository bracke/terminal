with AUnit.Assertions;

with Terminal.App.Cursor_Blink;
with Terminal.Core;

procedure Cursor_Blink_Smoke is
   use AUnit.Assertions;

   Snapshot : Terminal.Core.Render_Snapshot;
begin
   Assert
     (Terminal.App.Cursor_Blink.Tick (0.0) = 0,
      "initial blink tick");
   Assert
     (Terminal.App.Cursor_Blink.Tick (0.499) = 0,
      "first half-second is visible phase");
   Assert
     (Terminal.App.Cursor_Blink.Tick (0.5) = 1,
      "half-second advances to hidden phase");
   Assert
     (Terminal.App.Cursor_Blink.Tick (1.0) = 2,
      "one second returns to visible phase");

   Snapshot.Cursor :=
     (Row      => 1,
      Col      => 1,
      Visible  => True,
      Shape    => Terminal.Core.Cursor_Block,
      Blinking => False);
   Terminal.App.Cursor_Blink.Apply (Snapshot, 1);
   Assert (Snapshot.Cursor.Visible, "steady cursor remains visible");

   Snapshot.Cursor.Blinking := True;
   Snapshot.Cursor.Visible := True;
   Terminal.App.Cursor_Blink.Apply (Snapshot, 0);
   Assert (Snapshot.Cursor.Visible, "blinking cursor visible on even ticks");

   Terminal.App.Cursor_Blink.Apply (Snapshot, 1);
   Assert (not Snapshot.Cursor.Visible, "blinking cursor hidden on odd ticks");

   Snapshot.Cursor.Visible := False;
   Terminal.App.Cursor_Blink.Apply (Snapshot, 2);
   Assert
     (not Snapshot.Cursor.Visible,
      "blink helper does not override core cursor visibility");
end Cursor_Blink_Smoke;
