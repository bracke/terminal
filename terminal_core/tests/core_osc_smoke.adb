with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_OSC_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   function To_Bytes (S : String) return Byte_Array is
      Result : Byte_Array (1 .. S'Length);
   begin
      for I in S'Range loop
         Result (I - S'First + 1) := Byte (Character'Pos (S (I)));
      end loop;
      return Result;
   end To_Bytes;

   function DCS_Overflow_Fixture return Byte_Array is
      Result : Byte_Array (1 .. 4_101);
   begin
      Result (1) := 16#1B#;
      Result (2) := Byte (Character'Pos ('P'));
      for I in 3 .. 4_099 loop
         Result (I) := Byte (Character'Pos ('a'));
      end loop;
      Result (4_100) := 16#1B#;
      Result (4_101) := Byte (Character'Pos ('\'));
      return Result;
   end DCS_Overflow_Fixture;

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

   declare
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert (Title.Length = 5, "OSC 0 title length");
      Assert (Title.Text (1 .. Title.Length) = "title", "OSC 0 title text");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]2;editor" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC BEL title feed failed");

   declare
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert (Title.Length = 6, "OSC 2 title length");
      Assert (Title.Text (1 .. Title.Length) = "editor", "OSC 2 title text");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]8;ignored" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "unknown OSC feed failed");

   declare
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert (Title.Length = 6, "unknown OSC must not clear title length");
      Assert
        (Title.Text (1 .. Title.Length) = "editor",
         "unknown OSC must not change title");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]52;c;aGVsbG8=" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC 52 clipboard feed failed");

   declare
      Clip : constant Terminal.Core.Clipboard_Request :=
        Terminal.Core.Clipboard (T);
   begin
      Assert (Clip.Pending, "OSC 52 clipboard request pending");
      Assert (Clip.Length = 5, "OSC 52 clipboard request length");
      Assert
        (Clip.Text (1 .. Clip.Length) = "hello",
         "OSC 52 clipboard request text");
   end;

   Terminal.Core.Clear_Clipboard (T);
   Assert
     (not Terminal.Core.Clipboard (T).Pending,
      "cleared OSC 52 clipboard request");

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]52;c;" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "empty OSC 52 feed failed");

   declare
      Clip : constant Terminal.Core.Clipboard_Request :=
        Terminal.Core.Clipboard (T);
   begin
      Assert (Clip.Pending, "empty OSC 52 clipboard request pending");
      Assert (Clip.Length = 0, "empty OSC 52 clipboard request length");
   end;
   Terminal.Core.Clear_Clipboard (T);

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]52;c;%%%" & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "invalid OSC 52 feed failed");
      Assert
        (not Terminal.Core.Clipboard (T).Pending,
         "invalid OSC 52 should not request clipboard");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 1,
         "invalid OSC 52 should be diagnosed");
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#9D#, 2 => Byte (Character'Pos ('2')),
       3 => Byte (Character'Pos (';')),
       4 => Byte (Character'Pos ('c')),
       5 => Byte (Character'Pos ('1')), 6 => 16#9C#,
       7 => Byte (Character'Pos ('z'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 OSC title feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#7A#,
         "C1 OSC payload leaked or trailing text missing");
      Assert (Title.Length = 2, "C1 OSC title length");
      Assert (Title.Text (1 .. Title.Length) = "c1", "C1 OSC title text");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DCS initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "Pignored" & ASCII.ESC & "\x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DCS ST feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "DCS payload leaked or trailing text missing");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#90#, 2 => Byte (Character'Pos ('i')),
       3 => Byte (Character'Pos ('g')), 4 => Byte (Character'Pos ('n')),
       5 => 16#9C#, 6 => Byte (Character'Pos ('y'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 DCS feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#79#,
         "C1 DCS payload leaked or trailing text missing");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "PM/APC initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "^ignored" & ASCII.ESC & "\a"
         & ASCII.ESC & "_ignored" & ASCII.BEL & "b"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "PM/APC feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "PM payload leaked or trailing text missing");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#62#,
         "APC payload leaked or trailing text missing");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#9E#, 2 => Byte (Character'Pos ('p')),
       3 => Byte (Character'Pos ('m')), 4 => 16#9C#,
       5 => Byte (Character'Pos ('c')), 6 => 16#9F#,
       7 => Byte (Character'Pos ('a')), 8 => 16#9C#,
       9 => Byte (Character'Pos ('d'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 PM/APC feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#63#,
         "C1 PM payload leaked or trailing text missing");
      Assert
        (Terminal.Core.Cell_At (S, 1, 4).Text.Code_Point = 16#64#,
         "C1 APC payload leaked or trailing text missing");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SOS initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "Xignored" & ASCII.ESC & "\e"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "SOS feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#65#,
         "SOS payload leaked or trailing text missing");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#98#, 2 => Byte (Character'Pos ('s')),
       3 => Byte (Character'Pos ('o')), 4 => Byte (Character'Pos ('s')),
       5 => 16#9C#, 6 => Byte (Character'Pos ('f'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 SOS feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#66#,
         "C1 SOS payload leaked or trailing text missing");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DCS overflow initialize failed");
   Terminal.Core.Feed (T, DCS_Overflow_Fixture, Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Parser_Overflow,
      "DCS overflow should be explicit");
   Terminal.Core.Feed
     (T,
      To_Bytes ("z"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "DCS overflow recovery feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#7A#,
         "DCS overflow should recover after ST");
      Assert (D.Parser_Overflow = 1, "DCS overflow diagnostic count");
      Terminal.Core.Release (S);
   end;
end Core_OSC_Smoke;
