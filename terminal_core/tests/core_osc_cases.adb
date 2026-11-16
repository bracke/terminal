with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.Core.Snapshot_Testing;
with Core_String_Smoke_Support;

procedure Core_OSC_Cases is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Clipboard_Operation;
   use type Terminal.Core.Clipboard_Target;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Protocol_Kind;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Notification_Kind;
   use type Terminal.Core.Progress_Kind;
   use type Terminal.Core.Shell_Mark_Kind;
   use type Terminal.Core.Semantic_Zone;
   use Core_String_Smoke_Support;

   T           : Terminal.Core.Terminal;
   Init        : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]9999999999999999999999999999999999999999;x"
         & ASCII.BEL),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "oversized OSC command should saturate");

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
       ITerm2_File_Downloads    => True));
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]1337;Capabilities" & ASCII.ESC & "\"),
      Feed_Status);
   declare
      Expected : constant Byte_Array :=
        To_Bytes (ASCII.ESC & "]1337;Capabilities=FSx" & ASCII.ESC & "\");
      Response : Byte_Array (1 .. Expected'Length);
      Last : Natural;
   begin
      Terminal.Core.Read_Response (T, Response, Last);
      Assert
        (Last = Expected'Length and then Response = Expected,
         "feature report advertises complete FILE when enabled");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]7;file://localhost/home/test%20project" & ASCII.BEL
         & ASCII.ESC & "]133;A" & ASCII.BEL
         & ASCII.ESC & "]133;B" & ASCII.BEL
         & ASCII.ESC & "]133;C" & ASCII.BEL
         & ASCII.ESC & "]133;D;17;245" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "shell integration OSC feed failed");
   declare
      Shell : constant Terminal.Core.Shell_Integration_Snapshot :=
        Terminal.Core.Shell_Integration (T);
   begin
      Assert
        (Shell.Working_Directory.Length = 18
         and then Shell.Working_Directory.Text
           (1 .. Shell.Working_Directory.Length) = "/home/test project",
         "OSC 7 working directory");
      Assert
        (Shell.Zone = Terminal.Core.No_Semantic_Zone,
         "OSC 133 completion closes semantic zone");
      Assert
        (Shell.Prompt_Count = 1
         and then Shell.Command_Count = 1
         and then Shell.Output_Count = 1
         and then Shell.Completion_Count = 1,
         "OSC 133 semantic counters");
      Assert
        (Shell.Has_Exit_Status and then Shell.Last_Exit_Status = 17,
         "OSC 133 exit status");
      Assert
        (Terminal.Core.Shell_Mark_Count (T) = 2
         and then Terminal.Core.Shell_Mark_At (T, 1).Kind =
           Terminal.Core.Prompt_Mark
         and then Terminal.Core.Shell_Mark_At (T, 2).Kind =
           Terminal.Core.Command_Mark,
         "OSC 133 prompt and command marks");
      Assert
        (Terminal.Core.Shell_Command_Block_Count (T) = 1,
         "OSC 133 command block count");
      declare
         Block : constant Terminal.Core.Shell_Command_Block :=
           Terminal.Core.Shell_Command_Block_At (T, 1);
      begin
         Assert
           (Block.Has_Prompt and then Block.Has_Input and then Block.Has_Output
            and then Block.Complete,
            "OSC 133 command block phases");
         Assert
           (Block.Has_Exit_Status and then Block.Exit_Status = 17
            and then Block.Has_Duration
            and then Block.Duration_Milliseconds = 245,
            "OSC 133 command block result metadata");
      end;
   end;

   declare
      Notice : constant Terminal.Core.Notification_Request :=
        Terminal.Core.Notification (T);
   begin
      Assert
        (Notice.Pending
         and then Notice.Kind = Terminal.Core.Command_Completion
         and then Notice.Message.Text (1 .. Notice.Message.Length) =
           "Exit status 17",
         "OSC 133 completion creates an opt-in notification request");
   end;
   Terminal.Core.Clear_Notification (T);

   Terminal.Core.Feed (T, (1 => 16#07#), Feed_Status);
   declare
      Notice : constant Terminal.Core.Notification_Request :=
        Terminal.Core.Notification (T);
   begin
      Assert
        (Notice.Pending
         and then Notice.Kind = Terminal.Core.Terminal_Bell
         and then Notice.Bell_Count = 1,
         "BEL creates a bounded attention request");
   end;
   Terminal.Core.Clear_Notification (T);
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]99;i=build:d=0;Build finished" & ASCII.BEL
         & ASCII.ESC & "]99;i=build:p=body:e=1;RG9uZQ==" & ASCII.BEL),
      Feed_Status);
   declare
      Notice : constant Terminal.Core.Notification_Request :=
        Terminal.Core.Notification (T);
   begin
      Assert
        (Notice.Pending
         and then Notice.Kind = Terminal.Core.Desktop_Notification
         and then Notice.Title.Text (1 .. Notice.Title.Length) = "Build finished"
         and then Notice.Message.Text (1 .. Notice.Message.Length) = "Done",
         "OSC 99 assembles plain and base64 notification fields");
   end;
   Terminal.Core.Clear_Notification (T);
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "]9;Legacy notice" & ASCII.BEL), Feed_Status);
   Assert
     (Terminal.Core.Notification (T).Pending,
      "OSC 9 creates a legacy desktop notification");
   Terminal.Core.Clear_Notification (T);

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]9;4;1;42" & ASCII.BEL
         & ASCII.ESC & "]1337;SetBadgeFormat=YnVpbGQ=" & ASCII.BEL),
      Feed_Status);
   Assert
     (Terminal.Core.Progress (T).Kind = Terminal.Core.Normal_Progress
      and then Terminal.Core.Progress (T).Percent = 42,
      "OSC 9;4 exposes task progress");
   Assert
     (Terminal.Core.Badge (T).Length = 5
      and then Terminal.Core.Badge (T).Text (1 .. 5) = "build",
      "OSC 1337 exposes decoded badge text");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "]9;4;4;80" & ASCII.BEL), Feed_Status);
   Assert
     (Terminal.Core.Progress (T).Kind = Terminal.Core.Paused_Progress
      and then Terminal.Core.Progress (T).Percent = 80,
      "OSC 9;4 paused progress state");
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "]9;4;0" & ASCII.BEL), Feed_Status);
   Assert
     (Terminal.Core.Progress (T).Kind = Terminal.Core.No_Progress,
      "OSC 9;4 clears task progress");

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

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "c"), Feed_Status);
   declare
      Shell : constant Terminal.Core.Shell_Integration_Snapshot :=
        Terminal.Core.Shell_Integration (T);
   begin
      Assert
        (Shell.Working_Directory.Length = 0
         and then Shell.Prompt_Count = 0
         and then not Shell.Has_Exit_Status
         and then Terminal.Core.Shell_Command_Block_Count (T) = 0,
         "full reset clears shell integration metadata");
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
      Assert
        (Terminal.Core.Cell_Link_Equals
           (S, 1, 3, (others => <>)),
         "inactive snapshot links compare equal");
      Assert
        (Terminal.Core.Snapshot_Testing.Snapshot_Refresh_Is_Atomic
           (T, S, Force_Full => False, Successful_Interns => 1),
         "incremental snapshot refresh must be atomic on intern failure");
      Assert
        (Terminal.Core.Snapshot_Testing.Snapshot_Refresh_Is_Atomic
           (T, S, Force_Full => True, Successful_Interns => 1),
         "full snapshot refresh must be atomic on intern failure");
      Terminal.Core.Snapshot (T, S);
      Assert
        (Terminal.Core.Snapshot_Testing
           .Prepared_Hyperlink_Scratch_Is_Clear (S),
         "snapshot hyperlink scratch releases prepared references");
      Terminal.Core.Release (S);
   end;

   --  Force the private hyperlink interning table through a reclamation pass.
   --  The link retained by visible cells must remain valid while transient,
   --  never-rendered links are discarded.
   for N in 1 .. 1_100 loop
      Terminal.Core.Feed
        (T,
         To_Bytes
           (ASCII.ESC & "]8;;https://transient.test/"
            & Natural'Image (N) & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "OSC 8 hyperlink reclamation feed failed");
   end loop;
   Terminal.Core.Feed
     (T, To_Bytes (ASCII.ESC & "]8;;" & ASCII.ESC & "\"), Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "OSC 8 hyperlink reclamation close failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      H : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert
        (H.Link.Active
         and then H.Link.URI (1 .. H.Link.URI_Length) =
           "https://example.test",
         "hyperlink reclamation must preserve links retained by cells");
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
      To_Bytes (ASCII.ESC & "]52;c;/x==" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "invalid OSC 52 feed recovered");
   Assert
     (not Terminal.Core.Clipboard (T).Pending,
      "non-canonical OSC 52 Base64 padding bits are rejected");

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

end Core_OSC_Cases;
