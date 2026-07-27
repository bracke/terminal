with AUnit.Assertions;

with Terminal.App.Text_Blink;
with Terminal.Core;

procedure Text_Blink_Smoke is
   use AUnit.Assertions;

   Cells : constant Terminal.Core.Cell_Array_Access :=
     new Terminal.Core.Cell_Array (1 .. 2);
   Snapshot : Terminal.Core.Render_Snapshot :=
     (Rows   => 1,
      Cols   => 2,
      Cells  => Cells,
      Dirty  => null,
      Cursor => <>,
      Graphics => <>);
begin
   Cells.all (1).Kind := Terminal.Core.Character;
   Cells.all (1).Text.Code_Point := Character'Pos ('a');
   Cells.all (1).Style.Blink := True;

   Cells.all (2).Kind := Terminal.Core.Character;
   Cells.all (2).Text.Code_Point := Character'Pos ('b');

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
     (not Cells.all (1).Style.Conceal,
      "blinking text stays visible on even ticks");
   Assert
     (not Cells.all (2).Style.Conceal,
      "steady text remains visible on even ticks");

   Assert
     (Terminal.App.Text_Blink.Status_Label (Snapshot, 1) =
      "Text blink hidden",
      "hidden text blink status label");
   Terminal.App.Text_Blink.Apply (Snapshot, 1);
   Assert
     (Cells.all (1).Style.Conceal,
      "blinking text is hidden on odd ticks");
   Assert
     (not Cells.all (2).Style.Conceal,
      "steady text remains visible on odd ticks");

   Cells.all (1).Style.Blink := False;
   Cells.all (1).Style.Conceal := False;
   Assert
     (not Terminal.App.Text_Blink.Contains_Blinking_Text (Snapshot),
      "snapshot reports no blinking text after style clears");
   Assert
     (Terminal.App.Text_Blink.Status_Label (Snapshot, 0) =
      "Text blink inactive",
      "inactive text blink status label");
end Text_Blink_Smoke;
