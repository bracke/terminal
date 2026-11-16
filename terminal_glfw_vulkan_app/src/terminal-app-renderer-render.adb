separate (Terminal.App.Renderer)
procedure Render
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot;
   Status   : out Render_Status)
is
   Cell_Count          : Natural;
   Rect_Max            : Natural;
   Glyph_Max           : Natural;
   Image_Max           : Natural;
   Background_Image_Max : Natural;
   Content_Width       : Natural;
   Content_Height      : Natural;
   Intermediate        : Natural;
   Image_Intermediate  : Natural;
   Draw_Status         : Render_Status;
   Text_Run_Initial    : Natural;
begin
   if not R.Lifecycle.Initialized or else not R.Text_State.Text_Loaded then
      Set_Render_Status (R, Status, Not_Initialized);
      return;
   elsif not Terminal.Core.Is_Valid (Snapshot)
     or else not Event_Tracking.Payload_Available (R, Snapshot.Graphics)
   then
      Set_Render_Status (R, Status, Invalid_Snapshot);
      return;
   end if;

   Set_Visible_Graphics_View (R, Snapshot);

   if not Terminal.App.Size_Arithmetic.Try_Multiply
     (Snapshot.Rows, Snapshot.Cols, Cell_Count)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Cell_Count, 5, Rect_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Cell_Count, Max_Link_Overlay_Chars, Glyph_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Terminal.Core.Image_Cell_Count (Snapshot),
        Placements_State.Stored_Placement_Count (R), Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate,
        Additional_Frame_Image_Commands (R, Snapshot.Graphics),
        Image_Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Image_Intermediate,
        Additional_Frame_Image_Commands (R, Snapshot.Graphics),
        Image_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Image_Max,
        (if R.View_State.Background_Object = null then 0 else 1),
        Background_Image_Max)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Snapshot.Cols, R.Text_State.CW, Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate, R.View_State.Content_Padding * 2, Content_Width)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Snapshot.Rows, R.Text_State.CH, Intermediate)
     or else not Terminal.App.Size_Arithmetic.Try_Add
       (Intermediate, R.View_State.Content_Padding * 2, Content_Height)
   then
      Set_Render_Status (R, Status, Invalid_Snapshot);
      return;
   end if;
   Text_Run_Initial := Cell_Count / 4;
   if Cell_Count mod 4 /= 0 then
      Text_Run_Initial := Text_Run_Initial + 1;
   end if;

   Frame_Lifecycle.Prepare
     (R,
      Cell_Count,
      Natural'Max (Content_Width, R.Frame_State.Target_Frame_Width),
      Natural'Max (Content_Height, R.Frame_State.Target_Frame_Height),
      Rectangle_Count => Positive (Rect_Max),
      Glyph_Count => Positive (Glyph_Max),
      --  One tile per cell is the most a frame can ask for, and emoji are
      --  rare enough that a smaller cap would be a cliff rather than a saving.
      Colour_Count => Positive (Natural'Max (1, Natural'Min (Cell_Count, 64))),
      Image_Count => Positive (Natural'Max (1, Background_Image_Max)),
      Text_Run_Count => Positive (Natural'Max (1, Text_Run_Initial)),
      Map_Cell_Count => Positive (Cell_Count),
      Status => Status);
   if Status /= Ok then
      return;
   end if;
   Frame_Lifecycle.Record_Dirty_Rows (R, Snapshot);

   Drawing_Commands.Add_Rectangle
     (R,
      X      => 0.0,
      Y      => 0.0,
      Width  => Float (R.Frame_State.Last_Frame_Width),
      Height => Float (R.Frame_State.Last_Frame_Height),
      Color  => R.View_State.Color_Theme.Default_BG,
      Layer  => RM.Rectangle_Base_Background);

   Add_Background_Image (R);

   Draw_Snapshot_Into
     (R,
      Snapshot,
      Cache_Index  => 1,
      Show_Overlay => True,
      Status       => Draw_Status);
   if Draw_Status /= Ok then
      if Draw_Status = Allocation_Failed then
         Frame_Lifecycle.Release (R);
      end if;
      Set_Render_Status (R, Status, Draw_Status);
      return;
   end if;
   Frame_Lifecycle.Finish (R, Status);
   if Status /= Ok then
      return;
   end if;

   --  The single-snapshot entry point has no separate presentation phase;
   --  a successful build is its commit boundary. The GUI uses Render_App
   --  and commits only after the presenter accepts the frame.
   Commit_Graphics_Events (R);
end Render;
