with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Alternate_Smoke is
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

   Terminal.Core.Feed (T, (1 => Byte (Character'Pos ('p'))), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "primary feed failed");

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('1')),
       5 => Byte (Character'Pos ('0')), 6 => Byte (Character'Pos ('4')),
       7 => Byte (Character'Pos ('9')), 8 => Byte (Character'Pos ('h')),
       9 => Byte (Character'Pos ('a'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "alternate feed failed");
   Assert (Terminal.Core.Modes (T).Alternate_Screen, "alternate mode on");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#, "alternate cell");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('1')),
       5 => Byte (Character'Pos ('0')), 6 => Byte (Character'Pos ('4')),
       7 => Byte (Character'Pos ('9')), 8 => Byte (Character'Pos ('l'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "alternate off failed");
   Assert (not Terminal.Core.Modes (T).Alternate_Screen, "alternate mode off");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#70#, "primary restored");
      Terminal.Core.Release (S);
   end;
end Core_Alternate_Smoke;

