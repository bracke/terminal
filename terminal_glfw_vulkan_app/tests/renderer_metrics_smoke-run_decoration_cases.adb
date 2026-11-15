separate (Renderer_Metrics_Smoke)
procedure Run_Decoration_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
end Run_Decoration_Cases;
