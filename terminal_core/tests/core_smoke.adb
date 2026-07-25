with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Cell_Array_Access;
   use type Terminal.Core.Dirty_Row_Array_Access;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Feed_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 3, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

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

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#, "row 1 col 1");
      Assert (Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#64#, "row 2 col 1");
      Assert (S.Cursor.Row = 2 and then S.Cursor.Col = 4, "cursor after feed");
      Terminal.Core.Release (S);
      Assert (S.Cells = null, "released snapshot cells should be null");
      Assert (S.Dirty = null, "released snapshot dirty rows should be null");
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
         Assert (S.Dirty (Row), "DECALN should dirty row" & Natural'Image (Row));
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
end Core_Smoke;
