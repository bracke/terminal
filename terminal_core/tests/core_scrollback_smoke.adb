with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Scrollback_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Resize_Status;
   use type Terminal.Core.Graphics_Scroll_Direction;
   use type Terminal.Core.Graphics_Scroll_Event_Array_Access;
   use type Terminal.Core.Graphics_Scroll_Sequence;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Resize_Status : Terminal.Core.Resize_Status;
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
   Terminal.Core.Resize (T, 2, 4, Resize_Status);
   Assert (Resize_Status = Terminal.Core.Ok, "unchanged resize status");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 2
      and then
        Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#62#
      and then
        Terminal.Core.Scrollback_Cell_At (T, 2, 1).Text.Code_Point = 16#63#,
      "unchanged resize must preserve scrollback");
   Terminal.Core.Resize (T, Positive'Last, 2, Resize_Status);
   Assert
     (Resize_Status = Terminal.Core.Allocation_Failed,
      "overflowing resize must fail without raising");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 2
      and then
        Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#62#
      and then
        Terminal.Core.Scrollback_Cell_At (T, 2, 1).Text.Code_Point = 16#63#,
      "failed resize must preserve terminal buffers and scrollback");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Graphics_Scroll_Count = 3
         and then S.Graphics_Scroll_Current = 3
         and then S.Graphics_Scroll_Oldest = 1
         and then S.Graphics_Scroll_Events /= null,
         "full-screen scroll journal metadata");
      for I in 1 .. S.Graphics_Scroll_Count loop
         Assert
           (S.Graphics_Scroll_Events (I).Sequence =
              Terminal.Core.Graphics_Scroll_Sequence (I)
            and then S.Graphics_Scroll_Events (I).Direction =
              Terminal.Core.Graphics_Scroll_Up
            and then S.Graphics_Scroll_Events (I).Top = 1
            and then S.Graphics_Scroll_Events (I).Bottom = 2
            and then S.Graphics_Scroll_Events (I).Count = 1,
            "ordered full-screen scroll journal");
      end loop;
      Terminal.Core.Release (S);
      Assert
        (S.Graphics_Scroll_Events = null
         and then S.Graphics_Scroll_Count = 0,
         "scroll journal snapshot release");
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "reset feed failed");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 0,
      "terminal reset should clear scrollback");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Graphics_Scroll_Count = 0
         and then S.Graphics_Scroll_Current = 0,
         "terminal reset should clear graphics scroll journal");
      Terminal.Core.Release (S);
   end;

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
