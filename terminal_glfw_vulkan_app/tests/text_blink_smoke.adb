with Terminal.Core.Snapshot_Editing;
with AUnit.Assertions;

with Terminal.App.Blink_Activity;
with Terminal.App.Text_Blink;
with Terminal.Core;

procedure Text_Blink_Smoke is
   use AUnit.Assertions;
   use type Terminal.Core.Initialize_Status;

   Snapshot : Terminal.Core.Render_Snapshot;
   Core : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
begin
   Terminal.Core.Initialize (Core, 1, 2, 0, Init);
   Assert (Init = Terminal.Core.Ok, "core initialize");
   Terminal.Core.Snapshot (Core, Snapshot);
   declare
      First : Terminal.Core.Cell :=
        (Includes_Link => True, others => <>);
      Second : Terminal.Core.Cell :=
        (Includes_Link => True, others => <>);
   begin
      First.Kind := Terminal.Core.Character;
      First.Text.Code_Point := Character'Pos ('a');
      First.Style.Blink := True;
      Second.Kind := Terminal.Core.Character;
      Second.Text.Code_Point := Character'Pos ('b');
      Terminal.Core.Snapshot_Editing.Set_Cell (Snapshot, 1, First);
      Terminal.Core.Snapshot_Editing.Set_Cell (Snapshot, 2, Second);
   end;

   Assert
     (Terminal.App.Text_Blink.Contains_Blinking_Text (Snapshot),
      "snapshot reports blinking text");
   Assert
     (Terminal.App.Text_Blink.Status_Label (Snapshot, 0) =
      "Text blink visible",
      "visible text blink status label");
   Assert
     (Terminal.App.Text_Blink.Status_Label (Snapshot, 0)'Length <=
      Terminal.App.Text_Blink.Max_Status_Label_Length,
      "text blink status label should be bounded");

   Terminal.App.Text_Blink.Apply (Snapshot, 0);
   Assert
     (not Terminal.Core.Cell_At_Index (Snapshot, 1).Style.Conceal,
      "blinking text stays visible on even ticks");
   Assert
     (not Terminal.Core.Cell_At_Index (Snapshot, 2).Style.Conceal,
      "steady text remains visible on even ticks");

   Assert
     (Terminal.App.Text_Blink.Status_Label (Snapshot, 1) =
      "Text blink hidden",
      "hidden text blink status label");
   Terminal.App.Text_Blink.Apply (Snapshot, 1);
   Assert
     (Terminal.Core.Cell_At_Index (Snapshot, 1).Style.Conceal,
      "blinking text is hidden on odd ticks");
   Assert
     (not Terminal.Core.Cell_At_Index (Snapshot, 2).Style.Conceal,
      "steady text remains visible on odd ticks");

   declare
      First : Terminal.Core.Cell :=
        Terminal.Core.Cell_At_Index (Snapshot, 1);
   begin
      First.Style.Blink := False;
      First.Style.Conceal := False;
      Terminal.Core.Snapshot_Editing.Set_Cell (Snapshot, 1, First);
   end;
   Assert
     (not Terminal.App.Text_Blink.Contains_Blinking_Text (Snapshot),
      "snapshot reports no blinking text after style clears");
   Assert
     (Terminal.App.Text_Blink.Status_Label (Snapshot, 0) =
      "Text blink inactive",
      "inactive text blink status label");
   declare
      First_Pane  : Terminal.Core.Render_Snapshot;
      Second_Pane : Terminal.Core.Render_Snapshot;
      Activity    : Terminal.App.Blink_Activity.Activity;
      Cursor      : Terminal.Core.Cursor_State;
   begin
      Terminal.Core.Snapshot (Core, First_Pane);
      Terminal.Core.Snapshot (Core, Second_Pane);
      Cursor := Second_Pane.Cursor;
      Cursor.Blinking := True;
      Terminal.Core.Snapshot_Editing.Set_Cursor (Second_Pane, Cursor);
      Terminal.App.Blink_Activity.Reset (Activity);
      Terminal.App.Blink_Activity.Include (Activity, First_Pane);
      Terminal.App.Blink_Activity.Include (Activity, Second_Pane);
      Assert
        (Terminal.App.Blink_Activity.Requires_Redraw (Activity, 4, 5),
         "a blinking secondary pane schedules the shared redraw");
      Assert
        (not Terminal.App.Blink_Activity.Requires_Redraw (Activity, 5, 5),
         "unchanged blink ticks do not schedule redraws");
      Terminal.App.Blink_Activity.Reset (Activity);
      Cursor := Second_Pane.Cursor;
      Cursor.Visible := False;
      Terminal.Core.Snapshot_Editing.Set_Cursor (Second_Pane, Cursor);
      Terminal.App.Blink_Activity.Include (Activity, Second_Pane);
      Assert
        (not Terminal.App.Blink_Activity.Requires_Redraw (Activity, 4, 5),
         "a hidden blinking cursor does not schedule redraws");
      Terminal.Core.Release (First_Pane);
      Terminal.Core.Release (Second_Pane);
   end;
   Terminal.Core.Release (Snapshot);
   Terminal.Core.Finalize (Core);
end Text_Blink_Smoke;
