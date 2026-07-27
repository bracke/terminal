with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App;
with Terminal.App.Clipboard_OSC52;
with Terminal.App.Input_Map;
with Terminal.App.Queues;
with Terminal.App.Render_Policy;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.PTY.POSIX;

procedure App_Profile_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Clipboard_Operation;
   use type Terminal.Core.Clipboard_Target;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Profile : constant Terminal.App.Terminal_Profile := Terminal.App.Profile;

   package GI renames GLFW_Vulkan.Input;
   package IM renames Terminal.App.Input_Map;
   package Q renames Terminal.App.Queues;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Assert_Bytes
     (Actual  : Q.Byte_Chunk;
      Expect  : Byte_Array;
      Message : String)
   is
   begin
      Assert (Actual.Length = Expect'Length, Message & " length");
      for I in Expect'Range loop
         Assert
           (Actual.Data (I - Expect'First + 1) = Expect (I),
            Message & " byte" & Natural'Image (I - Expect'First + 1));
      end loop;
   end Assert_Bytes;
begin
   Assert
     (Terminal.App.Term_Name = "xterm-256color",
      "terminal TERM identity");
   Assert
     (Terminal.App.Color_Term = "truecolor",
      "terminal COLORTERM identity");
   Assert
     (Terminal.App.Term_Name = Terminal.PTY.POSIX.Term_Name,
      "app and PTY TERM identity should match");
   Assert
     (Terminal.App.Color_Term = Terminal.PTY.POSIX.Color_Term,
      "app and PTY COLORTERM identity should match");
   Assert (Profile.Bracketed_Paste, "profile bracketed paste");
   Assert (Profile.Focus_Reporting, "profile focus reporting");
   Assert (Profile.Xterm_Mouse_Reporting, "profile xterm mouse reporting");
   Assert (Profile.SGR_Mouse_Coordinates, "profile SGR mouse coordinates");
   Assert (Profile.Synchronized_Update, "profile synchronized update");
   Assert (Profile.OSC52_Clipboard, "profile OSC 52 clipboard");
   Assert
     (Profile.OSC52_App_Local_Selections,
      "profile OSC 52 app-local selections");
   Assert (Profile.OSC8_Hyperlinks, "profile OSC 8 hyperlinks");
   Assert (Profile.Truecolor, "profile truecolor");
   Assert (Profile.Tmux_DCS_Passthrough, "profile tmux DCS passthrough");
   Assert
     (Terminal.App.Profile_Status_Label (Profile) =
      "xterm-256color truecolor profile; OSC 52 selections app-local",
      "profile status label");
   Assert
     (Terminal.App.Profile_Status_Label (Profile)'Length <=
      Terminal.App.Max_Status_Label_Length,
      "profile status label should be bounded");
   Assert
     (Terminal.App.Multiplexer_Status_Label (Profile) =
      "tmux DCS passthrough enabled; full multiplexer sessions postponed",
      "profile multiplexer status label");
   Assert
     (Terminal.App.Multiplexer_Status_Label (Profile)'Length <=
      Terminal.App.Max_Status_Label_Length,
      "profile multiplexer status label should be bounded");

   if Profile.Bracketed_Paste then
      declare
         Modes : Terminal.Core.Mode_Snapshot;
         Chunk : Q.Byte_Chunk;
      begin
         Modes.Bracketed_Paste := True;
         IM.Encode_Paste_Text ("x", Modes, Chunk);
         Assert_Bytes
           (Chunk,
            To_Bytes (ASCII.ESC & "[200~x" & ASCII.ESC & "[201~"),
            "profile bracketed paste behavior");
      end;
   end if;

   if Profile.Focus_Reporting then
      declare
         Modes : Terminal.Core.Mode_Snapshot;
         Chunk : Q.Byte_Chunk;
      begin
         Modes.Focus_Reporting := True;
         IM.Encode_Focus ((Focused => True), Modes, Chunk);
         Assert_Bytes
           (Chunk, To_Bytes (ASCII.ESC & "[I"), "profile focus behavior");
      end;
   end if;

   if Profile.Xterm_Mouse_Reporting and then Profile.SGR_Mouse_Coordinates then
      declare
         Modes : Terminal.Core.Mode_Snapshot;
         Chunk : Q.Byte_Chunk;
      begin
         Modes.Mouse_Button := True;
         Modes.Mouse_SGR := True;
         Assert
           (IM.Mouse_Reporting_Enabled (Modes),
            "profile mouse reporting behavior");
         IM.Encode_Mouse_Button
           ((Button     => GI.Left,
             Raw_Button => 0,
             Action     => GI.Press,
             Modifiers  => (others => False),
             X          => 0.0,
             Y          => 0.0),
            Modes,
            Row   => 2,
            Col   => 3,
            Chunk => Chunk);
         Assert_Bytes
           (Chunk, To_Bytes (ASCII.ESC & "[<0;3;2M"),
            "profile SGR mouse behavior");
      end;
   end if;

   if Profile.Synchronized_Update then
      declare
         T : Terminal.Core.Terminal;
         Init : Terminal.Core.Initialize_Status;
         Feed : Terminal.Core.Feed_Status;
         Modes : Terminal.Core.Mode_Snapshot;
      begin
         Terminal.Core.Initialize (T, 1, 1, 10, Init);
         Assert (Init = Terminal.Core.Ok, "profile sync initialize");
         Terminal.Core.Feed
           (T, To_Bytes (ASCII.ESC & "[?2026h"), Feed);
         Assert (Feed = Terminal.Core.Ok, "profile sync feed");
         Modes := Terminal.Core.Modes (T);
         Assert (Modes.Synchronized_Update, "profile sync core mode");
         Assert
           (Terminal.App.Render_Policy.Should_Defer_Render
              (Modes, 0, False, False),
            "profile sync render defer");
         Assert
           (not Terminal.App.Render_Policy.Should_Defer_Render
              (Modes, 0, False, True),
            "profile sync local redraw override");
      end;
   end if;

   if Profile.Truecolor then
      declare
         T : Terminal.Core.Terminal;
         Init : Terminal.Core.Initialize_Status;
         Feed : Terminal.Core.Feed_Status;
      begin
         Terminal.Core.Initialize (T, 1, 1, 10, Init);
         Assert (Init = Terminal.Core.Ok, "profile truecolor initialize");
         Terminal.Core.Feed
           (T, To_Bytes (ASCII.ESC & "[38;2;1;2;3mX"), Feed);
         Assert (Feed = Terminal.Core.Ok, "profile truecolor feed");
         declare
            Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snap, 1, 1);
         begin
            Assert
              (Cell.Style.Foreground.Kind = Terminal.Core.RGB,
               "profile truecolor foreground kind");
            Assert
              (Cell.Style.Foreground.R = 1
               and then Cell.Style.Foreground.G = 2
               and then Cell.Style.Foreground.B = 3,
               "profile truecolor foreground value");
            Terminal.Core.Release (Snap);
         end;
      end;
   end if;

   if Profile.OSC52_Clipboard or else Profile.OSC8_Hyperlinks then
      declare
         T : Terminal.Core.Terminal;
         Init : Terminal.Core.Initialize_Status;
         Feed : Terminal.Core.Feed_Status;
      begin
         Terminal.Core.Initialize (T, 1, 2, 10, Init);
         Assert (Init = Terminal.Core.Ok, "profile core initialize");

         if Profile.OSC52_Clipboard then
            declare
               Clipboard_Cap : constant
                 Terminal.App.Clipboard_OSC52.Target_Capability :=
                   Terminal.App.Clipboard_OSC52.Capability
                     (Terminal.Core.Clipboard_Clipboard);
               Primary_Cap : constant
                 Terminal.App.Clipboard_OSC52.Target_Capability :=
                   Terminal.App.Clipboard_OSC52.Capability
                     (Terminal.Core.Clipboard_Primary);
               Selection_Cap : constant
                 Terminal.App.Clipboard_OSC52.Target_Capability :=
                   Terminal.App.Clipboard_OSC52.Capability
                     (Terminal.Core.Clipboard_Selection);
            begin
               Assert
                 (Clipboard_Cap.Native_Backing,
                  "profile OSC 52 clipboard native capability");
               Assert
                 (not Primary_Cap.Native_Backing
                  and then Primary_Cap.App_Local_Backing,
                  "profile OSC 52 primary app-local capability");
               Assert
                 (not Selection_Cap.Native_Backing
                  and then Selection_Cap.App_Local_Backing,
                  "profile OSC 52 selection app-local capability");
            end;

            Terminal.Core.Feed
              (T, To_Bytes (ASCII.ESC & "]52;c;?" & ASCII.BEL), Feed);
            Assert (Feed = Terminal.Core.Ok, "profile OSC 52 feed");
            declare
               Clip : constant Terminal.Core.Clipboard_Request :=
                 Terminal.Core.Clipboard (T);
            begin
               Assert (Clip.Pending, "profile OSC 52 pending");
               Assert
                 (Clip.Operation = Terminal.Core.Clipboard_Query,
                  "profile OSC 52 query operation");
               Assert
                 (Clip.Target = Terminal.Core.Clipboard_Clipboard,
                  "profile OSC 52 clipboard target");
            end;
            Terminal.Core.Clear_Clipboard (T);
         end if;

         if Profile.OSC8_Hyperlinks then
            Terminal.Core.Feed
              (T,
               To_Bytes
                 (ASCII.ESC & "]8;;https://example.test" & ASCII.ESC & "\x"),
               Feed);
            Assert (Feed = Terminal.Core.Ok, "profile OSC 8 feed");
            declare
               Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snap, 1, 1);
            begin
               Assert (Cell.Link.Active, "profile OSC 8 cell link");
               Assert
                 (Cell.Link.URI (1 .. Cell.Link.URI_Length) =
                  "https://example.test",
                  "profile OSC 8 URI");
               Terminal.Core.Release (Snap);
            end;
         end if;
      end;
   end if;

   if Profile.Tmux_DCS_Passthrough then
      declare
         T : Terminal.Core.Terminal;
         Init : Terminal.Core.Initialize_Status;
         Feed : Terminal.Core.Feed_Status;
      begin
         Terminal.Core.Initialize (T, 1, 1, 10, Init);
         Assert (Init = Terminal.Core.Ok, "profile tmux initialize");
         Terminal.Core.Feed
           (T,
            To_Bytes
              (ASCII.ESC & "Ptmux;"
               & ASCII.ESC & ASCII.ESC & "]0;mux"
               & ASCII.ESC & ASCII.ESC & "\"
               & ASCII.ESC & "\"),
            Feed);
         Assert (Feed = Terminal.Core.Ok, "profile tmux feed");
         declare
            Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
            D : constant Terminal.Core.Diagnostic_Snapshot :=
              Terminal.Core.Diagnostics (T);
         begin
            Assert (Title.Length = 3, "profile tmux title length");
            Assert (Title.Text (1 .. Title.Length) = "mux", "profile tmux title");
            Assert
              (D.Multiplexer_Passthrough = 1,
               "profile tmux passthrough diagnostic");
            Assert
              (Terminal.App.Multiplexer_Diagnostic_Label
                 ((others => <>)) = "",
               "empty multiplexer diagnostic label");
            Assert
              (Terminal.App.Multiplexer_Diagnostic_Label (D) =
               "tmux passthrough handled 1 sequence",
               "profile tmux passthrough diagnostic label");
            Assert
              (Terminal.App.Multiplexer_Diagnostic_Label (D)'Length <=
               Terminal.App.Max_Status_Label_Length,
               "profile tmux passthrough diagnostic label should be bounded");
         end;
      end;
   end if;
end App_Profile_Smoke;
