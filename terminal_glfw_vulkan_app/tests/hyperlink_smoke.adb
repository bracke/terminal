with AUnit.Assertions;

with Terminal.App.Hyperlinks;
with Terminal.App.Selection;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Hyperlink_Smoke is
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
   begin
      Assert (Link.Active, "link should be active at linked cell");
      Assert (Link.URI_Length = 20, "link URI length");
      Assert
        (Link.URI (1 .. Link.URI_Length) = "https://example.test",
         "link URI");
      Assert (Link.ID_Length = 3, "link ID length");
      Assert (Link.ID (1 .. Link.ID_Length) = "abc", "link ID");
      Assert (not Plain.Active, "plain cell should not report link");
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
     (not Terminal.App.Hyperlinks.Supported_URI ("file:///tmp/x"),
      "file URI should not be opened by default");
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
   Assert
     (Terminal.App.Hyperlinks.Open_Command ("https://example.test")
      = "xdg-open 'https://example.test'",
      "open command");
   Assert
     (Terminal.App.Hyperlinks.Open_Command ("https://example.test/a b") = "",
      "open command should reject unsupported URI bytes");
   Assert
     (Terminal.App.Hyperlinks.Open_Command ("https://example.test/a'b")
      = "xdg-open 'https://example.test/a'\''b'",
      "open command should quote apostrophes");

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
        (Terminal.App.Hyperlinks.Link_Label (Unsupported) = "",
         "link label should ignore unsupported URI");
      Assert
        (Terminal.App.Hyperlinks.Status_Label (Unsupported) =
         "Unsupported link file:///tmp/x",
         "status label should expose unsupported URI safely");
      Assert
        (Terminal.App.Hyperlinks.Hover_Title ("Ada Terminal", Unsupported)
         = "Ada Terminal",
         "hover title should ignore unsupported URI");
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
           (Terminal.App.Hyperlinks.Command_Too_Long) =
         "Link command too long",
         "activation command too long label");
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
