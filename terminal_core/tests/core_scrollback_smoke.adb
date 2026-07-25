with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Scrollback_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 2, 4, 2, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos ('a')), 2  => 13, 3  => 10,
       4  => Byte (Character'Pos ('b')), 5  => 13, 6  => 10,
       7  => Byte (Character'Pos ('c')), 8  => 13, 9  => 10,
       10 => Byte (Character'Pos ('d')), 11 => 13, 12 => 10,
       13 => Byte (Character'Pos ('e'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");
   Assert (Terminal.Core.Scrollback_Row_Count (T) = 2, "bounded scrollback count");
   Assert
     (Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#62#,
      "oldest retained row");
   Assert
     (Terminal.Core.Scrollback_Cell_At (T, 2, 1).Text.Code_Point = 16#63#,
      "newest retained row");

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "reset feed failed");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 0,
      "terminal reset should clear scrollback");

   Terminal.Core.Initialize (T, 2, 4, 2, Init);
   Assert (Init = Terminal.Core.Ok, "ED scrollback initialize failed");

   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')), 2 => 13, 3 => 10,
       4 => Byte (Character'Pos ('b')), 5 => 13, 6 => 10,
       7 => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "ED scrollback setup feed failed");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 1,
      "ED scrollback setup count");

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('2')), 4 => Byte (Character'Pos ('J'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "ED 2 feed failed");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 1,
      "ED 2 should preserve scrollback");

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('3')), 4 => Byte (Character'Pos ('J'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "ED 3 feed failed");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 0,
      "ED 3 should clear scrollback");
end Core_Scrollback_Smoke;
