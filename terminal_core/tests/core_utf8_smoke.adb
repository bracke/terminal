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
end Core_UTF8_Smoke;

