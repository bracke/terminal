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
      To_Bytes (ASCII.ESC & "[4mA" & ASCII.ESC & "[24;9mB"),
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
      Assert
        (Frame.Rectangles (5).Height = 1.0,
         "strikethrough decoration should be one pixel high");
      Assert
        (Frame.Rectangles (5).Width =
           Float (Terminal.App.Renderer.Cell_Width (R)),
         "strikethrough decoration should span the cell");
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
      Saw_Acute  : Boolean := False;
      Saw_ZWJ    : Boolean := False;
   begin
      for I in 1 .. Frame.Glyph_Count loop
         if Frame.Glyphs (I).Codepoint = 16#61# then
            Saw_Base := True;
         elsif Frame.Glyphs (I).Codepoint = 16#0301# then
            Saw_Acute := True;
         elsif Frame.Glyphs (I).Codepoint = 16#200D# then
            Saw_ZWJ := True;
         end if;
      end loop;

      Assert (Saw_Base, "cluster render should draw base glyph");
      Assert (Saw_Acute, "cluster render should draw combining mark");
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
      Saw_Base    : Boolean := False;
      Saw_ZWJ     : Boolean := False;
      Saw_Joined  : Boolean := False;
      Saw_Modifier : Boolean := False;
      Saw_B       : Boolean := False;
   begin
      for I in 1 .. Frame.Glyph_Count loop
         if Frame.Glyphs (I).Codepoint = 16#61# then
            Saw_A := True;
         elsif Frame.Glyphs (I).Codepoint = 16#1F469# then
            Saw_Base := True;
         elsif Frame.Glyphs (I).Codepoint = 16#200D# then
            Saw_ZWJ := True;
         elsif Frame.Glyphs (I).Codepoint = 16#1F468# then
            Saw_Joined := True;
         elsif Frame.Glyphs (I).Codepoint = 16#1F3FD# then
            Saw_Modifier := True;
         elsif Frame.Glyphs (I).Codepoint = 16#62# then
            Saw_B := True;
         end if;
      end loop;

      Assert (Saw_A, "emoji cluster render should draw prefix");
      Assert (Saw_Base, "emoji cluster render should draw base emoji glyph");
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
        (Frame.Text_Runs (2).Shape_Status =
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
        (Frame.Text_Runs (2).Shaped_Glyph_Count = 0,
         "emoji cluster should not invent shaped glyphs");
      Assert
        (Frame.Text_Runs (2).Fallback_Glyphs,
         "emoji cluster text run should allow the current glyph fallback");
      Assert (not Saw_ZWJ, "emoji cluster render should skip ZWJ");
      Assert (not Saw_Joined, "emoji cluster render should skip joined scalar");
      Assert
        (not Saw_Modifier,
         "emoji cluster render should skip emoji modifier attachment");
      declare
         Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
           Terminal.App.Renderer.Diagnostics (R);
      begin
         Assert
           (Diag.Last_Text_Run_Count = Frame.Text_Run_Count,
            "renderer diagnostics should report text run count");
         Assert
           (Diag.Last_Shaping_Fallback_Count = 1,
            "renderer diagnostics should report complex text fallback count");
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
           Terminal.App.Render_Model.Needs_Shaping_Backend,
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
        (Frame.Text_Runs (1).Shaped_Glyph_Count = 0,
         "ligature text should wait for shaping backend");
      Assert
        (Frame.Text_Runs (1).Fallback_Glyphs,
         "ligature text should use glyph fallback");
      Assert
        (Diag.Last_Shaping_Fallback_Count = 1,
         "ligature fallback diagnostic count");
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
