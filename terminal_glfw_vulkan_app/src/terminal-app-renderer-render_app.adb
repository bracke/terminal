separate (Terminal.App.Renderer)
procedure Render_App
  (R              : in out Renderer;
   Snapshots      : Snapshot_Array;
   Active_Index   : Positive;
   Tabs           : Terminal.App.Tabs.Tab_Snapshot;
   Splits         : Terminal.App.Splits.Split_Snapshot;
   Status         : out Render_Status)
is
   Cell_Count : Natural := 0;
   Rect_Max   : Natural;
   Glyph_Max  : Natural;
   Text_Run_Max : Natural := 0;
   Colour_Max : Natural := 0;
   Image_Max  : Natural := 0;
   Tab_Height : constant Natural :=
     (if Tabs.Count > 1 then R.CH + Pane_Border_Pixels else 0);
   Frame_W : Natural := 0;
   Frame_H : Natural := Tab_Height;
   Pane_X  : Natural := 0;
   Pane_Y  : Natural := Tab_Height;
   Draw_Status : Render_Status;
   Capacity_Ok : Boolean;
   Intermediate : Natural := 0;
   Pane_Cells : Natural := 0;
   Pane_W : Natural := 0;
   Pane_H : Natural := 0;
   Tab_Glyphs : Natural := 0;
   Rectangles_Per_Cell : Natural := 0;
   Placement_Images : Natural := 0;
   Event_Images : Natural := 0;
   Glyphs_Per_Cell : constant Natural :=
     Natural'Max
       (Terminal.Core.Max_Cluster_Attachments + 1,
        RM.Max_Shaped_Glyphs_Per_Run) * 2;

   function Accumulate
     (Value     : in out Natural;
      Increment : Natural) return Boolean
   is
      Sum : Natural;
   begin
      if not Terminal.App.Size_Arithmetic.Try_Add
        (Value, Increment, Sum)
      then
         return False;
      end if;
      Value := Sum;
      return True;
   end Accumulate;

   function Pane_Width (S : Terminal.Core.Render_Snapshot) return Natural is
     (S.Cols * R.CW + Content_Margin * 2);

   function Pane_Height (S : Terminal.Core.Render_Snapshot) return Natural is
     (S.Rows * R.CH + Content_Margin * 2);

   procedure Draw_Pane_Border
     (X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural;
      Active : Boolean)
   is
      Color : constant RM.Pixel_Color :=
        (if Active then R.Color_Theme.Cursor_BG else
           (R => 0.22, G => 0.24, B => 0.27, A => 1.0));
      Thickness : constant Float := Float (Pane_Border_Pixels);
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;
      Add_Rectangle (R, Float (X), Float (Y), Float (Width), Thickness, Color);
      Add_Rectangle
        (R,
         Float (X),
         Float (Y + Height - Pane_Border_Pixels),
         Float (Width),
         Thickness,
         Color);
      Add_Rectangle (R, Float (X), Float (Y), Thickness, Float (Height), Color);
      Add_Rectangle
        (R,
         Float (X + Width - Pane_Border_Pixels),
         Float (Y),
         Thickness,
         Float (Height),
         Color);
   end Draw_Pane_Border;

   procedure Draw_Tab_Bar is
   begin
      if Tabs.Count <= 1 then
         return;
      end if;

      declare
         Count : constant Positive := Positive (Tabs.Count);
         Base  : constant Natural := Frame_W / Count;
         Extra : constant Natural := Frame_W mod Count;
         X     : Natural := 0;
      begin
         Add_Rectangle
           (R,
            X      => 0.0,
            Y      => 0.0,
            Width  => Float (Frame_W),
            Height => Float (Tab_Height),
            Color  => (R => 0.08, G => 0.09, B => 0.10, A => 1.0));

         for I in 1 .. Tabs.Count loop
            declare
               Width : constant Natural :=
                 Base + (if Natural (I) <= Extra then 1 else 0);
               Col_Width : constant Natural :=
                 (if Width = 0 then 0 else Width / R.CW);
               Active : constant Boolean := I = Tabs.Active;
            begin
               if Width > 0 then
                  Add_Rectangle
                    (R,
                     X      => Float (X),
                     Y      => 0.0,
                     Width  => Float (Width),
                     Height => Float (R.CH),
                     Color  =>
                       (if Active
                        then (R => 0.18, G => 0.25, B => 0.34, A => 1.0)
                        else (R => 0.12, G => 0.13, B => 0.15, A => 1.0)));
                  if Col_Width > 0 then
                     declare
                        Label : constant String :=
                          Terminal.App.Tabs.Fitted_Label
                            (Tabs.Labels (I), Col_Width);
                     begin
                        Draw_Label
                          (R,
                           Text   => Label,
                           X      => Float (X + 1),
                           Y      => 0.0,
                           Limit  => Col_Width,
                           Color  => R.Color_Theme.Default_FG,
                           Status => Draw_Status);
                     end;
                     if Draw_Status /= Ok then
                        Status := Draw_Status;
                        return;
                     end if;
                  end if;
               end if;
               X := X + Width;
            end;
         end loop;
      end;

      Status := Ok;
   end Draw_Tab_Bar;
begin
   Status := Ok;
   if not R.Initialized or else not R.Text_Loaded then
      Set_Render_Status (R, Status, Not_Initialized);
      return;
   elsif Snapshots'Length = 0
     or else Active_Index < Snapshots'First
     or else Active_Index > Snapshots'Last
   then
      Set_Render_Status (R, Status, Invalid_Snapshot);
      return;
   end if;

   for I in Snapshots'Range loop
      if Snapshots (I).Rows = 0
        or else Snapshots (I).Cols = 0
        or else not Terminal.App.Size_Arithmetic.Try_Multiply
          (Snapshots (I).Rows, Snapshots (I).Cols, Pane_Cells)
        or else not Accumulate (Cell_Count, Pane_Cells)
        or else not Terminal.App.Size_Arithmetic.Try_Multiply
          (Snapshots (I).Cols, R.CW, Intermediate)
        or else not Terminal.App.Size_Arithmetic.Try_Add
          (Intermediate, Content_Margin * 2, Pane_W)
        or else not Terminal.App.Size_Arithmetic.Try_Multiply
          (Snapshots (I).Rows, R.CH, Intermediate)
        or else not Terminal.App.Size_Arithmetic.Try_Add
          (Intermediate, Content_Margin * 2, Pane_H)
      then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;
      if Splits.Orientation = Terminal.App.Splits.Vertical
        and then Snapshots'Length > 1
      then
         if not Accumulate (Frame_W, Pane_W)
           or else not Terminal.App.Size_Arithmetic.Try_Add
             (Tab_Height, Pane_H, Intermediate)
         then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
         Frame_H := Natural'Max (Frame_H, Intermediate);
      else
         Frame_W := Natural'Max (Frame_W, Pane_W);
         if not Accumulate (Frame_H, Pane_H)
         then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
      end if;
   end loop;

   Text_Run_Max := Cell_Count;
   Colour_Max := Cell_Count;
   for I in Snapshots'Range loop
      if not Accumulate
        (Event_Images,
         Additional_Frame_Image_Commands (R, Snapshots (I).Graphics))
      then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;
   end loop;
   if not Terminal.App.Size_Arithmetic.Try_Multiply
     (R.Kitty_Placement_Count,
      Natural (Snapshots'Length),
      Placement_Images)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Cell_Count, Placement_Images, Image_Max)
     or else not Accumulate (Image_Max, Event_Images)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (R.CW, 4, Rectangles_Per_Cell)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Cell_Count, Rectangles_Per_Cell, Rect_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Natural (Snapshots'Length), 8, Intermediate)
     or else not Accumulate (Rect_Max, Intermediate)
     or else not Accumulate (Rect_Max, Natural (Tabs.Count))
     or else not Accumulate (Rect_Max, 8)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Cell_Count, Glyphs_Per_Cell, Glyph_Max)
     or else not Accumulate (Glyph_Max, Max_Link_Overlay_Chars)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Terminal.App.Tabs.Max_Tab_Label_Length,
        Natural (Tabs.Count),
        Tab_Glyphs)
     or else not Accumulate (Glyph_Max, Tab_Glyphs)
   then
      Set_Render_Status (R, Status, Invalid_Snapshot);
      return;
   end if;

   Frame_W := Natural'Max (Frame_W, R.Target_Frame_Width);
   Frame_H := Natural'Max (Frame_H, R.Target_Frame_Height);

   Reset_Frame (R);
   R.Graphics_Event_Tracking_Failed := False;
   R.Missing_Glyph_Count := 0;
   R.Shaped_Glyph_Count := 0;
   R.Shaping_Fallback_Count := 0;
   R.Text_Fallback_Run_Count := 0;
   R.Color_Glyph_Count := 0;
   R.Color_Emoji_Fallback_Count := 0;
   R.Paragraph_Bidi_Fallback_Count := 0;
   R.Last_Cell_Count := Cell_Count;
   R.Last_Frame_Width := Frame_W;
   R.Last_Frame_Height := Frame_H;
   for I in Snapshots'Range loop
      if Snapshots (I).Dirty /= null then
         if Snapshots (I).Dirty'Length < Snapshots (I).Rows then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
         for Row in 1 .. Snapshots (I).Rows loop
            if Snapshots (I).Dirty (Row) then
               R.Last_Dirty_Rows := R.Last_Dirty_Rows + 1;
            end if;
         end loop;
      end if;
   end loop;

   Ensure_Frame_Capacity
     (R,
      Rectangle_Count => Positive (Natural'Max (1, Rect_Max)),
      Glyph_Count => Positive (Natural'Max (1, Glyph_Max)),
      Colour_Count => Positive (Natural'Max (1, Colour_Max)),
      Image_Count => Positive (Image_Max),
      Text_Run_Count => Positive (Natural'Max (1, Text_Run_Max)),
      Success => Capacity_Ok);
   if not Capacity_Ok then
      Release_Frame (R);
      Set_Render_Status (R, Status, Allocation_Failed);
      return;
   end if;

   Advance_Animations (R);

   Add_Rectangle
     (R,
      X      => 0.0,
      Y      => 0.0,
      Width  => Float (R.Last_Frame_Width),
      Height => Float (R.Last_Frame_Height),
      Color  => R.Color_Theme.Default_BG,
      Layer  => RM.Rectangle_Base_Background);

   Draw_Tab_Bar;
   if Status /= Ok then
      Set_Render_Status (R, Status, Status);
      return;
   end if;

   for I in Snapshots'Range loop
      declare
         W : constant Natural := Pane_Width (Snapshots (I));
         H : constant Natural := Pane_Height (Snapshots (I));
      begin
         Draw_Pane_Border
           (Pane_X,
            Pane_Y,
            W,
            H,
            Active_Index = I);
         R.Draw_Offset_X := Pane_X;
         R.Draw_Offset_Y := Pane_Y;
         Draw_Snapshot_Into
           (R,
            Snapshots (I),
            Show_Overlay => Active_Index = I,
            Status       => Draw_Status);
         if Draw_Status /= Ok then
            R.Draw_Offset_X := 0;
            R.Draw_Offset_Y := 0;
            Set_Render_Status (R, Status, Draw_Status);
            return;
         end if;

         if Splits.Orientation = Terminal.App.Splits.Vertical
           and then Snapshots'Length > 1
         then
            Pane_X := Pane_X + W;
         else
            Pane_Y := Pane_Y + H;
         end if;
      end;
   end loop;

   R.Draw_Offset_X := 0;
   R.Draw_Offset_Y := 0;

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

   Set_Render_Status (R, Status, Ok);
end Render_App;
