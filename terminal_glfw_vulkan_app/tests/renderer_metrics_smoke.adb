with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;

procedure Renderer_Metrics_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
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
     (Terminal.App.Renderer.Cell_Width (R) = 8,
      "cell width should keep the fixed monospace grid width");

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
        (Frame.Rectangles (3).Height <= 16.0,
         "cursor block should be font-sized, not full line height");
      Assert
        (Frame.Rectangles (3).Height <= Float (Terminal.App.Renderer.Cell_Height (R)),
         "cursor block should fit within the terminal cell");
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

   Terminal.App.Renderer.Finalize (R);
end Renderer_Metrics_Smoke;
