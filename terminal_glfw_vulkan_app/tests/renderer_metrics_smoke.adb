with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Hyperlinks;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;

procedure Renderer_Metrics_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Render_Model.Text_Run_Direction;
   use type Terminal.App.Render_Model.Text_Run_Kind;
   use type Terminal.App.Render_Model.Text_Run_Script;
   use type Terminal.App.Render_Model.Text_Run_Shape_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   R      : Terminal.App.Renderer.Renderer;
   Status : Terminal.App.Renderer.Init_Status;
   T      : Terminal.Core.Terminal;
   Core_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count);
   begin
      for I in Result'Range loop
         Result (I) := Ch;
      end loop;
      return Result;
   end Repeat_Char;

   procedure Assert_Close
     (Actual  : Float;
      Expected : Float;
      Message  : String)
   is
      Diff : constant Float := abs (Actual - Expected);
   begin
      Assert (Diff < 0.001, Message);
   end Assert_Close;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer initialize failed");
   Assert
     (Terminal.App.Renderer.Cell_Height (R) >= 16,
      "cell height should keep at least the requested pixel size");
   Assert
     (Terminal.App.Renderer.Cell_Width (R) > 8,
      "cell width should include measured glyph advance and breathing room");

   declare
      Diagnostics : Terminal.App.Renderer.Renderer_Diagnostics :=
        (others => <>);
   begin
      Assert
        (Terminal.App.Renderer.Color_Emoji_Status_Label (Diagnostics) = "",
         "empty color emoji status label");
      Assert
        (Terminal.App.Renderer.Paragraph_Bidi_Status_Label (Diagnostics) = "",
         "empty paragraph BiDi status label");
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics) = "",
         "empty image status label");

      Diagnostics.Last_Color_Emoji_Fallback_Count := 1;
      Assert
        (Terminal.App.Renderer.Color_Emoji_Status_Label (Diagnostics) =
         "Color emoji rendered with monochrome fallback",
         "color emoji fallback status label");

      Diagnostics.Last_Paragraph_Bidi_Fallback_Count := 1;
      Assert
        (Terminal.App.Renderer.Paragraph_Bidi_Status_Label (Diagnostics) =
         "Paragraph BiDi reordering not applied",
         "paragraph BiDi fallback status label");
   end;

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core initialize failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 3, "expected background, cell, cursor");
      Assert
        (Frame.Width =
           Terminal.App.Renderer.Cell_Width (R)
           + Terminal.App.Renderer.Content_Margin * 2,
         "frame width should include horizontal content margins");
      Assert
        (Frame.Height =
           Terminal.App.Renderer.Cell_Height (R)
           + Terminal.App.Renderer.Content_Margin * 2,
         "frame height should include vertical content margins");
      Assert
        (Frame.Rectangles (2).X = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should be inset horizontally");
      Assert
        (Frame.Rectangles (2).Y = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should be inset vertically");
      Assert
        (Frame.Rectangles (3).Height <= Float (Terminal.App.Renderer.Cell_Height (R)),
         "cursor block should fit within the terminal cell");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gf=32,a=T;AAAA" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "kitty graphics feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Diagnostics.Last_Image_Count = 1, "graphics image diagnostic count");
      Assert
        (Diagnostics.Last_Image_Protocol = Terminal.App.Render_Model.Image_Kitty,
         "graphics image diagnostic protocol");
      Assert
        (Diagnostics.Last_Image_Width =
         Terminal.App.Renderer.Cell_Width (R) * 6,
         "graphics image diagnostic width");
      Assert
        (Diagnostics.Last_Image_Height =
         Terminal.App.Renderer.Cell_Height (R) * 3,
         "graphics image diagnostic height");
      Assert
        (Diagnostics.Last_Image_Payload_Length = 14,
         "graphics image diagnostic payload length");
      Assert
        (Diagnostics.Last_Image_Payload_Preview_Complete,
         "graphics image diagnostic payload preview complete");
      Assert
        (Diagnostics.Last_Image_Encoded_Preview_Length = 4,
         "graphics image diagnostic encoded preview length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 3,
         "graphics image diagnostic decoded preview length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 0
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 0
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 0,
         "graphics image diagnostic decoded preview bytes");
      Assert
        (Diagnostics.Last_Image_Preview_Decode_Complete,
         "graphics image diagnostic preview decode complete");
      Assert
        (Diagnostics.Last_Image_Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Ok,
         "graphics image diagnostic preview decode status");
      Assert
        (Diagnostics.Last_Image_Placeholder,
         "graphics image diagnostic placeholder flag");
      Assert (Frame.Image_Count = 1, "graphics image command count");
      Assert
        (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty,
         "graphics image protocol");
      Assert (Frame.Images (1).Payload_Length = 14, "graphics payload length");
      Assert
        (Frame.Images (1).Payload_Preview_Complete,
         "graphics payload preview complete");
      Assert
        (Frame.Images (1).Encoded_Preview_Length = 4,
         "graphics encoded preview length");
      Assert
        (Frame.Images (1).Decoded_Preview_Length = 3,
         "graphics decoded preview length");
      Assert
        (Frame.Images (1).Decoded_Preview_Bytes (1) = 0
         and then Frame.Images (1).Decoded_Preview_Bytes (2) = 0
         and then Frame.Images (1).Decoded_Preview_Bytes (3) = 0,
         "graphics decoded preview bytes");
      Assert
        (Frame.Images (1).Preview_Decode_Complete,
         "graphics preview decode complete");
      Assert
        (Frame.Images (1).Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Ok,
         "graphics preview decode status");
      Assert
         (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
            "image kitty size="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R) * 6)
         & "x"
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R) * 3)
         & " payload=14 payload-complete preview=3/4 bytes=000000 placeholder decoded",
         "graphics image diagnostic status label");
      Assert
        (Frame.Images (1).Width =
         Float (Terminal.App.Renderer.Cell_Width (R) * 6),
         "graphics placeholder parsed width");
      Assert
        (Frame.Images (1).Height =
         Float (Terminal.App.Renderer.Cell_Height (R) * 3),
         "graphics placeholder parsed height");
   end;

   declare
      Payload : constant String := "Gf=32,s=1,v=1,c=1,r=1;/wAA/w==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "raw kitty graphics feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "raw graphics image diagnostic pixel metadata");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "raw graphics image should be textured");
         Assert
           (Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1,
            "raw graphics command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Encoded_Source_Bytes /= null,
            "raw graphics command should use encoded row source");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 3) = 16#FF#,
            "raw graphics encoded row source bytes");
         Assert
           (not Frame.Images (1).Decoded_Bytes_Owned,
            "raw graphics command should not own decoded frame bytes");
         Assert
           (Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "raw graphics command should carry decoded row stride");
         Assert
           (not Frame.Images (1).Placeholder,
            "raw graphics command should be textured");
         Assert
           (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
            "image kitty size="
            & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R))
            & "x"
            & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R))
            & " pixels=1x1 format=32 payload="
            & Trimmed_Natural (Diagnostics.Last_Image_Payload_Length)
            & " payload-complete preview=4/8 bytes=FF0000FF textured decoded",
            "raw graphics image diagnostic status label");
      end;
   end;

   declare
      Store_Payload : constant String :=
        "Gf=32,i=77,s=1,v=1,c=1,r=1;/wAA/w==";
      Place_Payload : constant String := "Gi=77,a=p,c=2,r=1;";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Store_Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "kitty object store feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "kitty object store render failed");

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Frame.Images (1).Decoded_Bytes /= null
            and then not Frame.Images (1).Decoded_Bytes_Owned,
            "kitty object store frame should borrow transferred object bytes");
      end;

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Place_Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "kitty object placement feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "kitty object placement render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "kitty object placement diagnostic pixel metadata");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "kitty object placement should be textured");
         Assert
           (Frame.Images (1).Width =
            Float (Terminal.App.Renderer.Cell_Width (R) * 2)
            and then Frame.Images (1).Height =
              Float (Terminal.App.Renderer.Cell_Height (R)),
            "kitty object placement dimensions");
         Assert
           (Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Byte_Length = 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Bytes (1) = 16#FF#
            and then Frame.Images (1).Decoded_Bytes (2) = 16#00#
            and then Frame.Images (1).Decoded_Bytes (3) = 16#00#
            and then Frame.Images (1).Decoded_Bytes (4) = 16#FF#,
            "kitty object placement decoded bytes");
         Assert
           (not Frame.Images (1).Decoded_Bytes_Owned,
            "kitty object placement should borrow stored decoded bytes");
         Assert
           (not Frame.Images (1).Placeholder,
            "kitty object placement command should be textured");
      end;
   end;

   for ID in 100 .. 120 loop
      declare
         Payload : constant String :=
           "Gf=32,i="
           & Trimmed_Natural (ID)
           & ",s=1,v=1,c=1,r=1;/wAA/w==";
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
            Feed_Status);
         Assert
           (Feed_Status = Terminal.Core.Ok,
            "unbounded kitty object feed failed");

         declare
            Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
         begin
            Terminal.App.Renderer.Render (R, Snap, Render_Status);
            Terminal.Core.Release (Snap);
         end;
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "unbounded kitty object render failed");
      end;
   end loop;

   declare
      Place_Payload : constant String := "Gi=100,a=p,c=3,r=1;";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Place_Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "unbounded kitty object placement feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "unbounded kitty object placement render failed");

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Frame.Images (1).Width =
            Float (Terminal.App.Renderer.Cell_Width (R) * 3)
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Decoded_Byte_Length = 4
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Decoded_Bytes (1) = 16#FF#
            and then Frame.Images (1).Decoded_Bytes (4) = 16#FF#
            and then not Frame.Images (1).Placeholder,
            "unbounded kitty object placement should keep first stored id");
         Assert
           (not Frame.Images (1).Decoded_Bytes_Owned,
            "unbounded kitty object placement should borrow stored bytes");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gi=100,a=d;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "kitty object delete feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "kitty object delete render failed");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "kitty object delete should not emit an image command");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gi=100,a=p,c=1,r=1;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "deleted kitty object placement feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "deleted kitty object placement render failed");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Placeholder,
      "deleted kitty object placement should fall back to placeholder");

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Ga=d;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "kitty object delete-all feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "kitty object delete-all render failed");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
      "kitty object delete-all should not emit an image command");

   declare
      Payload : constant String := "Gf=24,s=1,v=1,c=1,r=1;/wAA";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "raw RGB kitty graphics feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "raw RGB graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 24
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "raw RGB graphics image diagnostic pixel metadata");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "raw RGB graphics image should be textured");
         Assert
           (Frame.Images (1).Raw_Format = 24
            and then Frame.Images (1).Decoded_Byte_Length = 3
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 3
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null,
            "raw RGB graphics command encoded source metadata");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 1) = 16#00#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 2) = 16#00#,
            "raw RGB graphics encoded row source bytes");
         Assert
           (not Frame.Images (1).Placeholder,
            "raw RGB graphics command should be textured");
      end;
   end;

   declare
      First_Chunk  : constant String := "Gf=32,s=2,v=1,c=2,r=1,m=1;/w";
      Middle_Chunk : constant String := "Gm=1;AA/w";
      Last_Chunk   : constant String := "Gm=0;AA//8=";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & First_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked raw kitty first chunk feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked raw kitty first render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked raw kitty first chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Middle_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked raw kitty middle chunk feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked raw kitty middle render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked raw kitty middle chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Last_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked raw kitty final chunk feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked raw kitty final render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 2
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "chunked raw kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 8,
            "chunked raw kitty decoded byte length");
         Assert
         (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (5) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (6) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (7) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (8) = 16#FF#,
            "chunked raw kitty decoded bytes");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "chunked raw kitty image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 2
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null,
            "chunked raw kitty command encoded source metadata");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 7) = 16#FF#,
            "chunked raw kitty encoded row source bytes");
         Assert
           (not Frame.Images (1).Placeholder,
            "chunked raw kitty command should be textured");
      end;
   end;

   declare
      Segment_Count : constant Natural := 64;
   begin
      for I in 1 .. Segment_Count loop
         declare
            Prefix : constant String :=
              (if I = 1 then "Gf=32,s=48,v=1,c=12,r=1,m=1;"
               elsif I = Segment_Count then "Gm=0;"
               else "Gm=1;");
         begin
            Terminal.Core.Feed
              (T,
               To_Bytes
                 (ASCII.ESC & "_" & Prefix & "AAAA" & ASCII.ESC & "\"),
               Feed_Status);
            Assert
              (Feed_Status = Terminal.Core.Ok,
               "many-segment kitty chunk feed failed");

            declare
               Snap : Terminal.Core.Render_Snapshot :=
                 Terminal.Core.Snapshot (T);
            begin
               Terminal.App.Renderer.Render (R, Snap, Render_Status);
               Terminal.Core.Release (Snap);
            end;
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "many-segment kitty chunk render failed");

            if I < Segment_Count then
               Assert
                 (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
                  "many-segment kitty chunk should wait for final segment");
            end if;
         end;
      end loop;

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 48
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "many-segment kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Encoded_Preview_Length = Segment_Count * 4,
            "many-segment kitty encoded length should come from segments");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "many-segment kitty image should be textured");
         Assert
           (Frame.Images (1).Decoded_Byte_Length = 48 * 4
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null,
            "many-segment kitty command should retain encoded row source");
         Assert
           (not Frame.Images (1).Placeholder,
            "many-segment kitty command should be textured");
      end;
   end;

   declare
      Width          : constant Natural := 450;
      Height         : constant Natural := 300;
      Decoded_Length : constant Natural := Width * Height * 4;
      Encoded_Length : constant Natural := Decoded_Length / 3 * 4;
      Chunk_Length   : constant Natural := 120_000;
      Sent           : Natural := 0;

      procedure Feed_Chunk
        (Text    : String;
         Message : String;
         Final   : Boolean)
      is
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes (ASCII.ESC & "_" & Text & ASCII.ESC & "\"),
            Feed_Status);
         Assert (Feed_Status = Terminal.Core.Ok, Message & " feed failed");

         declare
            Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
         begin
            Terminal.App.Renderer.Render (R, Snap, Render_Status);
            Terminal.Core.Release (Snap);
         end;
         Assert (Render_Status = Terminal.App.Renderer.Ok, Message & " render failed");
         if not Final then
            Assert
              (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
               Message & " should wait for final chunk");
         end if;
      end Feed_Chunk;
   begin
      Feed_Chunk
        ("Gf=32,s=450,v=300,c=40,r=20,m=1;"
         & Repeat_Char ('A', Chunk_Length),
         "large chunked raw kitty first chunk",
         False);
      Sent := Sent + Chunk_Length;

      while Sent + Chunk_Length < Encoded_Length loop
         Feed_Chunk
           ("Gm=1;" & Repeat_Char ('A', Chunk_Length),
            "large chunked raw kitty middle chunk",
            False);
         Sent := Sent + Chunk_Length;
      end loop;

      Feed_Chunk
        ("Gm=0;" & Repeat_Char ('A', Encoded_Length - Sent),
         "large chunked raw kitty final chunk",
         True);

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = Width
            and then Diagnostics.Last_Image_Pixel_Height = Height,
            "large chunked raw kitty image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large chunked raw kitty decoded diagnostics preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "large chunked raw kitty payload should be complete");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "large chunked raw kitty image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = Width
            and then Frame.Images (1).Pixel_Height = Height
            and then Frame.Images (1).Decoded_Byte_Length = Decoded_Length
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large chunked raw kitty command should retain encoded row source");
         Assert
           (not Frame.Images (1).Placeholder,
            "large chunked raw kitty command should be textured");
      end;
   end;

   declare
      Payload : constant String :=
        "Gf=32,s=33,v=32,c=33,r=32;" & Repeat_Char ('A', 5632);
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "large raw kitty graphics feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "large raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 33
            and then Diagnostics.Last_Image_Pixel_Height = 32,
            "large raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large raw graphics decoded preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "large raw graphics payload should fit render buffer");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "large raw graphics image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 33
            and then Frame.Images (1).Pixel_Height = 32
            and then Frame.Images (1).Decoded_Byte_Length = 33 * 32 * 4
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "large raw graphics command encoded source metadata");
         Assert
           (not Frame.Images (1).Placeholder,
            "large raw graphics command should be textured");
      end;
   end;

   declare
      Payload : constant String :=
        "Gf=32,s=129,v=128,c=40,r=20;" & Repeat_Char ('A', 88064);
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "over-64KiB raw kitty graphics feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "over-64KiB raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 129
            and then Diagnostics.Last_Image_Pixel_Height = 128,
            "over-64KiB raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length =
            Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics decoded preview length");
         Assert
           (Diagnostics.Last_Image_Payload_Preview_Complete,
            "over-64KiB raw graphics payload should fit render buffer");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "over-64KiB raw graphics image should be textured");
         Assert
           (Frame.Images (1).Pixel_Width = 129
            and then Frame.Images (1).Pixel_Height = 128
            and then Frame.Images (1).Decoded_Byte_Length = 129 * 128 * 4
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_Raw_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null
            and then Frame.Images (1).Decoded_Preview_Length =
              Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length,
            "over-64KiB raw graphics command encoded source metadata");
         Assert
           (not Frame.Images (1).Placeholder,
            "over-64KiB raw graphics command should be textured");
      end;
   end;

   declare
      Payload : constant String :=
        "Gf=32,s=513,v=512,c=40,r=20;AAAA";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "oversized raw kitty graphics feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "oversized raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 513
            and then Diagnostics.Last_Image_Pixel_Height = 512,
            "oversized raw graphics image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Placeholder,
            "oversized raw graphics image should fall back to placeholder");
         Assert
           (Diagnostics.Last_Image_Decode_Status =
            Terminal.App.Render_Model.Image_Decode_Preview_Truncated,
            "oversized raw graphics image diagnostic decode status");
         Assert
           (not Diagnostics.Last_Image_Preview_Decode_Complete,
            "oversized raw graphics image should not report decode complete");
         Assert
           (Frame.Images (1).Placeholder
            and then Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_None,
            "oversized raw graphics command should not expose decoded source");
      end;
   end;

   declare
      Payload : constant String :=
        "File=name=pixel.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "]1337;" & Payload & ASCII.BEL),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "iTerm2 PNG image feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "iTerm2 PNG image render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_ITerm2,
            "iTerm2 PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "iTerm2 PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "iTerm2 PNG image decoded byte length");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "iTerm2 PNG image first RGBA pixel");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "iTerm2 PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_ITerm2
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "iTerm2 PNG image command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_PNG_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null,
            "iTerm2 PNG image command should retain encoded row source");
         Assert
           (not Frame.Images (1).Placeholder,
            "iTerm2 PNG image command should be textured");
      end;
   end;

   declare
      Payload : constant String :=
        "Gf=100,a=T,c=1,r=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "kitty PNG image feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "kitty PNG image render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_Kitty,
            "kitty PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "kitty PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "kitty PNG image decoded byte length");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "kitty PNG image first RGBA pixel");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "kitty PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty
            and then Frame.Images (1).Raw_Format = 32
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "kitty PNG image command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_PNG_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null,
            "kitty PNG image command should retain encoded row source");
         Assert
           (not Frame.Images (1).Placeholder,
            "kitty PNG image command should be textured");
      end;
   end;

   declare
      First_Chunk : constant String :=
        "Gf=100,c=1,r=1,m=1;iVBORw0KGgoAAAANSUhEUgAA";
      Middle_Chunk : constant String :=
        "Gm=1;AAEAAAABCAIAAACQd1PeAAAA";
      Last_Chunk : constant String :=
        "Gm=0;DUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & First_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG first chunk feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG first render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked kitty PNG first chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Middle_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG middle chunk feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG middle render failed");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Image_Count = 0,
         "chunked kitty PNG middle chunk should wait for final chunk");

      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Last_Chunk & ASCII.ESC & "\"),
         Feed_Status);
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "chunked kitty PNG final chunk feed failed");

      declare
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "chunked kitty PNG final render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert
           (Diagnostics.Last_Image_Protocol =
            Terminal.App.Render_Model.Image_Kitty,
            "chunked kitty PNG image diagnostic protocol");
         Assert
           (Diagnostics.Last_Image_Raw_Format = 32
            and then Diagnostics.Last_Image_Pixel_Width = 1
            and then Diagnostics.Last_Image_Pixel_Height = 1,
            "chunked kitty PNG image diagnostic pixel metadata");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Length = 4,
            "chunked kitty PNG decoded byte length");
         Assert
           (Diagnostics.Last_Image_Encoded_Preview_Length =
            24 + 24 + 44,
            "chunked kitty PNG encoded length should come from segments");
         Assert
           (Diagnostics.Last_Image_Staging_Byte_Length = 69,
            "chunked kitty PNG staging should be sized to Base64 upper bound");
         Assert
           (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#00#
            and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
            "chunked kitty PNG decoded bytes");
         Assert
           (not Diagnostics.Last_Image_Placeholder,
            "chunked kitty PNG image should be textured");
         Assert
           (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Kitty
            and then Frame.Images (1).Pixel_Width = 1
            and then Frame.Images (1).Pixel_Height = 1
            and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "chunked kitty PNG command pixel metadata");
         Assert
           (Frame.Images (1).Decoded_Bytes = null
            and then Frame.Images (1).Decoded_Source =
              Terminal.App.Render_Model.Image_Decoded_Source_PNG_Base64
            and then Frame.Images (1).Encoded_Source_Bytes /= null,
            "chunked kitty PNG command should retain encoded row source");
         Assert
           (not Frame.Images (1).Placeholder,
            "chunked kitty PNG command should be textured");
      end;
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "Pq~" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "sixel graphics feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "sixel graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Last_Image_Protocol =
         Terminal.App.Render_Model.Image_Sixel,
         "sixel graphics image diagnostic protocol");
      Assert
        (Diagnostics.Last_Image_Raw_Format = 32
         and then Diagnostics.Last_Image_Pixel_Width = 1
         and then Diagnostics.Last_Image_Pixel_Height = 6,
         "sixel graphics image diagnostic pixel metadata");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 24,
         "sixel graphics image decoded byte length");
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Bytes (1) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (2) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (3) = 16#FF#
         and then Diagnostics.Last_Image_Decoded_Preview_Bytes (4) = 16#FF#,
         "sixel graphics first RGBA pixel");
      Assert
        (not Diagnostics.Last_Image_Placeholder,
         "sixel graphics image should be textured");
      Assert
        (Frame.Images (1).Protocol = Terminal.App.Render_Model.Image_Sixel
         and then Frame.Images (1).Raw_Format = 32
         and then Frame.Images (1).Pixel_Width = 1
         and then Frame.Images (1).Pixel_Height = 6
         and then Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
         "sixel graphics command pixel metadata");
      Assert
        (Frame.Images (1).Decoded_Bytes = null
         and then Frame.Images (1).Decoded_Source =
           Terminal.App.Render_Model.Image_Decoded_Source_Sixel_Text
         and then Frame.Images (1).Encoded_Source_Bytes /= null,
         "sixel graphics command should retain encoded row source");
      Assert
        (not Frame.Images (1).Placeholder,
         "sixel graphics command should be textured");
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
         "image sixel size="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R) * 4)
         & "x"
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R) * 2)
         & " pixels=1x6 format=32 payload=2 payload-complete preview=24/1 bytes=FFFFFFFF textured decoded",
         "sixel graphics image diagnostic status label");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gf=100,a=T;SG$=" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "partial kitty graphics feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "partial graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert
        (Diagnostics.Last_Image_Decoded_Preview_Length = 0,
         "partial graphics image diagnostic decoded preview length");
      Assert
        (Diagnostics.Last_Image_Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Invalid_Byte,
         "partial graphics image diagnostic decode status");
      Assert
        (Diagnostics.Last_Image_Payload_Preview_Complete,
         "partial graphics image diagnostic payload preview complete");
      Assert
        (not Diagnostics.Last_Image_Preview_Decode_Complete,
         "partial graphics image diagnostic decode complete");
      Assert
        (Frame.Images (1).Decode_Status =
         Terminal.App.Render_Model.Image_Decode_Invalid_Byte,
         "partial graphics command decode status");
      Assert
        (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
         "image kitty size="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R) * 6)
         & "x"
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R) * 3)
         & " payload=15 payload-complete preview=0/4 placeholder partial invalid-byte",
         "partial graphics image diagnostic status label");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[4 q"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "underline cursor feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "underline cursor render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 3, "expected underline cursor rectangle");
      Assert
        (Frame.Rectangles (3).Height <= 3.0,
         "underline cursor should be thin");
      Assert
        (Frame.Rectangles (3).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "underline cursor should span the cell");
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[6 q"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bar cursor feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "bar cursor render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 3, "expected bar cursor rectangle");
      Assert
        (Frame.Rectangles (3).Width <= 3.0,
         "bar cursor should be thin");
      Assert
        (Frame.Rectangles (3).Height <= 16.0,
         "bar cursor should use font-sized height");
   end;

   Terminal.App.Renderer.Set_Framebuffer_Size (R, 100, 80);
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "render with framebuffer extent failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert
        (Frame.Width = 100,
         "frame width should use the target framebuffer width");
      Assert
        (Frame.Height = 80,
         "frame height should use the target framebuffer height");
      Assert
        (Frame.Rectangles (2).X = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should keep the horizontal content margin");
      Assert
        (Frame.Rectangles (2).Y = Float (Terminal.App.Renderer.Content_Margin),
         "first cell should keep the vertical content margin");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "bold core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[1mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bold feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "bold render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 2, "bold glyph should be drawn twice");
      Assert
        (Frame.Glyphs (2).X = Frame.Glyphs (1).X + 1.0,
         "bold duplicate glyph should be offset by one pixel");
      Assert
        (Frame.Glyphs (2).Y = Frame.Glyphs (1).Y,
         "bold duplicate glyph should keep baseline placement");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "bold indexed core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[1;31mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "bold indexed feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "bold indexed render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 2, "bold indexed glyph should be drawn twice");
      Assert_Close (Frame.Glyphs (1).Color.R, 1.0, "bold red bright red");
      Assert_Close (Frame.Glyphs (1).Color.G, 0.36, "bold red bright green");
      Assert_Close (Frame.Glyphs (1).Color.B, 0.32, "bold red bright blue");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "inverse bold indexed core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[1;31;44;7mA"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "inverse bold indexed feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "inverse bold indexed render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 2, "inverse bold glyph should be drawn twice");
      Assert_Close
        (Frame.Glyphs (1).Color.R,
         0.25,
         "inverse bold should use original background red");
      Assert_Close
        (Frame.Glyphs (1).Color.G,
         0.45,
         "inverse bold should use original background green");
      Assert_Close
        (Frame.Glyphs (1).Color.B,
         0.86,
         "inverse bold should use original background blue");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "faint core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[2mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "faint feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "faint render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count >= 1, "faint glyph count");
      Assert
        (Frame.Glyphs (1).Color.R < 0.86,
         "faint glyph should dim default foreground red");
      Assert
        (Frame.Glyphs (1).Color.G < 0.88,
         "faint glyph should dim default foreground green");
      Assert
        (Frame.Glyphs (1).Color.B < 0.88,
         "faint glyph should dim default foreground blue");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "conceal core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[8;4;9mA"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "conceal feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "conceal render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count = 0, "concealed glyph should not be drawn");
      Assert
        (Frame.Rectangle_Count >= 3,
         "concealed cell should still draw background and cursor rectangles");
      Assert
        (Frame.Rectangle_Count < 5,
         "concealed cell should not draw underline or strikethrough");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "overline core initialize failed");
   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[53mA"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "overline feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "overline render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 5, "expected overline rectangle");
      Assert
        (Frame.Rectangles (3).Height = 1.0,
         "overline decoration should be one pixel high");
      Assert
        (Frame.Rectangles (3).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "overline decoration should span the cell");
      Assert
        (Frame.Rectangles (3).Y =
           Float (Terminal.App.Renderer.Content_Margin),
         "overline decoration should sit at the cell top");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "decoration core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[58;2;1;2;3;4mA" & ASCII.ESC & "[24;9mB"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "decoration feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "decoration render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 7, "expected decoration rectangles");
      Assert
        (Frame.Rectangles (3).Height = 1.0,
         "underline decoration should be one pixel high");
      Assert
        (Frame.Rectangles (3).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "underline decoration should span the cell");
      Assert_Close
        (Frame.Rectangles (3).Color.R,
         1.0 / 255.0,
         "underline decoration red");
      Assert_Close
        (Frame.Rectangles (3).Color.G,
         2.0 / 255.0,
         "underline decoration green");
      Assert_Close
        (Frame.Rectangles (3).Color.B,
         3.0 / 255.0,
         "underline decoration blue");
      Assert
        (Frame.Rectangles (5).Height = 1.0,
         "strikethrough decoration should be one pixel high");
      Assert
        (Frame.Rectangles (5).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "strikethrough decoration should span the cell");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "underline substyle core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "[4:2mA"
         & ASCII.ESC & "[4:3mB"
         & ASCII.ESC & "[4:4mC"
         & ASCII.ESC & "[4:5mD"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "underline substyle feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "underline substyle render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Found_Double_Line : Boolean := False;
      Found_Segment     : Boolean := False;
   begin
      Assert
        (Frame.Rectangle_Count >= 10,
         "underline substyles should emit multiple decoration rectangles");
      for I in 1 .. Frame.Rectangle_Count loop
         if Frame.Rectangles (I).Width =
           Float (Terminal.App.Renderer.Cell_Width (R))
         then
            for J in I + 1 .. Frame.Rectangle_Count loop
               if Frame.Rectangles (J).Width = Frame.Rectangles (I).Width
                 and then Frame.Rectangles (J).X = Frame.Rectangles (I).X
                 and then abs (Frame.Rectangles (J).Y - Frame.Rectangles (I).Y) = 2.0
               then
                  Found_Double_Line := True;
               end if;
            end loop;
         end if;

         if Frame.Rectangles (I).Width <= 2.0 then
            Found_Segment := True;
         end if;
      end loop;

      Assert
        (Found_Double_Line,
         "double underline should draw two separated full-width lines");
      Assert
        (Found_Segment,
         "curly or dotted underline should be segmented");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "hover link core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (Character'Val (16#1B#) & "[?25l"
         & Character'Val (16#1B#) & "]8;id=hover;https://example.test"
         & Character'Val (16#1B#) & "\"
         & "ab"
         & Character'Val (16#1B#) & "]8;;"
         & Character'Val (16#1B#) & "\"
         & "c"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "hover link feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Link : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At (Snap, (Row => 1, Col => 1));
   begin
      Terminal.App.Renderer.Set_Hovered_Link (R, Link);
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "hover link render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Rectangle_Count >= 6, "expected hover link underlines");
      Assert
        (Frame.Rectangles (3).Height = 1.0,
         "hover underline first cell should be one pixel high");
      Assert
        (Frame.Rectangles (3).Y =
           Float
             (Terminal.App.Renderer.Content_Margin
              + Terminal.App.Renderer.Cell_Height (R) - 2),
         "hover underline first cell baseline");
      Assert
        (Frame.Rectangles (5).Height = 1.0,
         "hover underline second cell should be one pixel high");
      Assert
        (Frame.Rectangles (5).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "hover underline second cell width");
   end;

   Terminal.App.Renderer.Set_Hovered_Link (R, (others => <>));

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "indexed color core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[38;5;196mA" & ASCII.ESC & "[48;5;232mB"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "indexed color feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "indexed color render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Glyph_Count >= 2, "indexed color glyph count");
      Assert_Close (Frame.Glyphs (1).Color.R, 1.0, "xterm 196 red");
      Assert_Close (Frame.Glyphs (1).Color.G, 0.0, "xterm 196 green");
      Assert_Close (Frame.Glyphs (1).Color.B, 0.0, "xterm 196 blue");
      Assert_Close
        (Frame.Rectangles (3).Color.R,
         8.0 / 255.0,
         "xterm 232 grayscale red");
      Assert_Close
        (Frame.Rectangles (3).Color.G,
         8.0 / 255.0,
         "xterm 232 grayscale green");
      Assert_Close
        (Frame.Rectangles (3).Color.B,
         8.0 / 255.0,
         "xterm 232 grayscale blue");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "cluster render core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#CC#, 3 => 16#81#,
       4 => 16#E2#, 5 => 16#80#, 6 => 16#8D#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "cluster render feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "cluster render failed");

   declare
      Frame      : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Saw_Base   : Boolean := False;
      Saw_ZWJ    : Boolean := False;
   begin
      for I in 1 .. Frame.Glyph_Count loop
         if Frame.Glyphs (I).Codepoint = 16#61# then
            Saw_Base := True;
         elsif Frame.Glyphs (I).Codepoint = 16#200D# then
            Saw_ZWJ := True;
         end if;
      end loop;

      Assert (Saw_Base, "cluster render should draw base glyph");
      Assert (Frame.Text_Run_Count = 1, "cluster render text run count");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "cluster render shape status");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count > 0,
         "cluster render shaped glyph count");
      Assert (not Saw_ZWJ, "cluster render should skip invisible ZWJ");
   end;

   Terminal.Core.Initialize (T, 1, 5, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "emoji cluster render core initialize failed");
   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos ('a')),
       2  => 16#F0#, 3  => 16#9F#, 4  => 16#91#, 5  => 16#A9#,
       6  => 16#E2#, 7  => 16#80#, 8  => 16#8D#,
       9  => 16#F0#, 10 => 16#9F#, 11 => 16#91#, 12 => 16#A8#,
       13 => 16#F0#, 14 => 16#9F#, 15 => 16#8F#, 16 => 16#BD#,
       17 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "emoji cluster render feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "emoji cluster render failed");

   declare
      Frame       : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Saw_A       : Boolean := False;
      Saw_ZWJ     : Boolean := False;
      Saw_B       : Boolean := False;
   begin
      for I in 1 .. Frame.Glyph_Count loop
         if Frame.Glyphs (I).Codepoint = 16#61# then
            Saw_A := True;
         elsif Frame.Glyphs (I).Codepoint = 16#200D# then
            Saw_ZWJ := True;
         elsif Frame.Glyphs (I).Codepoint = 16#62# then
            Saw_B := True;
         end if;
      end loop;

      Assert (Saw_A, "emoji cluster render should draw prefix");
      Assert (Saw_B, "emoji cluster render should draw suffix");
      Assert (Frame.Text_Run_Count = 3, "emoji cluster render text run count");
      Assert
        (Frame.Text_Runs (2).Codepoint_Count = 4,
         "emoji cluster text run should preserve cluster length");
      Assert
        (Frame.Text_Runs (2).Codepoints (1) = 16#1F469#,
         "emoji cluster text run base");
      Assert
        (Frame.Text_Runs (2).Codepoints (2) = 16#200D#,
         "emoji cluster text run ZWJ");
      Assert
        (Frame.Text_Runs (2).Codepoints (3) = 16#1F468#,
         "emoji cluster text run joined scalar");
      Assert
        (Frame.Text_Runs (2).Codepoints (4) = 16#1F3FD#,
         "emoji cluster text run modifier");
      Assert
        (Frame.Text_Runs (2).Cell_Span = 2,
         "emoji cluster text run cell span");
      Assert
        (Frame.Text_Runs (2).Run_Kind =
           Terminal.App.Render_Model.Joined_Emoji_Cluster,
         "emoji cluster text run class");
      Assert
        (Frame.Text_Runs (2).Shape_Status
           in Terminal.App.Render_Model.Shape_Ok |
              Terminal.App.Render_Model.Needs_Shaping_Backend,
         "emoji cluster text run shape status");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "emoji cluster text run direction");
      Assert
        (Frame.Text_Runs (2).Script =
           Terminal.App.Render_Model.Script_Emoji,
         "emoji cluster text run script");
      Assert
        ((Frame.Text_Runs (2).Shape_Status =
            Terminal.App.Render_Model.Shape_Ok
          and then not Frame.Text_Runs (2).Fallback_Glyphs
          and then Frame.Text_Runs (2).Shaped_Glyph_Count > 0)
         or else
           (Frame.Text_Runs (2).Shape_Status =
              Terminal.App.Render_Model.Needs_Shaping_Backend
            and then Frame.Text_Runs (2).Fallback_Glyphs
            and then Frame.Text_Runs (2).Shaped_Glyph_Count = 0),
         "emoji cluster shaped/fallback state");
      Assert (not Saw_ZWJ, "emoji cluster render should skip ZWJ");
      declare
         Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diag.Last_Text_Run_Count = Frame.Text_Run_Count,
            "renderer diagnostics should report text run count");
         Assert
           (Diag.Last_Color_Emoji_Fallback_Count = 1,
            "renderer diagnostics should report color emoji fallback");
         if Frame.Text_Runs (2).Fallback_Glyphs then
            Assert
              (Diag.Last_Text_Fallback_Run_Count = 1,
               "renderer diagnostics should report emoji fallback run");
            Assert
              (Diag.Last_Shaping_Fallback_Count = 1,
               "renderer diagnostics should report emoji backend need");
         else
            Assert
              (Diag.Last_Text_Fallback_Run_Count = 0,
               "renderer diagnostics should report no emoji fallback run");
            Assert
              (Diag.Last_Shaping_Fallback_Count = 0,
               "renderer diagnostics should report no emoji backend need");
         end if;
      end;
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "simple text run core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (Character'Val (16#1B#) & "[?25labc"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "simple text run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "simple text run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "simple text should coalesce");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 3,
         "simple text run codepoint count");
      Assert
        (Frame.Text_Runs (1).Run_Kind =
           Terminal.App.Render_Model.Simple_Text,
         "simple text run class");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "simple text run shape status");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "simple text run direction");
      Assert
        (Frame.Text_Runs (1).Script =
           Terminal.App.Render_Model.Script_Latin,
         "simple text run script");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count = 3,
         "simple text shaped glyph count");
      Assert
        (Frame.Text_Runs (1).Cell_Span = 3,
         "simple text run should span all cells");
      Assert_Close
        (Frame.Text_Runs (1).Cell_Width,
         Float (Terminal.App.Renderer.Cell_Width (R)),
         "simple text run cell width should be one grid cell");
      Assert
        (Frame.Glyph_Count = Natural (Frame.Text_Runs (1).Shaped_Glyph_Count),
         "simple shaped text should not draw covered fallback cells");
      declare
         Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diag.Last_Shaped_Glyph_Count = 3,
            "simple text renderer shaped glyph diagnostic count");
      end;
      Assert
        (not Frame.Text_Runs (1).Fallback_Glyphs,
         "simple text should not need glyph fallback");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "neutral latin run core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (Character'Val (16#1B#) & "[?25l(ab)"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "neutral latin run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "neutral latin run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert
        (Frame.Text_Run_Count = 1,
         "neutral punctuation should join surrounding latin run");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 4,
         "neutral latin run codepoint count");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "neutral latin run direction");
      Assert
        (Frame.Text_Runs (1).Script =
           Terminal.App.Render_Model.Script_Latin,
         "neutral latin run script");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "neutral mixed run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('(')),
       2 => Byte (Character'Pos ('a')),
       3 => 16#D7#,
       4 => 16#90#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "neutral mixed run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "neutral mixed run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert
        (Frame.Text_Run_Count = 2,
         "neutral punctuation must not merge conflicting scripts");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 2,
         "neutral mixed first run codepoint count");
      Assert
        (Frame.Text_Runs (1).Script = Terminal.App.Render_Model.Script_Latin,
         "neutral mixed first run script");
      Assert
        (Frame.Text_Runs (2).Script = Terminal.App.Render_Model.Script_Hebrew,
         "neutral mixed second run script");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "neutral mixed second run direction");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "RTL digit split core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#D7#,
       2 => 16#90#,
       3 => Byte (Character'Pos ('1')),
       4 => Byte (Character'Pos ('2')),
       5 => 16#D7#,
       6 => 16#91#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "RTL digit split feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "RTL digit split render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert
        (Frame.Text_Run_Count = 3,
         "ASCII digits should split from neighboring RTL runs");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "RTL digit split first direction");
      Assert
        (Frame.Text_Runs (2).Codepoint_Count = 2,
         "RTL digit split digit run count");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "RTL digit split digit direction");
      Assert
        (Frame.Text_Runs (2).Script =
           Terminal.App.Render_Model.Script_Common,
         "RTL digit split digit script");
      Assert
        (Frame.Text_Runs (3).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "RTL digit split third direction");
      Assert
        (Diag.Last_Paragraph_Bidi_Fallback_Count = 1,
         "mixed LTR/RTL row should report paragraph BiDi fallback");
   end;

   Terminal.Core.Initialize (T, 1, 4, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "ligature text run core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (Character'Val (16#1B#) & "[?25lfile"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "ligature text run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "ligature text run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Diag  : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "ligature text should coalesce");
      Assert
        (Frame.Text_Runs (1).Codepoint_Count = 4,
         "ligature text run codepoint count");
      Assert
        (Frame.Text_Runs (1).Run_Kind =
           Terminal.App.Render_Model.Ligature_Candidate,
         "ligature text run class");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "ligature text run shape status");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Left_To_Right,
         "ligature text run direction");
      Assert
        (Frame.Text_Runs (1).Script =
           Terminal.App.Render_Model.Script_Latin,
         "ligature text run script");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count > 0,
         "ligature text shaped glyph count");
      Assert
        (not Frame.Text_Runs (1).Fallback_Glyphs,
         "ligature text should not use glyph fallback");
      Assert
        (Diag.Last_Shaping_Fallback_Count = 0,
         "ligature fallback diagnostic count");
   end;

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "missing scalar text run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#F4#, 2 => 16#8F#, 3 => 16#BF#, 4 => 16#BF#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "missing scalar feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "missing scalar render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
      Diag  : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "missing scalar text run count");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "missing scalar should remain renderable");
      Assert
        (Frame.Text_Runs (1).Fallback_Glyphs,
         "missing scalar should use codepoint fallback");
      Assert
        (Frame.Text_Runs (1).Shaped_Glyph_Count = 0,
         "missing scalar should not draw notdef shaped glyph");
      Assert
        (Diag.Last_Text_Fallback_Run_Count = 1,
         "renderer diagnostics should count fallback text run");
      Assert
        (Diag.Last_Shaping_Fallback_Count = 0,
         "simple missing scalar should not count as backend-needed");
   end;

   Terminal.Core.Initialize (T, 1, 3, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "mixed script text run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => Byte (Character'Pos ('a')),
       2 => 16#D7#,
       3 => 16#90#,
       4 => Byte (Character'Pos ('b'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "mixed script text run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "mixed script text run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert
        (Frame.Text_Run_Count = 3,
         "mixed script row should split shaping runs");
      Assert
        (Frame.Text_Runs (1).Script = Terminal.App.Render_Model.Script_Latin,
         "mixed script first run script");
      Assert
        (Frame.Text_Runs (2).Script = Terminal.App.Render_Model.Script_Hebrew,
         "mixed script second run script");
      Assert
        (Frame.Text_Runs (2).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "mixed script second run direction");
      Assert
        (Frame.Text_Runs (3).Script = Terminal.App.Render_Model.Script_Latin,
         "mixed script third run script");
   end;

   Terminal.Core.Initialize (T, 1, 2, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "RTL shaped run core initialize failed");
   Terminal.Core.Feed
     (T,
      (1  => Byte (Character'Pos (Character'Val (16#1B#))),
       2  => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('?')),
       4  => Byte (Character'Pos ('2')),
       5  => Byte (Character'Pos ('5')),
       6  => Byte (Character'Pos ('l')),
       7  => 16#D7#,
       8  => 16#90#,
       9  => 16#D7#,
       10 => 16#91#),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "RTL shaped run feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "RTL shaped run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Last_Frame (R);
   begin
      Assert (Frame.Text_Run_Count = 1, "RTL text should coalesce");
      Assert
        (Frame.Text_Runs (1).Direction =
           Terminal.App.Render_Model.Direction_Right_To_Left,
         "RTL text run direction");
      Assert
        (Frame.Text_Runs (1).Shape_Status =
           Terminal.App.Render_Model.Shape_Ok,
         "RTL text run shape status");
      Assert
        (Frame.Text_Runs (1).Cell_Span = 2,
         "RTL text run should span both cells");
      Assert_Close
        (Frame.Text_Runs (1).Cell_Width,
         Float (Terminal.App.Renderer.Cell_Width (R)),
         "RTL text run cell width should be one grid cell");
      Assert
        (Frame.Glyph_Count >= 2,
         "RTL shaped run should draw at least two glyphs");
      Assert
        (Frame.Glyphs (1).X > Frame.Glyphs (2).X,
         "RTL shaped run should place first shaped glyph to the right");
      Assert
        (Frame.Glyphs (1).X >
           Frame.Text_Runs (1).X + Frame.Text_Runs (1).Cell_Width - 1.0,
         "RTL shaped run should start from full run right edge");
   end;

   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Renderer.Finalize (R);

   declare
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert (not Diag.Initialized, "finalized renderer initialized flag");
      Assert (Diag.Last_Rectangle_Count = 0, "finalized rectangle count");
      Assert (Diag.Last_Glyph_Count = 0, "finalized glyph count");
   end;

   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer reinitialize failed");
   Terminal.App.Renderer.Finalize (R);
end Renderer_Metrics_Smoke;
