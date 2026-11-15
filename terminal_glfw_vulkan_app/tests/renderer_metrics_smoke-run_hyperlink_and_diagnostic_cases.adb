separate (Renderer_Metrics_Smoke)
procedure Run_Hyperlink_And_Diagnostic_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
   Terminal.Core.Initialize (T, 1, 32, 100, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "hyperlink overlay initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "]8;id=abc;https://example.test" & ASCII.ESC & "\"
         & "x"
         & ASCII.ESC & "]8;;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "hyperlink overlay feed failed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Link : constant Terminal.Core.Hyperlink :=
        Terminal.App.Hyperlinks.Link_At (Snap, (Row => 1, Col => 1));
   begin
      Terminal.App.Renderer.Set_Hovered_Link (R, (others => <>));
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "plain hyperlink render failed");

      declare
         Plain_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Terminal.App.Renderer.Set_Status_Overlay (R, "PALETTE test [1/1]");
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok
            and then Terminal.App.Renderer.Testing.Last_Frame (R).Glyph_Count >
              Plain_Frame.Glyph_Count,
            "interaction status overlay should draw without a hovered link");
         Terminal.App.Renderer.Set_Status_Overlay (R, "");
         Terminal.App.Renderer.Set_Hovered_Link (R, Link);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "hovered hyperlink render failed");

         declare
            Hover_Frame : constant Terminal.App.Render_Model.Frame_Commands :=
              Terminal.App.Renderer.Testing.Last_Frame (R);
         begin
            Assert (Link.Active, "hovered link should be active");
            Assert
              (Hover_Frame.Rectangle_Count >= Plain_Frame.Rectangle_Count + 2,
               "hovered link should add underline and status background rectangles");
            Assert
              (Hover_Frame.Glyph_Count > Plain_Frame.Glyph_Count,
               "hovered link should draw status label glyphs");
         end;
      end;

      Terminal.App.Renderer.Set_Hovered_Link (R, (others => <>));
      Terminal.Core.Release (Snap);
   end;

   Terminal.Core.Initialize (T, 2, 8, 100, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "scrollbar initialize failed");
   declare
      Base : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Base_Rectangles : Natural;
   begin
      Terminal.App.Renderer.Render (R, Base, Render_Status);
      Base_Rectangles :=
        Terminal.App.Renderer.Testing.Last_Frame (R).Rectangle_Count;
      Terminal.Core.Release (Base);
      Terminal.Core.Feed
        (T,
         To_Bytes
           ("a" & ASCII.CR & ASCII.LF
            & "b" & ASCII.CR & ASCII.LF
            & "c" & ASCII.CR & ASCII.LF),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "scrollbar feed failed");
      declare
         History : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Terminal.App.Renderer.Render (R, History, Render_Status);
         Assert
           (Terminal.Core.Scrollback_Rows (History) > 0
            and then Terminal.App.Renderer.Testing.Last_Frame (R).Rectangle_Count
              >= Base_Rectangles + 2,
            "retained history should add scrollbar track and thumb");
         Terminal.Core.Release (History);
      end;
   end;

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core reinitialize failed");

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gf=32,a=T,C=1;AAAA" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "kitty graphics feed failed");

   Render_And_Complete_Graphics (Context, T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "graphics render failed: "
      & Terminal.App.Renderer.Render_Status'Image (Render_Status));

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        (Diagnostics.Last_Image_Payload_Length = 18,
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
      Assert (Frame.Images (1).Payload_Length = 18, "graphics payload length");
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
          Bounded_Image_Label
            ("image kitty size="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R) * 6)
         & "x"
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R) * 3)
         & " payload=18 payload-complete preview=3/4 bytes=000000 placeholder decoded"),
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
      Payload : constant String := "Gf=32,a=T,C=1,s=1,v=1,c=1,r=1;/wAA/w==";
   begin
      Terminal.Core.Feed
        (T,
         To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
         Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "raw kitty graphics feed failed");

      Render_And_Complete_Graphics (Context, T);
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "raw graphics render failed");

      declare
         Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
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
              Terminal.App.Render_Model.Image_Decoded_Source_Buffer
            and then Frame.Images (1).Decoded_Bytes /= null
            and then Frame.Images (1).Encoded_Source_Bytes = null,
            "anonymous transmit-and-display should retain decoded pixels");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 3) = 16#FF#,
            "raw graphics retained row bytes");
         Assert
           (Frame.Images (1).Decoded_Row_Stride_Bytes = 4,
            "raw graphics command should carry decoded row stride");
         Assert
           (not Frame.Images (1).Placeholder,
            "raw graphics command should be textured");
         Assert
           (Terminal.App.Renderer.Image_Status_Label (Diagnostics) =
            Bounded_Image_Label
              ("image kitty size="
            & Trimmed_Natural
              (Natural'Min
                 (Terminal.App.Renderer.Cell_Width (R),
                  Terminal.App.Renderer.Cell_Height (R)))
            & "x"
            & Trimmed_Natural
              (Natural'Min
                 (Terminal.App.Renderer.Cell_Width (R),
                  Terminal.App.Renderer.Cell_Height (R)))
            & " pixels=1x1 format=32 payload=0"
            & " payload-complete preview=4/0 bytes=FF0000FF textured decoded"),
            "raw graphics image diagnostic status label");
      end;
   end;

   --  The anonymous a=T image is now a real persistent placement. Retire it
   --  before the independent explicit-ID object tests below.
   Terminal.App.Renderer.Graphics.Release_Stream (R, 0);
   Terminal.Core.Set_Graphics_Stream_ID (T, 4_100);
end Run_Hyperlink_And_Diagnostic_Cases;
