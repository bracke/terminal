with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_SGR_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Feed_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('3')), 4 => Byte (Character'Pos ('1')),
       5  => Byte (Character'Pos (';')), 6 => Byte (Character'Pos ('1')),
       7  => Byte (Character'Pos ('m')), 8 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      C : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert (C.Text.Code_Point = 16#78#, "text");
      Assert (C.Style.Bold, "bold style");
      Assert (C.Style.Foreground.Kind = Terminal.Core.Indexed, "indexed foreground");
      Assert (C.Style.Foreground.Index = 1, "red foreground index");
      Terminal.Core.Release (S);
   end;
end Core_SGR_Smoke;
