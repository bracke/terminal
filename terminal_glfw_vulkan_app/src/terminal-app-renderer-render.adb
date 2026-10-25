separate (Terminal.App.Renderer)
procedure Render
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot;
   Status   : out Render_Status)
is
   Cell_Count     : Natural;
   Rect_Max       : Natural;
   Glyph_Max      : Natural;
   Image_Max      : Natural;
   Content_Width  : Natural;
   Content_Height : Natural;
   Capacity_Ok    : Boolean;
   Intermediate   : Natural;
   Rectangles_Per_Cell : Natural;
   Glyphs_Per_Cell : constant Natural :=
     Natural'Max
       (Terminal.Core.Max_Cluster_Attachments + 1,
        RM.Max_Shaped_Glyphs_Per_Run) * 2;

begin
   if not R.Initialized or else not R.Text_Loaded then
      Set_Render_Status (R, Status, Not_Initialized);
      return;
   elsif Snapshot.Rows = 0 or else Snapshot.Cols = 0 then
      Set_Render_Status (R, Status, Invalid_Snapshot);
      return;
   end if;

   if not Terminal.App.Size_Arithmetic.Try_Multiply
     (Snapshot.Rows, Snapshot.Cols, Cell_Count)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (R.CW, 4, Rectangles_Per_Cell)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Cell_Count, Rectangles_Per_Cell, Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate, 3, Rect_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Cell_Count, Glyphs_Per_Cell, Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate, Max_Link_Overlay_Chars, Glyph_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Cell_Count, R.Kitty_Placement_Count, Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate,
        Additional_Frame_Image_Commands (R, Snapshot.Graphics),
        Image_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Snapshot.Cols, R.CW, Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate, Content_Margin * 2, Content_Width)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Snapshot.Rows, R.CH, Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate, Content_Margin * 2, Content_Height)
   then
      Set_Render_Status (R, Status, Invalid_Snapshot);
      return;
   end if;

   Reset_Frame (R);
   R.Graphics_Event_Tracking_Failed := False;
   R.Missing_Glyph_Count := 0;
   R.Shaped_Glyph_Count := 0;
   R.Shaping_Fallback_Count := 0;
   R.Text_Fallback_Run_Count := 0;
   R.Color_Glyph_Count := 0;
   R.Color_Emoji_Fallback_Count := 0;
   R.Paragraph_Bidi_Fallback_Count := 0;

   Ensure_Frame_Capacity
     (R,
      Rectangle_Count => Positive (Rect_Max),
      Glyph_Count => Positive (Glyph_Max),
      --  One tile per cell is the most a frame can ask for, and emoji are
      --  rare enough that a smaller cap would be a cliff rather than a saving.
      Colour_Count => Positive (Cell_Count),
      Image_Count => Positive (Image_Max),
      Text_Run_Count => Positive (Cell_Count),
      Success => Capacity_Ok);
   if not Capacity_Ok then
      Release_Frame (R);
      Set_Render_Status (R, Status, Allocation_Failed);
      return;
   end if;
   R.Last_Cell_Count := Cell_Count;
   R.Last_Frame_Width := Natural'Max (Content_Width, R.Target_Frame_Width);
   R.Last_Frame_Height := Natural'Max (Content_Height, R.Target_Frame_Height);

   if Snapshot.Dirty /= null then
      for Row in 1 .. Snapshot.Rows loop
         if Snapshot.Dirty (Row) then
            R.Last_Dirty_Rows := R.Last_Dirty_Rows + 1;
         end if;
      end loop;
   end if;

   Add_Rectangle
     (R,
      X      => 0.0,
      Y      => 0.0,
      Width  => Float (R.Last_Frame_Width),
      Height => Float (R.Last_Frame_Height),
      Color  => R.Color_Theme.Default_BG,
      Layer  => RM.Rectangle_Base_Background);

   Build_Text_Runs (R, Snapshot);
   Build_Shaped_Run_Map (R, Snapshot, 1);

   for Row in 1 .. Snapshot.Rows loop
      for Col in 1 .. Snapshot.Cols loop
         declare
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snapshot, Row, Col);
            X    : constant Float :=
              Float (Origin_X (R) + (Col - 1) * R.CW);
            Y    : constant Float :=
              Float (Origin_Y (R) + (Row - 1) * R.CH);
            Cell_W : constant Positive :=
              (if Cell.Text.Width = Terminal.Core.Width_Two then R.CW * 2 else R.CW);
            Cursor_Cell : constant Boolean := Is_Cursor_Cell (Snapshot, Row, Col);
            Block_Cursor : constant Boolean :=
              Is_Block_Cursor (Snapshot, Row, Col);
            FG : constant RM.Pixel_Color :=
              (if Block_Cursor
               then R.Color_Theme.Cursor_FG
               else Foreground (R, Cell));
            BG : constant RM.Pixel_Color := Background (R, Cell);
         begin
            if Cell.Kind /= Terminal.Core.Wide_Continuation then
               Add_Rectangle
                 (R,
                  X      => X,
                  Y      => Y,
                  Width  => Float (Cell_W),
                  Height => Float (R.CH),
                  Color  => BG,
                  Layer  =>
                    (if Has_Non_Default_Background (Cell)
                     then RM.Rectangle_Cell_Background
                     else RM.Rectangle_Base_Background));
               if Cursor_Cell then
                  case Snapshot.Cursor.Shape is
                     when Terminal.Core.Cursor_Block =>
                        Add_Rectangle
                          (R,
                           X      => X,
                           Y      => Cursor_Block_Y (R, Y),
                           Width  => Float (Cell_W),
                           Height => Float (Cursor_Block_Height (R)),
                           Color  => R.Color_Theme.Cursor_BG);
                     when Terminal.Core.Cursor_Underline =>
                        Add_Rectangle
                          (R,
                           X      => X,
                           Y      =>
                             Y + Float (R.CH - Cursor_Underline_Height (R)),
                           Width  => Float (Cell_W),
                           Height => Float (Cursor_Underline_Height (R)),
                           Color  => R.Color_Theme.Cursor_BG);
                     when Terminal.Core.Cursor_Bar =>
                        Add_Rectangle
                          (R,
                           X      => X,
                           Y      => Cursor_Block_Y (R, Y),
                           Width  => Float (Cursor_Bar_Width (R)),
                           Height => Float (Cursor_Block_Height (R)),
                           Color  => R.Color_Theme.Cursor_BG);
                  end case;
               end if;
            end if;

            if Is_Drawable (Cell) and then not Cell.Style.Conceal then
               declare
                  Glyph_Render_Status : Render_Status;
                  Run_Entry           : constant Shaped_Run_Map_Entry :=
                    Shaped_Run_At (R, Snapshot.Cols, Row, Col);
               begin
                  if Run_Entry.Starts_Here then
                     if not Draw_Emoji_Run_Color
                       (R, R.Text_Runs (Run_Entry.Run_Index))
                     then
                        Draw_Shaped_Run
                          (R,
                           Run    => R.Text_Runs (Run_Entry.Run_Index),
                           Status => Glyph_Render_Status);
                        if Glyph_Render_Status /= Ok then
                           Set_Render_Status (R, Status, Glyph_Render_Status);
                           return;
                        end if;
                     end if;
                  elsif Run_Entry.Run_Index = 0 then
                     Draw_Glyph
                       (R,
                        Codepoint => Cell.Text.Code_Point,
                        X         => X,
                        Y         => Y,
                        Color     => FG,
                        Bold      => Cell.Style.Bold,
                        Italic    => Cell.Style.Italic,
                        Status    => Glyph_Render_Status);
                     if Glyph_Render_Status /= Ok then
                        Set_Render_Status (R, Status, Glyph_Render_Status);
                        return;
                     end if;

                     for I in 1 .. Cell.Text.Attachment_Count loop
                        if Terminal.Core.Is_Renderable_Attachment
                          (Cell.Text.Attachments (I))
                        then
                           Draw_Glyph
                             (R,
                              Codepoint => Cell.Text.Attachments (I),
                              X         => X,
                              Y         => Y,
                              Color     => FG,
                              Bold      => Cell.Style.Bold,
                              Italic    => Cell.Style.Italic,
                              Status    => Glyph_Render_Status);
                           if Glyph_Render_Status /= Ok then
                              Set_Render_Status
                                (R, Status, Glyph_Render_Status);
                              return;
                           end if;
                        end if;
                     end loop;
                  end if;
               end;

               if Cell.Style.Overline then
                  Add_Rectangle
                    (R,
                     X      => X,
                     Y      => Y,
                     Width  => Float (Cell_W),
                     Height => 1.0,
                     Color  => FG);
               end if;

               if Cell.Style.Underline or else Is_Hovered_Link_Cell (R, Cell) then
                  Add_Underline
                    (R,
                     (if Cell.Style.Underline
                      then Cell.Style.Underline_Kind
                      else Terminal.Core.Underline_Single),
                     X,
                     Y,
                     Float (Cell_W),
                     Underline_Color (R, Cell, FG));
               end if;

               if Cell.Style.Strikethrough then
                  Add_Rectangle
                    (R,
                     X      => X,
                     Y      => Y + Float (R.CH) / 2.0,
                     Width  => Float (Cell_W),
                     Height => 1.0,
                     Color  => FG);
               end if;
            end if;
         end;
      end loop;
   end loop;

   Synchronize_Graphics_Screen (R, Snapshot);
   if Snapshot.Graphics.Pending then
      Synchronize_Graphics_Scroll
        (R, Snapshot, Snapshot.Graphics.Scroll_Sequence);
   end if;
   Add_Image (R, Snapshot.Graphics, Snapshot);
   if R.Graphics_Event_Tracking_Failed then
      Release_Frame (R);
      Set_Render_Status (R, Status, Allocation_Failed);
      return;
   end if;
   Advance_Animations (R);
   Synchronize_Graphics_Screen (R, Snapshot);
   Synchronize_Graphics_Scroll
     (R, Snapshot, Snapshot.Graphics_Scroll_Current);
   Add_Conventional_Images (R, Snapshot);
   Add_Placeholder_Images (R, Snapshot);
   if R.Graphics_Event_Tracking_Failed then
      Release_Frame (R);
      Set_Render_Status (R, Status, Allocation_Failed);
      return;
   end if;

   Add_Link_Overlay (R, Snapshot, Status);
   if Status /= Ok then
      Set_Render_Status (R, Status, Status);
      return;
   end if;
   if R.Frame_Command_Overflowed then
      Release_Frame (R);
      Set_Render_Status (R, Status, Allocation_Failed);
      return;
   end if;

   R.Atlas_Dirty := R.Atlas_Dirty or else Textrender.Atlas_Dirty (R.Text);
   R.Colour_Sheet_Dirty :=
     R.Colour_Sheet_Dirty or else Textrender.Colour_Sheet_Dirty (R.Text);

   declare
      Batch_Status : VS.Build_Status;
   begin
      VS.Build (Last_Frame (R), R.Batch, Batch_Status);
      if Batch_Status /= VS.Ok then
         Set_Render_Status (R, Status, Batch_Build_Failed);
         return;
      end if;
      R.Vertex_Count := VS.Vertex_Count (R.Batch);
   end;

   --  The single-snapshot entry point has no separate presentation phase;
   --  a successful build is its commit boundary. The GUI uses Render_App
   --  and commits only after the presenter accepts the frame.
   Commit_Graphics_Events (R);
   Set_Render_Status (R, Status, Ok);
end Render;
