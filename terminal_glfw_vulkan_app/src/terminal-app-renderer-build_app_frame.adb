separate (Terminal.App.Renderer)
procedure Build_App_Frame
  (R              : in out Renderer;
   Snapshots      : Snapshot_Array;
   Active_Index   : Positive;
   Tabs           : Terminal.App.Tabs.Tab_Snapshot;
   Layout         : Terminal.App.Splits.Pane_Layout;
   Status         : out Render_Status)
is
   Cell_Count : Natural := 0;
   Rect_Max   : Natural;
   Glyph_Max  : Natural;
   Text_Run_Max : Natural := 0;
   Colour_Max : Natural := 0;
   Image_Max  : Natural := 0;
   Image_Cell_Max : Natural := 0;
   Tab_Height : constant Natural :=
     (if Tab_Bar_Visible (R, Natural (Tabs.Count))
      then R.Text_State.CH + Pane_Border_Pixels else 0);
   Frame_W : Natural := 0;
   Frame_H : Natural := Tab_Height;
   Pane_X  : Natural := 0;
   Pane_Y  : Natural := Tab_Height;
   Draw_Status : Render_Status;
   Intermediate : Natural := 0;
   Pane_Cells : Natural := 0;
   Pane_W : Natural := 0;
   Pane_H : Natural := 0;
   Tab_Glyphs : Natural := 0;
   Placement_Images : Natural := 0;
   Event_Images : Natural := 0;
   Event_Image_Slots : Natural := 0;
   Legacy_Flat : constant Boolean :=
     Layout.Count > 1 and then Layout.Divider_Count = 0;
   Legacy_Orientation : constant Terminal.App.Splits.Split_Orientation :=
     Layout.Dividers (1).Orientation;

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
     (S.Cols * R.Text_State.CW + R.View_State.Content_Padding * 2);

   function Pane_Height (S : Terminal.Core.Render_Snapshot) return Natural is
     (S.Rows * R.Text_State.CH + R.View_State.Content_Padding * 2);

   procedure Draw_Pane_Border
     (X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural;
      Active : Boolean)
   is
      Color : constant RM.Pixel_Color :=
        (if Active then R.View_State.Color_Theme.Cursor_BG else
           (R => 0.22, G => 0.24, B => 0.27, A => 1.0));
      Thickness : constant Float := Float (Pane_Border_Pixels);
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;
      Drawing_Commands.Add_Rectangle (R, Float (X), Float (Y), Float (Width), Thickness, Color);
      Drawing_Commands.Add_Rectangle
        (R,
         Float (X),
         Float (Y + Height - Pane_Border_Pixels),
         Float (Width),
         Thickness,
         Color);
      Drawing_Commands.Add_Rectangle (R, Float (X), Float (Y), Thickness, Float (Height), Color);
      Drawing_Commands.Add_Rectangle
        (R,
         Float (X + Width - Pane_Border_Pixels),
         Float (Y),
         Thickness,
         Float (Height),
         Color);
   end Draw_Pane_Border;

   procedure Draw_Tab_Bar is
   begin
      if not Tab_Bar_Visible (R, Natural (Tabs.Count)) then
         return;
      end if;

      declare
         Count : constant Positive := Positive (Tabs.Count);
         Base  : constant Natural := Frame_W / Count;
         Extra : constant Natural := Frame_W mod Count;
         X     : Natural := 0;
      begin
         Drawing_Commands.Add_Rectangle
           (R,
            X      => 0.0,
            Y      => 0.0,
            Width  => Float (Frame_W),
            Height => Float (Tab_Height),
            Color  => R.View_State.Tabs.Bar_Background);

         for I in 1 .. Tabs.Count loop
            declare
               Width : constant Natural :=
                 Base + (if Natural (I) <= Extra then 1 else 0);
               Col_Width : constant Natural :=
                 (if Width = 0 then 0 else Width / R.Text_State.CW);
               Active : constant Boolean := I = Tabs.Active;
            begin
               if Width > 0 then
                  Drawing_Commands.Add_Rectangle
                    (R,
                     X      => Float (X),
                     Y      => 0.0,
                     Width  => Float (Width),
                     Height => Float (R.Text_State.CH),
                     Color  =>
                       (if Active
                        then R.View_State.Tabs.Active_Background
                        else R.View_State.Tabs.Inactive_Background));
                  if Col_Width > 0 then
                     declare
                        Label : constant String :=
                          Terminal.App.Tabs.Fitted_Label
                            (Tabs.Labels (I),
                             (if Col_Width > 2 then Col_Width - 2 else Col_Width));
                     begin
                        Draw_Label
                          (R,
                           Text   => Label,
                           X      => Float (X + 1),
                           Y      => 0.0,
                           Limit  => Col_Width,
                           Color  => R.View_State.Color_Theme.Default_FG,
                           Status => Draw_Status);
                     end;
                     if Draw_Status /= Ok then
                        Status := Draw_Status;
                        return;
                     end if;
                     if Col_Width > 2 then
                        Draw_Label
                          (R,
                           Text   => "x",
                           X      => Float (X + Width - R.Text_State.CW),
                           Y      => 0.0,
                           Limit  => 1,
                           Color  => R.View_State.Color_Theme.Default_FG,
                           Status => Draw_Status);
                        if Draw_Status /= Ok then
                           Status := Draw_Status;
                           return;
                        end if;
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
   if not R.Lifecycle.Initialized or else not R.Text_State.Text_Loaded then
      Set_Render_Status (R, Status, Not_Initialized);
      return;
   end if;

   for I in Snapshots'Range loop
      if not Terminal.Core.Is_Valid (Snapshots (I))
        or else not Event_Tracking.Payload_Available
          (R, Snapshots (I).Graphics)
        or else not Terminal.App.Size_Arithmetic.Try_Multiply
          (Snapshots (I).Rows, Snapshots (I).Cols, Pane_Cells)
        or else not Accumulate (Cell_Count, Pane_Cells)
        or else not Terminal.App.Size_Arithmetic.Try_Multiply
          (Snapshots (I).Cols, R.Text_State.CW, Intermediate)
        or else not Terminal.App.Size_Arithmetic.Try_Add
          (Intermediate, R.View_State.Content_Padding * 2, Pane_W)
        or else not Terminal.App.Size_Arithmetic.Try_Multiply
          (Snapshots (I).Rows, R.Text_State.CH, Intermediate)
        or else not Terminal.App.Size_Arithmetic.Try_Add
          (Intermediate, R.View_State.Content_Padding * 2, Pane_H)
      then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;
      if not Accumulate
        (Image_Cell_Max, Terminal.Core.Image_Cell_Count (Snapshots (I)))
      then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;
      if Legacy_Flat then
         if Legacy_Orientation = Terminal.App.Splits.Vertical then
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
            if not Accumulate (Frame_H, Pane_H) then
               Set_Render_Status (R, Status, Invalid_Snapshot);
               return;
            end if;
         end if;
      else
         declare
            X : constant Natural :=
              (Layout.Rects (I).Col - 1) * R.Text_State.CW;
            Y : constant Natural :=
              Tab_Height + (Layout.Rects (I).Row - 1) * R.Text_State.CH;
         begin
         if not Terminal.App.Size_Arithmetic.Try_Add (X, Pane_W, Intermediate)
         then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
         Frame_W := Natural'Max (Frame_W, Intermediate);
         if not Terminal.App.Size_Arithmetic.Try_Add (Y, Pane_H, Intermediate)
         then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
         Frame_H := Natural'Max (Frame_H, Intermediate);
         end;
      end if;
   end loop;

   Set_Visible_Graphics_Views (R, Snapshots);

   Text_Run_Max := Cell_Count / 4;
   if Cell_Count mod 4 /= 0 then
      Text_Run_Max := Text_Run_Max + 1;
   end if;
   Colour_Max := Natural'Max (1, Natural'Min (Cell_Count, 64));
   Glyph_Max := Cell_Count;
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
     (Placements_State.Stored_Placement_Count (R),
      Natural (Snapshots'Length),
      Placement_Images)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Event_Images, 2, Event_Image_Slots)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Image_Cell_Max, Placement_Images, Image_Max)
     or else not Accumulate (Image_Max, Event_Image_Slots)
     or else
       (R.View_State.Background_Object /= null
        and then not Accumulate (Image_Max, 1))
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Cell_Count, 1, Rect_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Natural (Snapshots'Length), 8, Intermediate)
     or else not Accumulate (Rect_Max, Intermediate)
     or else not Accumulate (Rect_Max, Natural (Tabs.Count))
     or else not Accumulate (Rect_Max, 8)
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

   Frame_W := Natural'Max (Frame_W, R.Frame_State.Target_Frame_Width);
   Frame_H := Natural'Max (Frame_H, R.Frame_State.Target_Frame_Height);

   Frame_Lifecycle.Prepare
     (R,
      Cell_Count,
      Frame_W,
      Frame_H,
      Rectangle_Count => Positive (Natural'Max (1, Rect_Max)),
      Glyph_Count => Positive (Natural'Max (1, Glyph_Max)),
      Colour_Count => Positive (Natural'Max (1, Colour_Max)),
      Image_Count => Positive (Natural'Max (1, Image_Max)),
      Text_Run_Count => Positive (Natural'Max (1, Text_Run_Max)),
      Map_Cell_Count => Positive (Natural'Max (1, Cell_Count)),
      Status => Status);
   if Status /= Ok then
      return;
   end if;
   for I in Snapshots'Range loop
      Frame_Lifecycle.Record_Dirty_Rows (R, Snapshots (I));
   end loop;

   Drawing_Commands.Add_Rectangle
     (R,
      X      => 0.0,
      Y      => 0.0,
      Width  => Float (R.Frame_State.Last_Frame_Width),
      Height => Float (R.Frame_State.Last_Frame_Height),
      Color  => R.View_State.Color_Theme.Default_BG,
      Layer  => RM.Rectangle_Base_Background);

   Add_Background_Image (R);

   Draw_Tab_Bar;
   if Status /= Ok then
      Set_Render_Status (R, Status, Status);
      return;
   end if;

   for I in Snapshots'Range loop
      declare
         W : constant Natural := Pane_Width (Snapshots (I));
         H : constant Natural := Pane_Height (Snapshots (I));
         X : constant Natural :=
           (if Legacy_Flat then Pane_X
            else (Layout.Rects (I).Col - 1) * R.Text_State.CW);
         Y : constant Natural :=
           (if Legacy_Flat then Pane_Y
            else Tab_Height + (Layout.Rects (I).Row - 1) * R.Text_State.CH);
      begin
         Draw_Pane_Border
           (X,
            Y,
            W,
            H,
            Active_Index = I);
         R.Frame_State.Draw_Offset_X := X;
         R.Frame_State.Draw_Offset_Y := Y;
         Draw_Snapshot_Into
           (R,
            Snapshots (I),
            Cache_Index  => Terminal.App.Splits.Pane_Index (I),
            Show_Overlay => Active_Index = I,
            Status       => Draw_Status);
         if Draw_Status /= Ok then
            R.Frame_State.Draw_Offset_X := 0;
            R.Frame_State.Draw_Offset_Y := 0;
            Set_Render_Status (R, Status, Draw_Status);
            return;
         end if;
         if Legacy_Flat then
            if Legacy_Orientation = Terminal.App.Splits.Vertical then
               Pane_X := Pane_X + W;
            else
               Pane_Y := Pane_Y + H;
            end if;
         end if;
      end;
   end loop;

   R.Frame_State.Draw_Offset_X := 0;
   R.Frame_State.Draw_Offset_Y := 0;

   Frame_Lifecycle.Finish (R, Status);
end Build_App_Frame;
