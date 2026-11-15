with Terminal.Core.Status_Labels;
with Terminal.Core.Snapshot_Editing;
with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.Core.Snapshot_Testing;

procedure Core_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Transaction_Generation;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Assert
     (Terminal.Core.Snapshot_Testing.Cleanup_Diagnostic_Is_Observable,
      "snapshot finalizer diagnostics retain identity and can be reset");
   Assert
     (Terminal.Core.Cell_Content'Size < Terminal.Core.Cell'Size,
      "link-free cell view excludes hyperlink storage");
   Terminal.Core.Initialize (T, Positive'Last, 2, 0, Init);
   Assert (Init = Terminal.Core.Invalid_Size, "grid overflow is rejected");
   Terminal.Core.Initialize (T, 1, Positive'Last, 2, Init);
   Assert
     (Init = Terminal.Core.Invalid_Scrollback_Limit,
      "scrollback overflow is rejected distinctly");

   Terminal.Core.Initialize (T, 3, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");
   Assert
     (Terminal.Core.Status_Labels.Initialize_Label (Init) = "Initialize: Ok",
      "initialize status label");
   Assert
     (Terminal.Core.Status_Labels.Initialize_Label (Terminal.Core.Invalid_Size) =
      "Initialize: Invalid Size",
      "invalid-size status label");
   Assert
     (Terminal.Core.Status_Labels.Feed_Label (Terminal.Core.Parser_Overflow) =
      "Feed: Parser Overflow",
      "parser-overflow status label");
   Assert
     (Terminal.Core.Status_Labels.Diagnostics_Label (Terminal.Core.Diagnostics (T)) =
      "Diagnostics: clean",
      "clean diagnostics label");

   declare
      Bounded : Terminal.Core.Terminal;
      Bounded_Init : Terminal.Core.Initialize_Status;
      Bounded_Feed : Terminal.Core.Feed_Status;
      Huge_Operations : constant String :=
        "x" & ASCII.ESC & "[999999999999S" &
        ASCII.ESC & "[999999999999T" &
        ASCII.ESC & "[999999999999b";
      Input : Byte_Array (1 .. Huge_Operations'Length);
   begin
      for I in Huge_Operations'Range loop
         Input (I - Huge_Operations'First + 1) :=
           Byte (Character'Pos (Huge_Operations (I)));
      end loop;
      Terminal.Core.Initialize (Bounded, 3, 10, 0, Bounded_Init);
      Assert (Bounded_Init = Terminal.Core.Ok, "bounded CSI initialize");
      Terminal.Core.Feed (Bounded, Input, Bounded_Feed);
      Assert
        (Bounded_Feed = Terminal.Core.Parser_Overflow,
         "huge CSI parameters should report rejection");
      declare
         S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Bounded);
      begin
         Assert
           (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point =
              Character'Pos ('x')
            and then Terminal.Core.Cell_At (S, 1, 2).Kind =
              Terminal.Core.Empty
            and then S.Cursor.Row = 1
            and then S.Cursor.Col = 2,
            "overflowed CSI commands must not execute saturated work counts");
         Terminal.Core.Release (S);
      end;

      --  Preserve the invalid-command state across arbitrary PTY boundaries.
      Terminal.Core.Feed
        (Bounded,
         (1 => Byte (Character'Pos (ASCII.ESC)),
          2 => Byte (Character'Pos ('[')),
          3 => Byte (Character'Pos ('9')),
          4 => Byte (Character'Pos ('9')),
          5 => Byte (Character'Pos ('9')),
          6 => Byte (Character'Pos ('9')),
          7 => Byte (Character'Pos ('9')),
          8 => Byte (Character'Pos ('9'))),
         Bounded_Feed);
      Assert
        (Bounded_Feed = Terminal.Core.Parser_Overflow,
         "split oversized CSI prefix should report overflow");
      Terminal.Core.Feed
        (Bounded,
         (1 => Byte (Character'Pos ('b'))),
         Bounded_Feed);
      Assert
        (Bounded_Feed = Terminal.Core.Parser_Recovered,
         "split oversized CSI final should report recovery");
      declare
         S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Bounded);
      begin
         Assert
           (Terminal.Core.Cell_At (S, 1, 2).Kind = Terminal.Core.Empty
            and then S.Cursor.Row = 1
            and then S.Cursor.Col = 2,
            "split overflowed CSI must not execute");
         Terminal.Core.Release (S);
      end;
      Terminal.Core.Finalize (Bounded);
   end;

   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => Byte (Character'Pos ('b')),
       3 => Byte (Character'Pos ('c')),
       4 => 13,
       5 => 10,
       6 => Byte (Character'Pos ('d')),
       7 => Byte (Character'Pos ('e')),
       8 => Byte (Character'Pos ('f'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");
   Assert
     (Terminal.Core.Status_Labels.Feed_Label (Feed_Status) = "Feed: Ok",
      "feed status label");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#, "row 1 col 1");
      Assert (Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#64#, "row 2 col 1");
      Assert (S.Cursor.Row = 2 and then S.Cursor.Col = 4, "cursor after feed");
      Terminal.Core.Release (S);
      Assert (Terminal.Core.Cell_Count (S) = 0,
              "released snapshot cells should be empty");
      Assert (not Terminal.Core.Has_Dirty_Rows (S),
              "released snapshot dirty rows should be empty");
      Terminal.Core.Release (S);
   end;

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Style : constant Terminal.Core.Cell_Style :=
        Terminal.Core.Cell_Style_At_Index (S, 1);
      Rejected : Boolean := False;
   begin
      begin
         Terminal.Core.Snapshot_Editing.Set_Cell_Style
           (S, Positive (Terminal.Core.Cell_Count (S) + 1), Style);
      exception
         when Constraint_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected,
         "cell-style mutation should reject an index outside the snapshot");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 3, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DECALN initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('x')),
       2 => Byte (Character'Pos ('y')),
       3 => 16#1B#,
       4 => Byte (Character'Pos ('#')),
       5 => Byte (Character'Pos ('8'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DECALN feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      for Row in 1 .. S.Rows loop
         Assert (Terminal.Core.Dirty_Row (S, Row),
                 "DECALN should dirty row" & Natural'Image (Row));
         for Col in 1 .. S.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (S, Row, Col);
            begin
               Assert
                 (Cell.Kind = Terminal.Core.Character,
                  "DECALN cell kind row" & Natural'Image (Row)
                  & " col" & Natural'Image (Col));
               Assert
                 (Cell.Text.Code_Point = 16#45#,
                  "DECALN cell text row" & Natural'Image (Row)
                  & " col" & Natural'Image (Col));
            end;
         end loop;
      end loop;

      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 3,
         "DECALN should preserve cursor position");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "non-1 feed initialize failed");
   Terminal.Core.Feed
     (T,
      (10 => Byte (Character'Pos ('r')),
       11 => Byte (Character'Pos ('a')),
       12 => Byte (Character'Pos ('n')),
       13 => Byte (Character'Pos ('g')),
       14 => Byte (Character'Pos ('e')),
       15 => 13,
       16 => 10,
       17 => Byte (Character'Pos ('z'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "non-1 feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#72#,
         "non-1 feed first cell");
      Assert
        (Terminal.Core.Cell_At (S, 1, 5).Text.Code_Point = 16#65#,
         "non-1 feed fifth cell");
      Assert
        (Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#7A#,
         "non-1 feed second row");
      Assert
        (S.Cursor.Row = 2 and then S.Cursor.Col = 2,
         "non-1 feed cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 3, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "invalid DECALN initialize failed");
   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Ignored_Escape;
   begin
      Terminal.Core.Feed
        (T,
         (1 => Byte (Character'Pos ('x')),
          2 => 16#1B#,
          3 => Byte (Character'Pos ('#')),
          4 => Byte (Character'Pos ('9')),
          5 => Byte (Character'Pos ('y'))),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Parser_Recovered,
         "invalid DECALN selector should recover");
      Assert
        (Terminal.Core.Diagnostics (T).Ignored_Escape = Before + 1,
         "invalid DECALN selector should be diagnosed");
      Assert
        (Terminal.Core.Status_Labels.Diagnostics_Label (Terminal.Core.Diagnostics (T)) =
         "Diagnostics: issues=1 utf8=0 esc=1 parse=0 queue=0 unsup=0 gfx=0 mux=0",
         "invalid DECALN diagnostics label");
   end;

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "invalid DECALN should preserve prior text");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#79#,
         "invalid DECALN selector should not leak");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Kind = Terminal.Core.Empty,
         "invalid DECALN should not fill the screen");
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 3,
         "invalid DECALN cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "C1 RIS initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => Byte (Character'Pos ('b')),
       3 => 16#8C#,
       4 => Byte (Character'Pos ('z'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 RIS feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#7A#,
         "C1 RIS should clear old text before trailing text");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Kind = Terminal.Core.Empty,
         "C1 RIS should clear second cell");
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 2,
         "C1 RIS should reset cursor before trailing text");
      Assert
        (D.Malformed_UTF8 = 0,
         "C1 RIS should not count as malformed UTF-8");
      Terminal.Core.Release (S);
   end;

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Bounds_Rejected : Boolean := False;
      Event : Terminal.Core.Graphics_Event := S.Graphics;
   begin
      Event.Pending := True;
      Terminal.Core.Snapshot_Editing.Set_Graphics (S, Event);
      Terminal.Core.Snapshot_Testing.Set_Presentation_Context
        (S,
         Stream => S.Graphics_Stream,
         Transaction => 7,
         Alternate => S.Alternate_Screen,
         Screen_Generation => S.Screen_Generation);
      Assert
        (Terminal.Core.Cell_Count (S) = S.Rows * S.Cols,
         "snapshot owns a complete cell grid");
      Assert (Terminal.Core.Is_Valid (S), "fresh snapshot is valid");
      Assert
        (Terminal.Core.Snapshot_Testing.Cell_Replacement_Is_Atomic (S),
         "failed snapshot cell replacement preserves cell and counters");
      Assert
        (Terminal.Core.Snapshot_Testing.Batch_Replacement_Is_Atomic (S),
         "failed snapshot batch preserves every cell and counter");
      declare
         First  : constant Terminal.Core.Cell :=
           Terminal.Core.Cell_At_Index (S, 1);
         Second : constant Terminal.Core.Cell :=
           Terminal.Core.Cell_At_Index (S, 2);
         Broken : Terminal.Core.Cell := First;
      begin
         Broken.Kind := Terminal.Core.Character;
         Broken.Text.Width := Terminal.Core.Width_Two;
         Terminal.Core.Snapshot_Editing.Set_Cell (S, 1, Broken);
         Terminal.Core.Snapshot_Editing.Set_Cell (S, 2, Second);
         Assert
           (not Terminal.Core.Is_Valid (S),
            "snapshot rejects a wide head without a continuation");
         Terminal.Core.Snapshot_Editing.Set_Cell (S, 1, First);
         Broken := Second;
         Broken.Kind := Terminal.Core.Wide_Continuation;
         Terminal.Core.Snapshot_Editing.Set_Cell (S, 2, Broken);
         Assert
           (not Terminal.Core.Is_Valid (S),
            "snapshot rejects an orphaned wide continuation");
         Terminal.Core.Snapshot_Editing.Set_Cell (S, 2, Second);
         Assert
           (Terminal.Core.Is_Valid (S),
            "snapshot remains valid after invariant test restoration");
      end;
      begin
         declare
            Ignored : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At_Index
                (S, Positive (Terminal.Core.Cell_Count (S) + 1));
            pragma Unreferenced (Ignored);
         begin
            Bounds_Rejected := False;
         end;
      exception
         when Constraint_Error =>
            Bounds_Rejected := True;
      end;
      Assert
        (Bounds_Rejected,
         "indexed cell access observes logical snapshot dimensions");
      Bounds_Rejected := False;
      begin
         Terminal.Core.Snapshot_Editing.Set_Cell
           (S,
            Positive (Terminal.Core.Cell_Count (S) + 1),
            Terminal.Core.Cell_At_Index (S, 1));
         Bounds_Rejected := False;
      exception
         when Constraint_Error =>
            Bounds_Rejected := True;
      end;
      Assert
        (Bounds_Rejected,
         "indexed cell replacement observes logical snapshot dimensions");
      Bounds_Rejected := False;
      begin
         declare
            Ignored : constant Boolean :=
              Terminal.Core.Dirty_Row (S, S.Rows + 1);
            pragma Unreferenced (Ignored);
         begin
            Bounds_Rejected := False;
         end;
      exception
         when Constraint_Error =>
            Bounds_Rejected := True;
      end;
      Assert
        (Bounds_Rejected,
         "dirty-row access observes logical snapshot dimensions");
      Bounds_Rejected := False;
      begin
         Terminal.Core.Snapshot_Editing.Set_Dirty_Row (S, S.Rows + 1, False);
         Bounds_Rejected := False;
      exception
         when Constraint_Error =>
            Bounds_Rejected := True;
      end;
      Assert
        (Bounds_Rejected,
         "dirty-row replacement observes logical snapshot dimensions");
      Bounds_Rejected := False;
      declare
         Cursor : Terminal.Core.Cursor_State := S.Cursor;
      begin
         Cursor.Row := S.Rows + 1;
         begin
            Terminal.Core.Snapshot_Editing.Set_Cursor (S, Cursor);
         exception
            when Constraint_Error => Bounds_Rejected := True;
         end;
      end;
      Assert
        (Bounds_Rejected,
         "snapshot cursor setter rejects rows outside the logical grid");
      Bounds_Rejected := False;
      declare
         Cursor : Terminal.Core.Cursor_State := S.Cursor;
      begin
         Cursor.Col := S.Cols + 1;
         begin
            Terminal.Core.Snapshot_Editing.Set_Cursor (S, Cursor);
         exception
            when Constraint_Error => Bounds_Rejected := True;
         end;
      end;
      Assert
        (Bounds_Rejected,
         "snapshot cursor setter rejects columns outside the logical grid");
      Bounds_Rejected := False;
      Event := S.Graphics;
      Event.Preview_Length := 1;
      Event.Payload_Length := 0;
      begin
         Terminal.Core.Snapshot_Editing.Set_Graphics (S, Event);
      exception
         when Constraint_Error => Bounds_Rejected := True;
      end;
      Assert
        (Bounds_Rejected,
         "snapshot graphics setter rejects a preview beyond its payload");
      begin
         declare
            Ignored : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (S, S.Rows + 1, 1);
            pragma Unreferenced (Ignored);
         begin
            Bounds_Rejected := False;
         end;
      exception
         when Constraint_Error =>
            Bounds_Rejected := True;
      end;
      Assert
        (Bounds_Rejected,
         "out-of-range snapshot coordinates raise Constraint_Error");
      Terminal.Core.Release (S);
      Assert
        (Terminal.Core.Cell_Count (S) = 0
         and then not S.Graphics.Pending
         and then S.Graphics_Transaction = 0,
         "snapshot release resets storage and graphics state");
   end;
end Core_Smoke;
