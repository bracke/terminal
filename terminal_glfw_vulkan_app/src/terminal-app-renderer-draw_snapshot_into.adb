separate (Terminal.App.Renderer)
procedure Draw_Snapshot_Into
  (R            : in out Renderer;
   Snapshot     : Terminal.Core.Render_Snapshot;
   Show_Overlay : Boolean;
   Status       : out Render_Status)
is
   First_Run : constant Positive := R.Text_Run_Count + 1;
begin
   Build_Text_Runs (R, Snapshot);
   Build_Shaped_Run_Map (R, Snapshot, First_Run);

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
      Status := Allocation_Failed;
      return;
   end if;
   Synchronize_Graphics_Screen (R, Snapshot);
   Synchronize_Graphics_Scroll
     (R, Snapshot, Snapshot.Graphics_Scroll_Current);
   Add_Conventional_Images (R, Snapshot);
   Add_Placeholder_Images (R, Snapshot);
   if R.Graphics_Event_Tracking_Failed then
      Status := Allocation_Failed;
      return;
   end if;

   if Show_Overlay then
      Add_Link_Overlay (R, Snapshot, Status);
   else
      Status := Ok;
   end if;
end Draw_Snapshot_Into;
