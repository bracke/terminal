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

   function To_String (Data : Byte_Array) return String is
      Result : String (1 .. Data'Length);
   begin
      for I in Data'Range loop
         Result (I - Data'First + 1) := Character'Val (Natural (Data (I)));
      end loop;
      return Result;
   end To_String;
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

   Terminal.Core.Initialize (T, 1, 4, 10, Init);
   Assert (Init = Terminal.Core.Ok, "cluster selection initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#CC#, 3 => 16#81#,
       4 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "cluster selection feed failed");

   declare
      Sel : Terminal.App.Selection.Selection_State;
      S   : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Selection.Begin_Selection
        (Sel, (Row => 1, Col => 1));
      Terminal.App.Selection.Finish_Selection
        (Sel, (Row => 1, Col => 1));

      Assert
        (Terminal.App.Selection.Selected_Text (S, Sel) =
         To_String ((1 => 16#61#, 2 => 16#CC#, 3 => 16#81#)),
         "selection should copy attached combining marks");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 5, 10, Init);
   Assert (Init = Terminal.Core.Ok, "wide selection initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#E4#, 3 => 16#B8#, 4 => 16#80#,
       5 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "wide selection feed failed");

   declare
      Sel : Terminal.App.Selection.Selection_State;
      S   : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Selection.Begin_Selection
        (Sel, (Row => 1, Col => 2));
      Terminal.App.Selection.Finish_Selection
        (Sel, (Row => 1, Col => 2));

      Assert
        (Terminal.App.Selection.Selected_Text (S, Sel) =
         To_String ((1 => 16#E4#, 2 => 16#B8#, 3 => 16#80#)),
         "selecting only a wide head should copy the glyph");

      Terminal.App.Selection.Apply_To_Snapshot (S, Sel);
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Style.Inverse,
         "wide head should highlight when selected");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Style.Inverse,
         "wide continuation should highlight when head is selected");
      Assert
        (not Terminal.Core.Cell_At (S, 1, 4).Style.Inverse,
         "wide selection should not affect following cell");
      Terminal.Core.Release (S);
   end;

   declare
      Sel : Terminal.App.Selection.Selection_State;
      S   : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Selection.Begin_Selection
        (Sel, (Row => 1, Col => 3));
      Terminal.App.Selection.Finish_Selection
        (Sel, (Row => 1, Col => 3));

      Assert
        (Terminal.App.Selection.Selected_Text (S, Sel) =
         To_String ((1 => 16#E4#, 2 => 16#B8#, 3 => 16#80#)),
         "selecting only a wide continuation should copy the whole glyph");

      Terminal.App.Selection.Apply_To_Snapshot (S, Sel);
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Style.Inverse,
         "wide head should highlight when continuation is selected");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Style.Inverse,
         "wide continuation should highlight when selected");
      Assert
        (not Terminal.Core.Cell_At (S, 1, 1).Style.Inverse,
         "wide selection should not affect previous cell");
      Terminal.Core.Release (S);
   end;

   declare
      Sel : Terminal.App.Selection.Selection_State;
      S   : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Selection.Begin_Selection
        (Sel, (Row => 1, Col => 2));
      Terminal.App.Selection.Finish_Selection
        (Sel, (Row => 1, Col => 3));

      Assert
        (Terminal.App.Selection.Selected_Text (S, Sel) =
         To_String ((1 => 16#E4#, 2 => 16#B8#, 3 => 16#80#)),
         "selecting both halves of a wide glyph should copy it once");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 10, Init);
   Assert (Init = Terminal.Core.Ok, "emoji cluster selection initialize failed");
   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos ('a')),
       2  => 16#F0#, 3  => 16#9F#, 4  => 16#91#, 5  => 16#A9#,
       6  => 16#E2#, 7  => 16#80#, 8  => 16#8D#,
       9  => 16#F0#, 10 => 16#9F#, 11 => 16#91#, 12 => 16#A8#,
       13 => 16#F0#, 14 => 16#9F#, 15 => 16#8F#, 16 => 16#BD#,
       17 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "emoji cluster selection feed failed");

   declare
      Sel : Terminal.App.Selection.Selection_State;
      S   : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Expected : constant String :=
        To_String
          ((1  => 16#F0#, 2  => 16#9F#, 3  => 16#91#, 4  => 16#A9#,
            5  => 16#E2#, 6  => 16#80#, 7  => 16#8D#,
            8  => 16#F0#, 9  => 16#9F#, 10 => 16#91#, 11 => 16#A8#,
            12 => 16#F0#, 13 => 16#9F#, 14 => 16#8F#, 15 => 16#BD#));
   begin
      Terminal.App.Selection.Begin_Selection
        (Sel, (Row => 1, Col => 2));
      Terminal.App.Selection.Finish_Selection
        (Sel, (Row => 1, Col => 2));

      Assert
        (Terminal.App.Selection.Selected_Text (S, Sel) = Expected,
         "selecting emoji cluster head should copy full stored cluster");
      Terminal.Core.Release (S);
   end;

   declare
      Sel : Terminal.App.Selection.Selection_State;
      S   : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Expected : constant String :=
        To_String
          ((1  => 16#F0#, 2  => 16#9F#, 3  => 16#91#, 4  => 16#A9#,
            5  => 16#E2#, 6  => 16#80#, 7  => 16#8D#,
            8  => 16#F0#, 9  => 16#9F#, 10 => 16#91#, 11 => 16#A8#,
            12 => 16#F0#, 13 => 16#9F#, 14 => 16#8F#, 15 => 16#BD#));
   begin
      Terminal.App.Selection.Begin_Selection
        (Sel, (Row => 1, Col => 3));
      Terminal.App.Selection.Finish_Selection
        (Sel, (Row => 1, Col => 3));

      Assert
        (Terminal.App.Selection.Selected_Text (S, Sel) = Expected,
         "selecting emoji cluster continuation should copy full stored cluster");
      Terminal.Core.Release (S);
   end;
end Selection_Smoke;
