with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_OSC_Smoke is
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
      (1  => 16#1B#, 2 => Byte (Character'Pos (']')),
       3  => Byte (Character'Pos ('0')), 4 => Byte (Character'Pos (';')),
       5  => Byte (Character'Pos ('t')), 6 => Byte (Character'Pos ('i')),
       7  => Byte (Character'Pos ('t')), 8 => Byte (Character'Pos ('l')),
       9  => Byte (Character'Pos ('e')), 10 => 16#1B#,
       11 => Byte (Character'Pos ('\')), 12 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC ST feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#, "OSC payload leaked or x missing");
      Terminal.Core.Release (S);
   end;
end Core_OSC_Smoke;

