with AUnit.Assertions;

with Terminal.App.Selection;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Selection_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;
begin
   declare
      Pos : constant Terminal.App.Selection.Cell_Position :=
        Terminal.App.Selection.Cell_From_Pixels
          (X           => 17.0,
           Y           => 26.0,
           Cell_Width  => 10,
           Cell_Height => 20,
           Margin      => 6,
           Rows        => 24,
           Cols        => 80);
   begin
      Assert (Pos.Row = 2, "pixel y should map through margin and cell height");
      Assert (Pos.Col = 2, "pixel x should map through margin and cell width");
   end;

   Terminal.Core.Initialize (T, 2, 4, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes ("ab" & ASCII.CR & ASCII.LF & "cd"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");

   declare
      Sel : Terminal.App.Selection.Selection_State;
      S   : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Selection.Begin_Selection
        (Sel, (Row => 1, Col => 2));
      Terminal.App.Selection.Finish_Selection
        (Sel, (Row => 2, Col => 2));

      Assert
        (Terminal.App.Selection.Selected_Text (S, Sel) =
         "b" & ASCII.LF & "cd",
         "selection should copy visible text across rows");

      Assert
        (not Terminal.Core.Cell_At (S, 1, 2).Style.Inverse,
         "cell should start without selection inversion");
      Terminal.App.Selection.Apply_To_Snapshot (S, Sel);
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Style.Inverse,
         "selected cell should be inverted for rendering");
      Assert
        (not Terminal.Core.Cell_At (S, 1, 1).Style.Inverse,
         "unselected cell should not be inverted");

      Terminal.Core.Release (S);
   end;
end Selection_Smoke;
