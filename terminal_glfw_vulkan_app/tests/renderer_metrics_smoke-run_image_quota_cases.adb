separate (Renderer_Metrics_Smoke)
procedure Run_Image_Quota_Cases (Context : in out Suite_Context) is
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
      "missing scalar render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "_Ga=d,d=R,x=0,y=4294967295;" & ASCII.ESC & "\"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "quota reset feed failed");
   Render_And_Complete_Graphics (Context, T);
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "quota reset render failed");

   for Offset in 0 .. Terminal.App.Renderer.Max_Kitty_Image_Objects + 9 loop
      declare
         ID : constant Natural := 10_000 + Offset;
         Payload : constant String :=
           "Gq=2,a=t,i=" & Trimmed_Natural (ID)
           & ",f=32,s=1,v=1;/wAA/w==";
      begin
         Terminal.Core.Feed
           (T,
            To_Bytes (ASCII.ESC & "_" & Payload & ASCII.ESC & "\"),
            Feed_Status);
         Assert (Feed_Status = Terminal.Core.Ok, "quota object feed failed");
         Render_And_Complete_Graphics (Context, T);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "quota object render failed");
      end;
   end loop;

   declare
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert
        (Diag.Kitty_Image_Object_Count =
           Terminal.App.Renderer.Max_Kitty_Image_Objects,
         "kitty image-object count quota");
      Assert
        (Diag.Kitty_Image_Object_Bytes =
           Terminal.App.Renderer.Max_Kitty_Image_Objects * 4,
         "kitty decoded-image byte accounting");
      Assert
        (Diag.Kitty_Placement_Count = 0,
         "transmit-only quota test should not create placements");
   end;

end Run_Image_Quota_Cases;
