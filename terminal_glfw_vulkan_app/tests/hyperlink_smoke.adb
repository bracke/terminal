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
     (not Terminal.App.Hyperlinks.Supported_URI ("file:///tmp/x"),
      "file URI should not be opened by default");
   Assert
     (Terminal.App.Hyperlinks.Open_Command ("https://example.test")
      = "xdg-open 'https://example.test'",
      "open command");
   Assert
     (Terminal.App.Hyperlinks.Open_Command ("https://example.test/a'b")
      = "xdg-open 'https://example.test/a'\''b'",
      "open command should quote apostrophes");
end Hyperlink_Smoke;
