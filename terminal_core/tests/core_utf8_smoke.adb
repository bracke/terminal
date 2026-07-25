with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_UTF8_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      (1 => 16#E2#, 2 => 16#82#, 3 => 16#AC#,
       4 => 16#E0#, 5 => 16#80#, 6 => 16#80#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");
   Assert (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 1, "malformed UTF-8 count");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#20AC#, "euro decoded");
      Assert (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#FFFD#, "overlong replacement");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "reinitialize failed");

   Terminal.Core.Feed
     (T,
      (1 => 16#C2#, 2 => 16#1B#, 3 => Byte (Character'Pos ('[')),
       4 => Byte (Character'Pos ('3')), 5 => Byte (Character'Pos ('G')),
       6 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "control recovery feed failed");
   Assert
     (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 1,
      "incomplete UTF-8 before ESC should be counted");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#FFFD#,
         "incomplete UTF-8 before ESC should emit replacement");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#78#,
         "ESC after incomplete UTF-8 should still move cursor");
      Assert (S.Cursor.Col = 4, "cursor after recovered CSI");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "charset consume initialize failed");

   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos ('a')),
       2  => 16#1B#, 3 => Byte (Character'Pos (')')),
       4  => Byte (Character'Pos ('0')),
       5  => Byte (Character'Pos ('b')),
       6  => 16#1B#, 7 => Byte (Character'Pos ('*')),
       8  => Byte (Character'Pos ('B')),
       9  => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "charset consume feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "charset consume prefix");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#62#,
         "charset selector should not leak before b");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#63#,
         "charset selector should not leak before c");
      Assert (S.Cursor.Col = 4, "cursor after charset consume");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "keypad mode consume initialize failed");

   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#1B#, 3 => Byte (Character'Pos ('=')),
       4 => Byte (Character'Pos ('b')),
       5 => 16#1B#, 6 => Byte (Character'Pos ('>')),
       7 => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "keypad mode consume feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "keypad mode consume prefix");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#62#,
         "application keypad mode should not leak");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#63#,
         "numeric keypad mode should not leak");
      Assert
        (D.Ignored_Escape = 0,
         "keypad mode toggles should not count as ignored escapes");
      Terminal.Core.Release (S);
   end;
end Core_UTF8_Smoke;
