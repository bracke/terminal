separate (Renderer_Metrics_Smoke)
procedure Run_Emoji_Cluster_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Core_Status : Terminal.Core.Initialize_Status renames Context.Core_Status;
begin
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
           (Diag.Last_Color_Glyph_Count > 0,
            "renderer diagnostics should report emitted color emoji glyphs");
         Assert
           (Diag.Last_Color_Emoji_Fallback_Count = 0,
            "color emoji should not fall back when a color font is available");
         Assert
           (Frame.Colour_Glyph_Count = Diag.Last_Color_Glyph_Count,
            "renderer diagnostics should report emitted color glyphs");
         Assert
           (Frame.Colour_Sheet_Width > 0
              and then Frame.Colour_Sheet_Height > 0
              and then Frame.Colour_Sheet_Pixels /= System.Null_Address,
            "color emoji render should expose a color sheet");
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
end Run_Emoji_Cluster_Cases;
