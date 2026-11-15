separate (Renderer_Metrics_Smoke)
procedure Run_Shaping_Fallback_Cases (Context : in out Suite_Context) is
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
      "neutral latin run render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        (Frame.Text_Runs (3).X < Frame.Text_Runs (2).X
         and then Frame.Text_Runs (2).X < Frame.Text_Runs (1).X,
         "mixed RTL paragraph should be visually reordered");
      Assert
        (Diag.Last_Paragraph_Bidi_Fallback_Count = 0,
         "mixed LTR/RTL row should not report paragraph BiDi fallback");
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
end Run_Shaping_Fallback_Cases;
