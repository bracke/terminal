with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.Core.Snapshot_Testing;
with Core_String_Smoke_Support;

with Ada.Strings.Unbounded;

procedure Core_Inline_Graphics_Cases is
   package Unbounded renames Ada.Strings.Unbounded;
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
   Terminal.Core.Initialize (T, 3, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "iTerm2 cursor initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]1337;File=inline=1:AAAA" & ASCII.BEL & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 cursor feed failed");
   declare
      Event : Terminal.Core.Graphics_Event;
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 0,
         "default iTerm2 cursor movement defers following input");
      Terminal.Core.Release (S);
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Assert
        (Event.Pending
         and then Event.Protocol = Terminal.Core.ITerm2_Graphics,
         "default iTerm2 cursor event is pending");
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code => Terminal.Core.Graphics_OK,
          Cursor =>
            (Move => True, To_Line_Start => True, Placement_Rows => 1,
             others => <>),
          others => <>));
      Terminal.Core.Snapshot (T, S);
      Assert
        (Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#78#,
         "iTerm2 trailing input resumes at the line below the image");
      Assert
        (S.Cursor.Row = 2 and then S.Cursor.Col = 2,
         "iTerm2 cursor commits to the next line before deferred input");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC
         & "]1337;File=inline=1;doNotMoveCursor=1:AAAA"
         & ASCII.BEL & "y"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 fixed-cursor feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 2, 2).Text.Code_Point = 16#79#,
         "doNotMoveCursor leaves following input at the current cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 3, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "bottom image initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[3;1H"
         & ASCII.ESC & "]1337;File=inline=1:AAAA" & ASCII.BEL & "z"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bottom image feed failed");
   declare
      Event : Terminal.Core.Graphics_Event;
      S     : Terminal.Core.Render_Snapshot;
   begin
      Terminal.Core.Peek_Graphics_Event (T, Event);
      Terminal.Core.Complete_Graphics_Event
        (T,
         Event,
         (Code => Terminal.Core.Graphics_OK,
          Cursor =>
            (Move => True, To_Line_Start => True, Placement_Rows => 1,
             others => <>),
          others => <>));
      Terminal.Core.Snapshot (T, S);
      Assert
        (Terminal.Core.Cell_At (S, 3, 1).Text.Code_Point = 16#7A#,
         "bottom image scrolls before deferred input resumes");
      Assert
        (S.Cursor.Row = 3 and then S.Cursor.Col = 2,
         "bottom image leaves the cursor after resumed input");
      Assert
        (Terminal.Core.Scrollback_Row_Count (T) = 1,
         "bottom image advancement records the scrolled row");
      Assert
        (Terminal.Core.Graphics_Scroll_Count (S) = 1,
         "bottom image advancement records the placement scroll");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "tmux recovery initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "Ptmux;" & ASCII.ESC & ASCII.ESC & "%x"
         & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Parser_Recovered,
      "tmux passthrough must propagate nested parser recovery");

   declare
      Nested : Unbounded.Unbounded_String :=
        Unbounded.To_Unbounded_String ("x");
   begin
      for Depth in 1 .. 17 loop
         Nested := Unbounded.To_Unbounded_String
           (Wrap_Tmux (Unbounded.To_String (Nested)));
      end loop;
      Terminal.Core.Initialize (T, 1, 10, 100, Init);
      Assert (Init = Terminal.Core.Ok, "nested tmux initialize failed");
      Terminal.Core.Feed
        (T, To_Bytes (Unbounded.To_String (Nested)), Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Parser_Overflow,
         "nested tmux depth limit must report overflow");
      Terminal.Core.Feed (T, To_Bytes ("z"), Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "nested tmux overflow must restore parser ground state");
      declare
         S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Assert
           (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#7A#,
            "nested tmux overflow recovery text");
         Terminal.Core.Release (S);
      end;
   end;

   declare
      Payload : constant String := Repeat_Char ('q', 256);
      Inner   : constant String := Wrap_Tmux (Payload);
      Nested  : constant String := Wrap_Tmux (Inner);
      Limits  : constant Terminal.Core.Graphics_Resource_Limits :=
        (Transaction_Length   => Nested'Length,
         Pending_Events      => 4,
         Pending_Bytes       => 1_024,
         Deferred_Input_Bytes => 1_024,
         Pixel_Dimension     => 16);
   begin
      Terminal.Core.Initialize (T, 1, 10, 100, Init);
      Assert (Init = Terminal.Core.Ok, "tmux budget initialize failed");
      Terminal.Core.Set_Graphics_Resource_Limits (T, Limits);
      Terminal.Core.Feed (T, To_Bytes (Nested), Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Parser_Overflow,
         "nested tmux decoding shares one transaction byte budget");
      Terminal.Core.Feed (T, To_Bytes ("b"), Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "tmux byte-budget overflow restores parser state");
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "large iTerm2 part initialize failed");
   declare
      Part_Length : constant Natural := 128 * 1024 + 17;
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "]1337;MultipartFile=inline=1" & ASCII.BEL
            & ASCII.ESC & "]1337;FilePart="
            & Repeat_Char ('A', Part_Length) & ASCII.BEL
            & ASCII.ESC & "]1337;FileEnd" & ASCII.BEL),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "iTerm2 FilePart up to the one-MiB protocol limit is accepted");
      declare
         Event : Terminal.Core.Graphics_Event;
      begin
         Terminal.Core.Peek_Graphics_Event (T, Event);
         Assert
           (Event.Pending
            and then Event.Protocol = Terminal.Core.ITerm2_Graphics
            and then Event.Payload_Length =
              String'("File=inline=1:")'Length + Part_Length,
            "large iTerm2 multipart payload assembled without truncation");
      end;
   end;

   Terminal.Core.Initialize (T, 1, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "iTerm2 multipart initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC
         & "]1337;MultipartFile=name=a;inline=1;doNotMoveCursor=1"
         & ASCII.BEL
         & ASCII.ESC & "]1337;FilePart=QU" & ASCII.BEL
         & ASCII.ESC & "]1337;FilePart=FB" & ASCII.BEL
         & ASCII.ESC & "]1337;FileEnd" & ASCII.BEL
         & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 multipart feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Graphics.Pending
         and then S.Graphics.Protocol = Terminal.Core.ITerm2_Graphics,
         "iTerm2 multipart event exposed");
      Assert
        (S.Graphics.Preview (1 .. S.Graphics.Preview_Length) =
           "File=name=a;inline=1;doNotMoveCursor=1:QUFB",
         "iTerm2 multipart payload assembled");
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "iTerm2 multipart trailing text preserved");
      Terminal.Core.Release (S);
   end;

end Core_Inline_Graphics_Cases;
