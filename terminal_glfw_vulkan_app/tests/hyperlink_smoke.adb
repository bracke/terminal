with AUnit.Assertions;

with Terminal.App.Hyperlinks;
with Terminal.App.Platform_Launcher;
with Terminal.App.Platform_Launcher.Testing;
with Terminal.App.Selection;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Hyperlink_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.App.Platform_Launcher.Launch_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Launch_Status : Terminal.App.Platform_Launcher.Launch_Status;
   Started       : Boolean := False;
   Started_Program : String (1 .. 32) := (others => ' ');
   Started_Program_Length : Natural := 0;
   Started_URI : String (1 .. 64) := (others => ' ');
   Started_URI_Length : Natural := 0;
   Mock_Result : Terminal.App.Platform_Launcher.Launch_Status :=
     Terminal.App.Platform_Launcher.Opened;
   Mock_Raises : Boolean := False;

   procedure Mock_Start
     (Program : String;
      URI     : String;
      Status  : out Terminal.App.Platform_Launcher.Launch_Status) is
   begin
      Started := True;
      Started_Program_Length := Program'Length;
      Started_Program (1 .. Program'Length) := Program;
      Started_URI_Length := URI'Length;
      Started_URI (1 .. URI'Length) := URI;
      if Mock_Raises then
         raise Program_Error with "mock launcher failure";
      end if;
      Status := Mock_Result;
   end Mock_Start;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;
begin
   Terminal.App.Platform_Launcher.Testing.Dispatch
     ("/mock/xdg-open", "/mock/open", "https://example.test",
      Launch_Status, Mock_Start'Access);
   Assert
     (Started
      and then Started_Program (1 .. Started_Program_Length) =
        "/mock/xdg-open"
      and then Started_URI (1 .. Started_URI_Length) =
        "https://example.test"
      and then Launch_Status = Terminal.App.Platform_Launcher.Opened,
      "launcher dispatches the preferred executable");
   Started := False;
   Terminal.App.Platform_Launcher.Testing.Dispatch
     ("", "/mock/open", "mailto:a@example.test",
      Launch_Status, Mock_Start'Access);
   Assert
     (Started
      and then Started_Program (1 .. Started_Program_Length) = "/mock/open",
      "launcher dispatches the fallback executable");
   Started := False;
   Terminal.App.Platform_Launcher.Testing.Dispatch
     ("/mock/xdg-open", "",
      "https://example.test" & ASCII.NUL & ".invalid",
      Launch_Status, Mock_Start'Access);
   Assert
     (not Started
      and then Launch_Status = Terminal.App.Platform_Launcher.Launch_Failed,
      "launcher rejects an embedded nul before native dispatch");
   Started := False;
   Terminal.App.Platform_Launcher.Testing.Dispatch
     ("", "", "https://example.test", Launch_Status, Mock_Start'Access);
   Assert
     (not Started
      and then Launch_Status =
        Terminal.App.Platform_Launcher.Launcher_Unavailable,
      "launcher reports an unavailable executable without dispatching");
   Mock_Result := Terminal.App.Platform_Launcher.Launch_Failed;
   Terminal.App.Platform_Launcher.Testing.Dispatch
     ("/mock/xdg-open", "", "https://example.test",
      Launch_Status, Mock_Start'Access);
   Assert
     (Launch_Status = Terminal.App.Platform_Launcher.Launch_Failed,
      "launcher preserves an executor failure");
   Mock_Raises := True;
   Terminal.App.Platform_Launcher.Testing.Dispatch
     ("/mock/xdg-open", "", "https://example.test",
      Launch_Status, Mock_Start'Access);
   Assert
     (Launch_Status = Terminal.App.Platform_Launcher.Launch_Failed,
      "launcher maps executor exceptions to failure");
   Mock_Raises := False;
   Mock_Result := Terminal.App.Platform_Launcher.Opened;

   Assert
     (Terminal.App.Platform_Launcher.Testing.Child_Tracker_Admission_Valid,
      "child tracker enforces its admission limit");
   Assert
     (Terminal.App.Platform_Launcher.Testing.Child_Tracker_Recovery_Valid,
      "child tracker preserves quarantine and recovery state");
   Assert
     (Terminal.App.Platform_Launcher.Testing.Child_Tracker_Reservation_Valid,
      "child tracker cancels reservations without changing its load");
   Assert
     (Terminal.App.Platform_Launcher.Testing.Child_Tracker_Capacity_Valid,
      "child tracker enforces its hard tracking capacity");

   if Terminal.App.Platform_Launcher.Testing.Can_Track_Children then
      Terminal.App.Platform_Launcher.Testing.Launch_Direct
        ("/bin/true", "ignored", Launch_Status);
      Assert
        (Launch_Status = Terminal.App.Platform_Launcher.Opened
         and then Terminal.App.Platform_Launcher.Testing.Pending_Count = 1,
         "POSIX launcher starts and tracks a real child");
      for Attempt in 1 .. 1_000 loop
         Terminal.App.Platform_Launcher.Testing.Poll_Launches;
         exit when Terminal.App.Platform_Launcher.Testing.Pending_Count = 0;
         delay 0.001;
      end loop;
      Assert
        (Terminal.App.Platform_Launcher.Testing.Pending_Count = 0,
         "POSIX launcher reaps a completed child without blocking");
      Terminal.App.Platform_Launcher.Testing.Launch_Direct
        ("/definitely/missing/terminal-uri-launcher",
         "ignored",
         Launch_Status);
      Assert
        (Launch_Status = Terminal.App.Platform_Launcher.Launch_Failed
         and then Terminal.App.Platform_Launcher.Testing.Pending_Count = 0,
         "a failed POSIX spawn releases its child-registry reservation");
   else
      Terminal.App.Platform_Launcher.Testing.Launch_Direct
        ("shell",
         "https://example.test/"
           & Character'Val (16#F0#)
           & Character'Val (16#80#)
           & Character'Val (16#80#)
           & Character'Val (16#80#),
         Launch_Status);
      Assert
        (Launch_Status = Terminal.App.Platform_Launcher.Launch_Failed,
         "Windows launcher rejects malformed UTF-8 before shell dispatch");
   end if;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "hyperlink core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]8;id=abc;https://example.test" & ASCII.ESC & "\"
         & "x"
         & ASCII.ESC & "]8;;" & ASCII.ESC & "\"
         & "!"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "hyperlink feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Link : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At
          (S, (Row => 1, Col => 1));
      Plain : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At
          (S, (Row => 1, Col => 2));
      Equivalent : Terminal.Core.Hyperlink := Link;
   begin
      Assert (Link.Active, "link should be active at linked cell");
      Assert (Link.URI_Length = 20, "link URI length");
      Assert
        (Link.URI (1 .. Link.URI_Length) = "https://example.test",
         "link URI");
      Assert (Link.ID_Length = 3, "link ID length");
      Assert (Link.ID (1 .. Link.ID_Length) = "abc", "link ID");
      Assert (not Plain.Active, "plain cell should not report link");
      Equivalent.URI (Terminal.Core.Max_Hyperlink_URI_Length) := 'X';
      Equivalent.ID (Terminal.Core.Max_Hyperlink_ID_Length) := 'Y';
      Assert
        (Terminal.Core.Same_Hyperlink (Link, Equivalent)
         and then Terminal.Core.Cell_Link_Equals (S, 1, 1, Equivalent),
         "unused hyperlink buffer bytes do not affect logical identity");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "wide hyperlink initialize failed");
   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2 => Byte (Character'Pos (']')),
       3  => Byte (Character'Pos ('8')), 4 => Byte (Character'Pos (';')),
       5  => Byte (Character'Pos (';')),
       6  => Byte (Character'Pos ('h')),
       7  => Byte (Character'Pos ('t')),
       8  => Byte (Character'Pos ('t')),
       9  => Byte (Character'Pos ('p')),
       10 => Byte (Character'Pos (':')),
       11 => Byte (Character'Pos ('/')),
       12 => Byte (Character'Pos ('/')),
       13 => Byte (Character'Pos ('w')),
       14 => 16#1B#, 15 => Byte (Character'Pos ('\')),
       16 => 16#E4#, 17 => 16#B8#, 18 => 16#80#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "wide hyperlink feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Base : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At
          (S, (Row => 1, Col => 1));
      Continuation : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At
          (S, (Row => 1, Col => 2));
   begin
      Assert (Base.Active, "wide base should report link");
      Assert (Continuation.Active, "wide continuation should report link");
      Assert
        (Continuation.URI (1 .. Continuation.URI_Length) = "http://w",
         "wide continuation link URI");
      Terminal.Core.Release (S);
   end;

   Assert
     (Terminal.App.Hyperlinks.Supported_URI ("https://example.test"),
      "https URI should be supported");
   Assert
     (Terminal.App.Hyperlinks.Supported_URI ("http://example.test"),
      "http URI should be supported");
   Assert
     (Terminal.App.Hyperlinks.Supported_URI ("mailto:a@example.test"),
      "mailto URI should be supported");
   Assert
     (Terminal.App.Hyperlinks.Supported_URI ("HTTPS://example.test"),
      "URI scheme matching should be case-insensitive");
   Assert
     (Terminal.App.Hyperlinks.Supported_URI ("MailTo:a@example.test"),
      "mailto URI scheme matching should be case-insensitive");
   Assert
     (Terminal.App.Hyperlinks.Supported_URI ("file:///tmp/x"),
      "explicitly activated file URI should be supported");
   Assert
     (not Terminal.App.Hyperlinks.Supported_URI ("http://"),
      "bare http scheme should not be opened");
   Assert
     (not Terminal.App.Hyperlinks.Supported_URI ("https://"),
      "bare https scheme should not be opened");
   Assert
     (not Terminal.App.Hyperlinks.Supported_URI ("mailto:"),
      "bare mailto scheme should not be opened");
   Assert
     (not Terminal.App.Hyperlinks.Supported_URI ("https://example.test/a b"),
      "URI with spaces should not be opened");
   Assert
     (not Terminal.App.Hyperlinks.Supported_URI
        ("https://example.test/" & Character'Val (10) & "x"),
      "URI with control bytes should not be opened");

   Terminal.Core.Initialize (T, 2, 80, 100, Init);
   Assert (Init = Terminal.Core.Ok, "detected-link initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        ("see https://example.test/a." & ASCII.CR & ASCII.LF
         & "/tmp/file.adb:12"),
      Feed_Status);
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      URL : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At (S, (Row => 1, Col => 6));
      Path : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At (S, (Row => 2, Col => 2));
      Hints : Terminal.App.Hyperlinks.Hint_State;
   begin
      Assert
        (URL.Active
         and then URL.URI (1 .. URL.URI_Length) = "https://example.test/a",
         "plain URL detection trims sentence punctuation");
      Assert
        (Path.Active
         and then Path.URI (1 .. Path.URI_Length) = "file:///tmp/file.adb",
         "absolute path detection strips line suffix");
      Terminal.App.Hyperlinks.Begin_Hints (Hints, S);
      Assert
        (Terminal.App.Hyperlinks.Hints_Active (Hints)
         and then Terminal.App.Hyperlinks.Hint_Count (Hints) = 2,
         "keyboard hint scan finds detected links and paths");
      Terminal.App.Hyperlinks.Move_Hint (Hints, 1);
      declare
         Current : constant Terminal.Core.Hyperlink :=
           Terminal.App.Hyperlinks.Current_Hint_Link (Hints);
      begin
         Assert
           (Current.URI (1 .. Current.URI_Length) = "file:///tmp/file.adb",
            "keyboard hint navigation advances deterministically");
      end;
      Terminal.Core.Release (S);
   end;
   declare
      Left  : Terminal.Core.Hyperlink :=
        (Active     => True,
         URI_Length => 14,
         URI        => (1 .. Terminal.Core.Max_Hyperlink_URI_Length => ' '),
         ID_Length  => 1,
         ID         => (1 .. Terminal.Core.Max_Hyperlink_ID_Length => ' '));
      Right : Terminal.Core.Hyperlink := Left;
   begin
      Left.URI (1 .. Left.URI_Length) := "https://same/x";
      Left.ID (1) := 'a';
      Right.URI (1 .. Right.URI_Length) := "https://same/x";
      Right.ID (1) := 'a';
      Assert
        (Terminal.App.Hyperlinks.Same_Link (Left, Right),
         "same link should match");
      Right.URI (Right.URI_Length + 1) := 'x';
      Assert
        (Terminal.App.Hyperlinks.Same_Link (Left, Right),
         "same link ignores unused URI storage");
      Right.ID (1) := 'b';
      Assert
        (not Terminal.App.Hyperlinks.Same_Link (Left, Right),
         "different link id should not match");
   end;

   declare
      Link : Terminal.Core.Hyperlink :=
        (Active     => True,
         URI_Length => 20,
         URI        => (1 .. Terminal.Core.Max_Hyperlink_URI_Length => ' '),
         ID_Length  => 0,
         ID         => (1 .. Terminal.Core.Max_Hyperlink_ID_Length => ' '));
      Unsupported : Terminal.Core.Hyperlink := Link;
   begin
      Link.URI (1 .. Link.URI_Length) := "https://example.test";
      Assert
        (Terminal.App.Hyperlinks.Link_Label (Link) =
         "https://example.test",
         "link label should expose supported URI");
      Assert
        (Terminal.App.Hyperlinks.Status_Label (Link) =
         "Open https://example.test",
         "status label should describe openable URI");
      Assert
        (Terminal.App.Hyperlinks.Hover_Title ("Ada Terminal", Link)
         = "Ada Terminal - https://example.test",
         "hover title should expose supported URI");

      Unsupported.URI_Length := 13;
      Unsupported.URI (1 .. Unsupported.URI_Length) := "file:///tmp/x";
      Assert
        (Terminal.App.Hyperlinks.Link_Label (Unsupported) = "file:///tmp/x",
         "link label should expose supported file URI");
      Assert
        (Terminal.App.Hyperlinks.Status_Label (Unsupported) =
         "Open file:///tmp/x",
         "status label should expose supported file URI safely");
      Assert
        (Terminal.App.Hyperlinks.Hover_Title ("Ada Terminal", Unsupported)
         = "Ada Terminal - file:///tmp/x",
         "hover title should expose supported file URI");
      Assert
        (Terminal.App.Hyperlinks.Hover_Title ("", Link)
         = "Ada Terminal - https://example.test",
         "empty base title should use app name");
      Assert
        (Terminal.App.Hyperlinks.Activation_Status_Label
           (Terminal.App.Hyperlinks.Ok) = "Link opened",
         "activation ok label");
      Assert
        (Terminal.App.Hyperlinks.Activation_Status_Label
           (Terminal.App.Hyperlinks.No_Link) = "No link under pointer",
         "activation no link label");
      Assert
        (Terminal.App.Hyperlinks.Activation_Status_Label
           (Terminal.App.Hyperlinks.Unsupported_URI) =
         "Unsupported link target",
         "activation unsupported URI label");
      Assert
        (Terminal.App.Hyperlinks.Activation_Status_Label
           (Terminal.App.Hyperlinks.Launch_Failed) =
         "Link launcher failed",
         "activation launch failed label");
      Assert
        (Terminal.App.Hyperlinks.Activation_Status_Label
           (Terminal.App.Hyperlinks.Launch_Failed)'Length <=
         Terminal.App.Hyperlinks.Max_Status_Label_Length,
         "activation status label should be bounded");
   end;

   declare
      Long_Link : Terminal.Core.Hyperlink :=
        (Active     => True,
         URI_Length => Terminal.Core.Max_Hyperlink_URI_Length,
         URI        => (others => 'a'),
         ID_Length  => 0,
         ID         => (1 .. Terminal.Core.Max_Hyperlink_ID_Length => ' '));
      Label : String
        (1 .. Terminal.App.Hyperlinks.Max_Link_Label_Length);
   begin
      Long_Link.URI (1 .. 8) := "https://";
      Label := Terminal.App.Hyperlinks.Link_Label (Long_Link);
      Assert
        (Label'Length = Terminal.App.Hyperlinks.Max_Link_Label_Length,
         "link label should be bounded");
      Assert
        (Label (1 .. 8) = "https://",
         "bounded link label should preserve URI prefix");
   end;
end Hyperlink_Smoke;
