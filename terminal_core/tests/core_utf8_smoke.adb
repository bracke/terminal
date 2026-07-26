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

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;
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
   Assert (Init = Terminal.Core.Ok, "UTF-8 scalar boundary initialize failed");
   Terminal.Core.Feed
     (T,
      (1  => 16#F4#, 2  => 16#8F#, 3  => 16#BF#, 4  => 16#BF#,
       5  => 16#ED#, 6  => 16#A0#, 7  => 16#80#,
       8  => 16#F4#, 9  => 16#90#, 10 => 16#80#, 11 => 16#80#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "UTF-8 scalar boundary feed failed");
   Assert
     (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 2,
      "surrogate and above-range UTF-8 should be counted malformed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#10FFFF#,
         "maximum Unicode scalar should decode");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#FFFD#,
         "UTF-8 surrogate should be replaced");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#FFFD#,
         "above-range UTF-8 should be replaced");
      Assert (S.Cursor.Col = 4, "UTF-8 scalar boundary cursor");
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

   Terminal.Core.Initialize (T, 3, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "private CSI consume initialize failed");

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "[<0;1;1M"
            & ASCII.ESC & "[=3;3H"
            & "x"
            & ASCII.ESC & "[?2D"
            & ASCII.ESC & "[>2J"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "private CSI consume feed failed");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 4,
         "private CSI forms should be diagnosed");
   end;

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "private CSI marker should not leak or move cursor");
      Assert (S.Cursor.Col = 2, "private CSI consume cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "coding system consume initialize failed");

   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#1B#, 3 => Byte (Character'Pos ('%')),
       4 => Byte (Character'Pos ('G')),
       5 => Byte (Character'Pos ('b')),
       6 => 16#1B#, 7 => Byte (Character'Pos ('%')),
       8 => Byte (Character'Pos ('@')),
       9 => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "coding system consume feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "coding system consume prefix");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#62#,
         "UTF-8 designation should not leak G");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#63#,
         "default coding designation should not leak at-sign");
      Assert
        (D.Ignored_Escape = 0,
         "coding system designations should not count as ignored escapes");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert
     (Init = Terminal.Core.Ok,
      "unsupported coding system initialize failed");

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Ignored_Escape;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes ("a" & ASCII.ESC & "%/b"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Parser_Recovered,
         "unsupported coding system should recover");
      Assert
        (Terminal.Core.Diagnostics (T).Ignored_Escape = Before + 1,
         "unsupported coding system should be diagnosed");
   end;

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "unsupported coding system prefix");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#62#,
         "unsupported coding system selector should not leak");
      Assert (S.Cursor.Col = 3, "unsupported coding system cursor");
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

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "C1 CSI initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#9B#, 2 => Byte (Character'Pos ('3')),
       3 => Byte (Character'Pos ('G')), 4 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 CSI feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#78#,
         "C1 CSI should move cursor before printable text");
      Assert
        (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
         "C1 CSI should not be counted as malformed UTF-8");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "C1 recovery initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#C2#, 2 => 16#9B#, 3 => Byte (Character'Pos ('3')),
       4 => Byte (Character'Pos ('G')), 5 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 recovery feed failed");
   Assert
     (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
      "UTF-8 encoded C1 CSI should be valid UTF-8");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#78#,
         "UTF-8 encoded C1 CSI should execute CSI");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DEL initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#7F#,
       3 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DEL feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "DEL should leave preceding text");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#62#,
         "DEL should not render as a cell");
      Assert
        (S.Cursor.Col = 3,
         "DEL should not advance the cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DEL UTF-8 recovery initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#C2#, 2 => 16#7F#, 3 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DEL UTF-8 recovery feed failed");
   Assert
     (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 1,
      "DEL after UTF-8 lead should recover the incomplete sequence");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#FFFD#,
         "DEL recovery should emit replacement first");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#78#,
         "text after DEL recovery should render");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "single shift consume initialize failed");

   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos ('a')),
       2  => 16#1B#, 3 => Byte (Character'Pos ('N')),
       4  => Byte (Character'Pos ('x')),
       5  => Byte (Character'Pos ('b')),
       6  => 16#1B#, 7 => Byte (Character'Pos ('O')),
       8  => Byte (Character'Pos ('y')),
       9  => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "single shift consume feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "single shift consume prefix");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#78#,
         "SS2 should invoke G2 for the following printable byte");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#62#,
         "text after SS2 should render");
      Assert
        (Terminal.Core.Cell_At (S, 1, 4).Text.Code_Point = 16#79#,
         "SS3 should invoke G3 for the following printable byte");
      Assert
        (Terminal.Core.Cell_At (S, 1, 5).Text.Code_Point = 16#63#,
         "text after SS3 should render");
      Assert
        (D.Ignored_Escape = 0,
         "SS2/SS3 should not count as ignored escapes");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "C1 single shift initialize failed");

   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#8E#,
       3 => Byte (Character'Pos ('x')),
       4 => Byte (Character'Pos ('b')),
       5 => 16#8F#,
       6 => Byte (Character'Pos ('y')),
       7 => Byte (Character'Pos ('c'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 single shift feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "C1 single shift consume prefix");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#78#,
         "C1 SS2 should invoke G2 for the following printable byte");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#62#,
         "text after C1 SS2 should render");
      Assert
        (Terminal.Core.Cell_At (S, 1, 4).Text.Code_Point = 16#79#,
         "C1 SS3 should invoke G3 for the following printable byte");
      Assert
        (Terminal.Core.Cell_At (S, 1, 5).Text.Code_Point = 16#63#,
         "text after C1 SS3 should render");
      Assert
        (D.Malformed_UTF8 = 0,
         "C1 SS2/SS3 should not count as malformed UTF-8");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "single shift UTF-8 recovery initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#C2#,
       2 => 16#8E#,
       3 => Byte (Character'Pos ('x')),
       4 => Byte (Character'Pos ('z'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "single shift UTF-8 recovery feed failed");
   Assert
     (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
      "UTF-8 encoded SS2 should be valid UTF-8");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "UTF-8 encoded SS2 should render the following byte");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#7A#,
         "text after UTF-8 encoded SS2 should render");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "G2 single shift charset initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('*')),
       3 => Byte (Character'Pos ('0')),
       4 => 16#1B#, 5 => Byte (Character'Pos ('N')),
       6 => Byte (Character'Pos ('q')),
       7 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "G2 single shift charset feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#2500#,
         "SS2 should map through designated DEC special graphics G2");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#78#,
         "single shift should restore the previous charset after one byte");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "C1 ST initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#9C#,
       3 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 ST feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "C1 ST should leave preceding text");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#62#,
         "C1 ST should not render as a cell");
      Assert
        (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
         "C1 ST should not count as malformed UTF-8");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 100, Init);
   Assert (Init = Terminal.Core.Ok, "C1 ST UTF-8 recovery initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#C2#,
       2 => 16#9C#,
       3 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 ST UTF-8 recovery feed failed");
   Assert
     (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
      "UTF-8 encoded C1 ST should be valid UTF-8");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "text after UTF-8 encoded C1 ST should render");
      Terminal.Core.Release (S);
   end;
end Core_UTF8_Smoke;
