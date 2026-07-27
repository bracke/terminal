with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.Core.Parser;

procedure Core_OSC_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Clipboard_Operation;
   use type Terminal.Core.Clipboard_Target;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Initialize_Status;

   function To_Bytes (S : String) return Byte_Array is
      Result : Byte_Array (1 .. S'Length);
   begin
      for I in S'Range loop
         Result (I - S'First + 1) := Byte (Character'Pos (S (I)));
      end loop;
      return Result;
   end To_Bytes;

   --  A DCS whose payload exceeds the parser's escape buffer, so Feed must
   --  report Parser_Overflow. Sized off the actual limit (not a literal) so it
   --  keeps overflowing if Max_Escape_Length changes -- as it did when the OSC
   --  and escape buffers grew from 4 KiB to 128 KiB.
   function DCS_Overflow_Fixture return Byte_Array is
      Payload_Length : constant Natural := Terminal.Core.Parser.Max_Escape_Length + 5;
      Result         : Byte_Array (1 .. Payload_Length + 4);
   begin
      Result (1) := 16#1B#;
      Result (2) := Byte (Character'Pos ('P'));
      for I in 1 .. Payload_Length loop
         Result (I + 2) := Byte (Character'Pos ('a'));
      end loop;
      Result (Result'Last - 1) := 16#1B#;
      Result (Result'Last)     := Byte (Character'Pos ('\'));
      return Result;
   end DCS_Overflow_Fixture;

   function Long_Title_Fixture return Byte_Array is
      Payload_Length : constant Natural := Terminal.Core.Max_Title_Length + 20;
      Result : Byte_Array (1 .. Payload_Length + 5);
   begin
      Result (1) := 16#1B#;
      Result (2) := Byte (Character'Pos (']'));
      Result (3) := Byte (Character'Pos ('1'));
      Result (4) := Byte (Character'Pos (';'));
      for I in 1 .. Payload_Length loop
         Result (I + 4) := Byte (Character'Pos ('A'));
      end loop;
      Result (Result'Last) := 16#07#;
      return Result;
   end Long_Title_Fixture;

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

   Terminal.Core.Feed (T, Long_Title_Fixture, Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "long OSC title feed failed");

   declare
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert
        (Title.Length = Terminal.Core.Max_Title_Length,
         "long OSC title should be clipped to bounded length");
      for I in 1 .. Title.Length loop
         Assert
           (Title.Text (I) = 'A',
            "long OSC title clipped byte" & Natural'Image (I));
      end loop;
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "OSC 8 initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]8;id=abc;https://example.test" & ASCII.ESC & "\"
         & "hi"
         & ASCII.ESC & "]8;;" & ASCII.ESC & "\"
         & "!"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC 8 feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      H : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      I : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      Bang : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 3);
   begin
      Assert (H.Text.Code_Point = 16#68#, "OSC 8 linked h");
      Assert (I.Text.Code_Point = 16#69#, "OSC 8 linked i");
      Assert (H.Link.Active, "OSC 8 first cell link active");
      Assert (I.Link.Active, "OSC 8 second cell link active");
      Assert (H.Link.URI_Length = 20, "OSC 8 URI length");
      Assert
        (H.Link.URI (1 .. H.Link.URI_Length) = "https://example.test",
         "OSC 8 URI");
      Assert (H.Link.ID_Length = 3, "OSC 8 id length");
      Assert (H.Link.ID (1 .. H.Link.ID_Length) = "abc", "OSC 8 id");
      Assert (Bang.Text.Code_Point = 16#21#, "OSC 8 trailing bang");
      Assert (not Bang.Link.Active, "OSC 8 close should clear current link");
      Terminal.Core.Release (S);
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
      Assert
        (Clip.Operation = Terminal.Core.Clipboard_Set,
         "OSC 52 clipboard set operation");
      Assert
        (Clip.Target = Terminal.Core.Clipboard_Clipboard,
         "OSC 52 clipboard target");
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

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]52;p;cHJpbWFyeQ==" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC 52 primary feed failed");

   declare
      Clip : constant Terminal.Core.Clipboard_Request :=
        Terminal.Core.Clipboard (T);
   begin
      Assert (Clip.Pending, "OSC 52 primary request pending");
      Assert
        (Clip.Target = Terminal.Core.Clipboard_Primary,
         "OSC 52 primary target");
      Assert (Clip.Length = 7, "OSC 52 primary request length");
      Assert
        (Clip.Text (1 .. Clip.Length) = "primary",
         "OSC 52 primary request text");
   end;
   Terminal.Core.Clear_Clipboard (T);

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]52;c;?" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC 52 query feed failed");

   declare
      Clip : constant Terminal.Core.Clipboard_Request :=
        Terminal.Core.Clipboard (T);
   begin
      Assert (Clip.Pending, "OSC 52 query pending");
      Assert
        (Clip.Operation = Terminal.Core.Clipboard_Query,
         "OSC 52 query operation");
      Assert
        (Clip.Target = Terminal.Core.Clipboard_Clipboard,
         "OSC 52 query target");
      Assert (Clip.Length = 0, "OSC 52 query should not decode text");
   end;
   Terminal.Core.Clear_Clipboard (T);

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]52;s;?" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC 52 selection query feed failed");

   declare
      Clip : constant Terminal.Core.Clipboard_Request :=
        Terminal.Core.Clipboard (T);
   begin
      Assert (Clip.Pending, "OSC 52 selection query pending");
      Assert
        (Clip.Operation = Terminal.Core.Clipboard_Query,
         "OSC 52 selection query operation");
      Assert
        (Clip.Target = Terminal.Core.Clipboard_Selection,
         "OSC 52 selection query target");
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

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]52;c;?x" & ASCII.BEL),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "ambiguous OSC 52 query feed failed");
      Assert
        (not Terminal.Core.Clipboard (T).Pending,
         "ambiguous OSC 52 query should not request clipboard");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 1,
         "ambiguous OSC 52 query should be diagnosed");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]52;x;?" & ASCII.BEL),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "unsupported OSC 52 target feed failed");
      Assert
        (not Terminal.Core.Clipboard (T).Pending,
         "unsupported OSC 52 target should not request clipboard");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 1,
         "unsupported OSC 52 target should be diagnosed");
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]52;cx;?" & ASCII.BEL),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "mixed unsupported OSC 52 target feed failed");
      Assert
        (not Terminal.Core.Clipboard (T).Pending,
         "mixed unsupported OSC 52 target should not request clipboard");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 1,
         "mixed unsupported OSC 52 target should be diagnosed");
   end;

   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "C1 OSC title initialize failed");
   Terminal.Core.Feed (T, To_Bytes ("x"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 OSC title prefix feed failed");

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
   Assert (Init = Terminal.Core.Ok, "graphics protocol initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "Pqabcdef" & ASCII.ESC & "\x"
         & ASCII.ESC & "_Gf=100,a=T;AAAA" & ASCII.ESC & "\y"
         & ASCII.ESC & "]1337;File=name=a;inline=1:AAAA" & ASCII.BEL
         & "z"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "graphics protocol feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "sixel payload leaked or trailing text missing");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#79#,
         "kitty payload leaked or trailing text missing");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#7A#,
         "iTerm2 image payload leaked or trailing text missing");
      Assert
        (D.Graphics_Protocol_Ignored = 3,
         "graphics protocols should be explicitly diagnosed");
      Assert (D.Sixel_Ignored = 1, "sixel ignored count");
      Assert (D.Kitty_Graphics_Ignored = 1, "kitty graphics ignored count");
      Assert (D.ITerm2_Image_Ignored = 1, "iTerm2 image ignored count");
      Assert
        (D.Last_Graphics_Protocol = Terminal.Core.ITerm2_Graphics,
         "last ignored graphics protocol");
      Assert
        (D.Last_Graphics_Payload_Length = 25,
         "last ignored graphics payload length");
      Assert (S.Graphics.Pending, "graphics event should be exposed");
      Assert
        (S.Graphics.Protocol = Terminal.Core.ITerm2_Graphics,
         "graphics event protocol");
      Assert
        (S.Graphics.Row = 1 and then S.Graphics.Col = 3,
         "graphics event position should use protocol cursor cell");
      Assert
        (S.Graphics.Payload_Length = 25,
         "graphics event payload length");
      Assert
        (S.Graphics.Preview_Length = 25,
         "graphics event preview length");
      Assert
        (S.Graphics.Preview (1 .. S.Graphics.Preview_Length) =
         "File=name=a;inline=1:AAAA",
         "graphics event preview");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "tmux passthrough initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "Ptmux;"
         & ASCII.ESC & ASCII.ESC & "]0;wrapped"
         & ASCII.ESC & ASCII.ESC & "\"
         & ASCII.ESC & "\x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "tmux title passthrough feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "tmux passthrough trailing text missing");
      Assert (Title.Length = 7, "tmux passthrough title length");
      Assert
        (Title.Text (1 .. Title.Length) = "wrapped",
         "tmux passthrough title text");
      Assert
        (D.Multiplexer_Passthrough = 1,
         "tmux passthrough diagnostic count");
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
