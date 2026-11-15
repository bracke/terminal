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
   use type Terminal.Core.Graphics_Scroll_Sequence;
   use type Terminal.Core.Cell_Kind;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

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
   Terminal.Core.Resize (T, 3, 5, Resize_Status);
   Assert (Resize_Status = Terminal.Core.Ok, "changed resize status");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Scrollback_Row_Count (T) = 1
         and then
           Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#62#
         and then Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#63#,
         "taller resize pulls the newest history row into the viewport");
      Terminal.Core.Release (S);
   end;
   Terminal.Core.Resize (T, Positive'Last, 2, Resize_Status);
   Assert
     (Resize_Status = Terminal.Core.Invalid_Size,
      "overflowing resize must report invalid size without raising");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 1
      and then
        Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#62#,
      "failed resize must preserve terminal buffers and scrollback");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Graphics_Scroll_Count = 3
         and then S.Graphics_Scroll_Current = 3
         and then S.Graphics_Scroll_Oldest = 1
         and then Terminal.Core.Has_Graphics_Scroll_Events (S),
         "full-screen scroll journal metadata");
      for I in 1 .. S.Graphics_Scroll_Count loop
         Assert
           (Terminal.Core.Graphics_Scroll_Event_At (S, I).Sequence =
              Terminal.Core.Graphics_Scroll_Sequence (I)
            and then Terminal.Core.Graphics_Scroll_Event_At (S, I).Direction =
              Terminal.Core.Graphics_Scroll_Up
            and then Terminal.Core.Graphics_Scroll_Event_At (S, I).Top = 1
            and then Terminal.Core.Graphics_Scroll_Event_At (S, I).Bottom = 2
            and then Terminal.Core.Graphics_Scroll_Event_At (S, I).Count = 1,
            "ordered full-screen scroll journal");
      end loop;
      Terminal.Core.Release (S);
      Assert
        (not Terminal.Core.Has_Graphics_Scroll_Events (S)
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

   Terminal.Core.Initialize (T, 4, 1, 4, Init);
   Assert (Init = Terminal.Core.Ok, "bulk scroll initialize failed");
   Terminal.Core.Feed
     (T, To_Bytes ("1" & ASCII.CR & ASCII.LF
                   & "2" & ASCII.CR & ASCII.LF
                   & "3" & ASCII.CR & ASCII.LF & "4"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bulk scroll setup failed");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "[2S"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bulk scroll feed failed");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 2
      and then
        Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#31#
      and then
        Terminal.Core.Scrollback_Cell_At (T, 2, 1).Text.Code_Point = 16#32#,
      "bulk scroll should archive displaced rows in order");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#33#
         and then Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#34#
         and then Terminal.Core.Cell_At (S, 3, 1).Text.Code_Point = 0
         and then Terminal.Core.Cell_At (S, 4, 1).Text.Code_Point = 0,
         "bulk scroll should shift the retained rows once");
      Assert
        (S.Graphics_Scroll_Count = 1
         and then Terminal.Core.Graphics_Scroll_Event_At (S, 1).Count = 2,
         "bulk scroll should publish one counted graphics event");
      Terminal.Core.Release (S);
   end;

   --  ED 3 invalidates the logical ring without releasing its backing array.
   --  Hyperlink reclamation must ignore those invalid rows, and RIS must clear
   --  their compact references before releasing the intern pool.
   Terminal.Core.Initialize (T, 2, 4, 4, Init);
   Assert (Init = Terminal.Core.Ok, "hyperlink scrollback initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]8;;https://old.test" & ASCII.ESC & "\"
         & "x" & ASCII.ESC & "]8;;" & ASCII.ESC & "\"
         & ASCII.CR & ASCII.LF & "y"
         & ASCII.CR & ASCII.LF & "z"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok
      and then Terminal.Core.Scrollback_Row_Count (T) = 1,
      "linked scrollback setup failed");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "[3J"), Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok
      and then Terminal.Core.Scrollback_Row_Count (T) = 0,
      "linked scrollback erase failed");
   for N in 1 .. 1_100 loop
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "]8;;https://transient.test/"
            & Natural'Image (N) & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "hyperlink sweep after scrollback erase failed");
   end loop;
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "c"), Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok
      and then Terminal.Core.Scrollback_Row_Count (T) = 0,
      "RIS after hyperlink sweep failed");

   Terminal.Core.Initialize (T, 2, 4, 2, Init);
   Assert (Init = Terminal.Core.Ok, "wide scrollback resize initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => Byte (Character'Pos ('b')),
       3 => 16#E4#, 4 => 16#B8#, 5 => 16#80#,
       6 => Byte (Character'Pos (ASCII.CR)),
       7 => Byte (Character'Pos (ASCII.LF)),
       8 => Byte (Character'Pos ('x')),
       9 => Byte (Character'Pos (ASCII.CR)),
       10 => Byte (Character'Pos (ASCII.LF)),
       11 => Byte (Character'Pos ('y'))),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok
      and then Terminal.Core.Scrollback_Row_Count (T) = 1,
      "wide scrollback resize setup failed");
   Terminal.Core.Resize (T, 2, 3, Resize_Status);
   Assert (Resize_Status = Terminal.Core.Ok, "wide scrollback resize failed");
   Assert
     (Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#61#
      and then
        Terminal.Core.Scrollback_Cell_At (T, 1, 2).Text.Code_Point = 16#62#
      and then Terminal.Core.Scrollback_Cell_At (T, 1, 3).Kind =
        Terminal.Core.Empty,
      "wide scrollback resize clears truncated wide head");

   Terminal.Core.Initialize (T, 3, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "reflow initialize failed");
   Terminal.Core.Feed (T, To_Bytes ("abcdefgh"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "reflow feed failed");
   Terminal.Core.Resize (T, 3, 8, Resize_Status);
   Assert (Resize_Status = Terminal.Core.Ok, "wide reflow failed");
   declare
      Expected : constant String := "abcdefgh";
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      for Col in 1 .. 8 loop
         Assert
           (Terminal.Core.Cell_At (S, 1, Col).Text.Code_Point =
              Terminal.Common.Code_Point
                (Character'Pos (Expected (Col))),
            "wide reflow rejoins wrapped text");
      end loop;
      Terminal.Core.Release (S);
   end;
   Terminal.Core.Resize (T, 3, 3, Resize_Status);
   Assert (Resize_Status = Terminal.Core.Ok, "narrow reflow failed");
   Assert
     (Terminal.Core.Scrollback_Row_Count (T) = 2
      and then
        Terminal.Core.Scrollback_Cell_At (T, 1, 1).Text.Code_Point = 16#61#
      and then
        Terminal.Core.Scrollback_Cell_At (T, 2, 1).Text.Code_Point = 16#64#,
      "narrow reflow moves leading visual rows into history");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#67#
         and then Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#68#,
         "narrow reflow preserves the logical-line tail");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 3, 4, 0, Init);
   Assert (Init = Terminal.Core.Ok, "cursor-anchored resize initialize failed");
   Terminal.Core.Feed (T, To_Bytes ("a"), Feed_Status);
   Terminal.Core.Resize (T, 1, 4, Resize_Status);
   Assert (Resize_Status = Terminal.Core.Ok, "cursor-anchored resize failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#
         and then S.Cursor.Row = 1,
         "shorter viewport retains the old cursor row");
      Terminal.Core.Release (S);
   end;
end Core_Scrollback_Smoke;
