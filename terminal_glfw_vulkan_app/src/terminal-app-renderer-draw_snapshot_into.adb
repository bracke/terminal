separate (Terminal.App.Renderer)
procedure Draw_Snapshot_Into
  (R            : in out Renderer;
   Snapshot     : Terminal.Core.Render_Snapshot;
   Cache_Index  : Terminal.App.Splits.Pane_Index;
   Show_Overlay : Boolean;
   Status       : out Render_Status)
is
   First_Run : constant Positive := R.Frame_State.Text_Run_Count + 1;
   procedure Add_Scrollbar is
      Total : constant Natural := Terminal.Core.Scrollback_Rows (Snapshot);
      Offset : constant Natural :=
        Natural'Min (Terminal.Core.Scrollback_Offset (Snapshot), Total);
      Track_Height : constant Float := Float (Snapshot.Rows * R.Text_State.CH);
      Thumb_Height : Float;
      Thumb_Y : Float;
      X : constant Float :=
        Float (Origin_X (R) + Snapshot.Cols * R.Text_State.CW - 3);
   begin
      if Total = 0 then return; end if;
      Thumb_Height :=
        Float'Max
          (8.0,
           Track_Height * Float (Snapshot.Rows)
             / Float (Total + Snapshot.Rows));
      Thumb_Height := Float'Min (Track_Height, Thumb_Height);
      Thumb_Y :=
        Float (Origin_Y (R))
        + (Track_Height - Thumb_Height)
          * Float (Total - Offset) / Float (Total);
      Drawing_Commands.Add_Rectangle
        (R, X, Float (Origin_Y (R)), 3.0, Track_Height,
         (R => 0.0, G => 0.0, B => 0.0, A => 0.28));
      Drawing_Commands.Add_Rectangle
        (R, X, Thumb_Y, 3.0, Thumb_Height,
         (R.View_State.Color_Theme.Default_FG with delta A => 0.75));
   end Add_Scrollbar;
begin
   Build_Text_Runs (R, Snapshot, Cache_Index);
   Build_Shaped_Run_Map (R, Snapshot, First_Run);

   for Row in 1 .. Snapshot.Rows loop
      declare
         First_Rectangle : constant Positive :=
           R.Frame_State.Rectangle_Count + 1;
         First_Glyph : constant Positive := R.Frame_State.Glyph_Count + 1;
         First_Colour : constant Positive :=
           R.Frame_State.Colour_Glyph_Count + 1;
         First_Color_Diagnostic : constant Natural :=
           R.Text_State.Color_Glyph_Count;
         First_Emoji_Fallback : constant Natural :=
           R.Text_State.Color_Emoji_Fallback_Count;
         First_Missing_Glyph : constant Natural :=
           R.Text_State.Missing_Glyph_Count;
      begin
      if Text_Pipeline.Append_Cached_Row (R, Cache_Index, Row) then
         null;
      else
      for Col in 1 .. Snapshot.Cols loop
         declare
            Cell : constant Terminal.Core.Cell_Content :=
              Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
            X    : constant Float :=
              Float (Origin_X (R) + (Col - 1) * R.Text_State.CW);
            Y    : constant Float :=
              Float (Origin_Y (R) + (Row - 1) * R.Text_State.CH);
            Cell_W : constant Positive :=
              (if Cell.Text.Width = Terminal.Core.Width_Two then R.Text_State.CW * 2 else R.Text_State.CW);
            Cursor_Cell : constant Boolean :=
              Style.Is_Cursor_Cell (Snapshot, Row, Col);
            Block_Cursor : constant Boolean :=
              Style.Is_Block_Cursor (Snapshot, Row, Col);
            FG : constant RM.Pixel_Color :=
              (if Block_Cursor
               then R.View_State.Color_Theme.Cursor_FG
               else Style.Foreground (R, Cell));
            BG : constant RM.Pixel_Color := Style.Background (R, Cell);
         begin
            if Cell.Kind /= Terminal.Core.Wide_Continuation then
               Drawing_Commands.Add_Rectangle
                 (R,
                  X      => X,
                  Y      => Y,
                  Width  => Float (Cell_W),
                  Height => Float (R.Text_State.CH),
                  Color  => BG,
                  Layer  =>
                    (if Style.Has_Non_Default_Background (Cell)
                     then RM.Rectangle_Cell_Background
                     else RM.Rectangle_Base_Background));
               if Cursor_Cell then
                  case Snapshot.Cursor.Shape is
                     when Terminal.Core.Cursor_Block =>
                        Drawing_Commands.Add_Rectangle
                          (R,
                           X      => X,
                           Y      => Style.Cursor_Block_Y (R, Y),
                           Width  => Float (Cell_W),
                           Height => Float (Style.Cursor_Block_Height (R)),
                           Color  => R.View_State.Color_Theme.Cursor_BG);
                     when Terminal.Core.Cursor_Underline =>
                        Drawing_Commands.Add_Rectangle
                          (R,
                           X      => X,
                           Y      =>
                             Y + Float
                               (R.Text_State.CH
                                - Style.Cursor_Underline_Height (R)),
                           Width  => Float (Cell_W),
                           Height => Float
                             (Style.Cursor_Underline_Height (R)),
                           Color  => R.View_State.Color_Theme.Cursor_BG);
                     when Terminal.Core.Cursor_Bar =>
                        Drawing_Commands.Add_Rectangle
                          (R,
                           X      => X,
                           Y      => Style.Cursor_Block_Y (R, Y),
                           Width  => Float (Style.Cursor_Bar_Width (R)),
                           Height => Float (Style.Cursor_Block_Height (R)),
                           Color  => R.View_State.Color_Theme.Cursor_BG);
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
                       (R, R.Frame_State.Text_Runs (Run_Entry.Run_Index))
                     then
                        Draw_Shaped_Run
                          (R,
                           Run    => R.Frame_State.Text_Runs (Run_Entry.Run_Index),
                           Status => Glyph_Render_Status);
                        if Glyph_Render_Status /= Ok then
                           Status := Glyph_Render_Status;
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
                        Status := Glyph_Render_Status;
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
                              Status := Glyph_Render_Status;
                              return;
                           end if;
                        end if;
                     end loop;
                  end if;
               end;

               if Cell.Style.Overline then
                  Drawing_Commands.Add_Rectangle
                    (R,
                     X      => X,
                     Y      => Y,
                     Width  => Float (Cell_W),
                     Height => 1.0,
                     Color  => FG);
               end if;

               if Cell.Style.Underline
                 or else Style.Is_Hovered_Link_Cell (R, Snapshot, Row, Col)
               then
                  Add_Underline
                    (R,
                     (if Cell.Style.Underline
                      then Cell.Style.Underline_Kind
                      else Terminal.Core.Underline_Single),
                     X,
                     Y,
                     Float (Cell_W),
                     Style.Underline_Color (R, Cell, FG));
               end if;

               if Cell.Style.Strikethrough then
                  Drawing_Commands.Add_Rectangle
                    (R,
                     X      => X,
                     Y      => Y + Float (R.Text_State.CH) / 2.0,
                     Width  => Float (Cell_W),
                     Height => 1.0,
                     Color  => FG);
               end if;
            end if;
         end;
      end loop;
      Text_Pipeline.Capture_Row
        (R, Cache_Index, Row, First_Rectangle, First_Glyph, First_Colour,
         First_Color_Diagnostic, First_Emoji_Fallback, First_Missing_Glyph);
      end if;
      end;
   end loop;

   Synchronize_Graphics_Screen (R, Snapshot);
   if Snapshot.Graphics.Pending then
      Synchronize_Graphics_Scroll
        (R, Snapshot, Snapshot.Graphics.Scroll_Sequence);
   end if;
   Add_Image (R, Snapshot.Graphics, Snapshot);
   if R.Graphics_State.Transaction.Event_Tracking_Failed then
      Status := Allocation_Failed;
      return;
   end if;
   Synchronize_Graphics_Screen (R, Snapshot);
   Synchronize_Graphics_Scroll
     (R, Snapshot, Snapshot.Graphics_Scroll_Current);
   Add_Conventional_Images (R, Snapshot);
   Add_Placeholder_Images (R, Snapshot);
   Add_Scrollbar;
   if R.Graphics_State.Transaction.Event_Tracking_Failed then
      Status := Allocation_Failed;
      return;
   end if;

   if Show_Overlay then
      Add_Link_Overlay (R, Snapshot, Status);
   else
      Status := Ok;
   end if;
end Draw_Snapshot_Into;
