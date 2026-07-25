with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Modes_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Feed_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('2')),
       5 => Byte (Character'Pos ('0')), 6 => Byte (Character'Pos ('0')),
       7 => Byte (Character'Pos ('4')), 8 => Byte (Character'Pos ('h'))),
      Feed_Status);

   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");
   Assert (Terminal.Core.Modes (T).Bracketed_Paste, "bracketed paste");

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2  => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('2')), 4 => Byte (Character'Pos (';')),
       5  => Byte (Character'Pos ('4')), 6 => Byte (Character'Pos ('r')),
       7  => 16#1B#, 8  => Byte (Character'Pos ('[')),
       9  => Byte (Character'Pos ('1')), 10 => Byte (Character'Pos (';')),
       11 => Byte (Character'Pos ('1')), 12 => Byte (Character'Pos ('H'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "absolute CUP feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 1,
         "CUP should be absolute with origin mode disabled");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2  => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('6')),
       5  => Byte (Character'Pos ('h')),
       6  => 16#1B#, 7  => Byte (Character'Pos ('[')),
       8  => Byte (Character'Pos ('2')), 9 => Byte (Character'Pos (';')),
       10 => Byte (Character'Pos ('3')), 11 => Byte (Character'Pos ('H'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "origin CUP feed failed");
   Assert (Terminal.Core.Modes (T).Origin_Mode, "origin mode should be enabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 3 and then S.Cursor.Col = 3,
         "CUP should be relative to the top margin in origin mode");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('9')), 4 => Byte (Character'Pos ('H'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "origin clamp feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Cursor.Row = 4, "origin CUP should clamp to bottom margin");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('6')),
       5 => Byte (Character'Pos ('l'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "origin reset feed failed");
   Assert (not Terminal.Core.Modes (T).Origin_Mode, "origin mode should be disabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 1,
         "resetting origin mode should home to absolute row one");
      Terminal.Core.Release (S);
   end;
end Core_Modes_Smoke;
