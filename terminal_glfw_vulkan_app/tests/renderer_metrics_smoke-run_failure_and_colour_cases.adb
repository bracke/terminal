separate (Renderer_Metrics_Smoke)
procedure Run_Failure_And_Colour_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
   while Terminal.Core.Pending_Graphics_Event_Count (T) > 0 loop
      Terminal.Core.Discard_Graphics_Event (T);
   end loop;
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "_Gf=100,a=T,C=1;SG$=" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "partial kitty graphics feed failed");
   Render_And_Complete_Graphics (Context, T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "partial graphics render failed");

   declare
      Diagnostics : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
         Bounded_Image_Label
           ("image kitty size="
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Width (R) * 6)
         & "x"
         & Trimmed_Natural (Terminal.App.Renderer.Cell_Height (R) * 3)
         & " payload=19 payload-complete preview=0/4 placeholder partial invalid-byte"),
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
end Run_Failure_And_Colour_Cases;
