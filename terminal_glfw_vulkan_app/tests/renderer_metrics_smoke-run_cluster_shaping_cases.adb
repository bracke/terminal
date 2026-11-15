separate (Renderer_Metrics_Smoke)
procedure Run_Cluster_Shaping_Cases (Context : in out Suite_Context) is
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
      "underline substyle render failed");

   declare
      Frame : constant Terminal.App.Render_Model.Frame_Commands :=
        Terminal.App.Renderer.Testing.Last_Frame (R);
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

   Terminal.Core.Initialize (T, 1, 1, 10, Core_Status);
   Assert
     (Core_Status = Terminal.Core.Ok,
      "dense decoration core initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[4:3;9;53mA"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "dense decoration feed failed");
   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert
     (Render_Status = Terminal.App.Renderer.Ok,
      "dense one-cell decorations fit the rectangle budget");
   Assert
     (Terminal.App.Renderer.Testing.Last_Frame (R).Rectangle_Count >= 9,
      "dense one-cell decorations are not silently truncated");

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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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
      Assert
        (Frame.Rectangles (3).Layer =
           Terminal.App.Render_Model.Rectangle_Cell_Background,
         "explicit cell background covers deep negative images");
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
        Terminal.App.Renderer.Testing.Last_Frame (R);
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


end Run_Cluster_Shaping_Cases;
