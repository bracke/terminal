with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.Core.Snapshot_Testing;
with Core_String_Smoke_Support;

procedure Core_String_Control_Cases is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Clipboard_Operation;
   use type Terminal.Core.Clipboard_Target;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Protocol_Kind;
   use type Terminal.Core.Initialize_Status;
   use Core_String_Smoke_Support;

   T           : Terminal.Core.Terminal;
   Init        : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
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

   Terminal.Core.Set_Graphics_Capabilities
     (T,
      (Kitty_Direct_RGB         => True,
       Kitty_Direct_RGBA        => True,
       Kitty_Indexed_RGB        => True,
       Kitty_Indexed_RGBA       => True,
       Kitty_Direct_PNG         => True,
       Kitty_Direct_JPEG        => True,
       Kitty_Direct_GIF         => True,
       Kitty_Zlib_Compression   => True,
       Kitty_File_Transfer      => False,
       Kitty_Temporary_Transfer => True,
       Kitty_Shared_Memory      => True,
       Sixel                    => True,
       ITerm2_Inline_Images     => True,
       ITerm2_File_Downloads    => False));
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]1337;Capabilities" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "feature report feed failed");
   declare
      Expected : constant Byte_Array :=
        To_Bytes (ASCII.ESC & "]1337;Capabilities=Sx" & ASCII.ESC & "\");
      Response : Byte_Array (1 .. Expected'Length + 8);
      Last     : Natural;
   begin
      Terminal.Core.Read_Response (T, Response, Last);
      Assert (Last = Expected'Length, "feature report response length");
      Assert
        (Response (Response'First .. Response'First + Last - 1) = Expected,
         "feature report must advertise Sixel but not FILE downloads");
      Assert
        (Terminal.Core.Pending_Response_Length (T) = 0,
         "feature report response should drain atomically");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "Pqabcdef" & ASCII.ESC & "\x"
         & ASCII.ESC & "_Gq=2,f=100,a=T,C=1;AAAA" & ASCII.ESC & "\y"
         & ASCII.ESC & "]1337;File=name=a;inline=1;doNotMoveCursor=1:AAAA" & ASCII.BEL
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
        (D.Graphics_Commands_Received = 3,
         "graphics protocols should be explicitly diagnosed");
      Assert (D.Sixel_Commands_Received = 1, "sixel received count");
      Assert (D.Kitty_Commands_Received = 1, "kitty graphics received count");
      Assert (D.ITerm2_Commands_Received = 1, "iTerm2 image received count");
      Assert
        (D.Last_Graphics_Protocol = Terminal.Core.ITerm2_Graphics,
         "last received graphics protocol");
      Assert
        (D.Last_Graphics_Payload_Length = 43,
         "last received graphics payload length");
      Assert (S.Graphics.Pending, "graphics event should be exposed");
      Assert
        (S.Graphics.Protocol = Terminal.Core.ITerm2_Graphics,
         "graphics event protocol");
      Assert
        (S.Graphics.Row = 1 and then S.Graphics.Col = 3,
         "graphics event position should use protocol cursor cell");
      Assert
        (S.Graphics.Payload_Length = 43,
         "graphics event payload length");
      Assert
        (S.Graphics.Preview_Length = 43,
         "graphics event preview length");
      Assert
        (S.Graphics.Preview (1 .. S.Graphics.Preview_Length) =
         "File=name=a;inline=1;doNotMoveCursor=1:AAAA",
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
end Core_String_Control_Cases;
