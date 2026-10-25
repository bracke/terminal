separate (Terminal.App.Renderer)
function Store_Auxiliary_Placement
  (R           : in out Renderer;
   Event       : Terminal.Core.Graphics_Event;
   Protocol    : RM.Image_Protocol;
   Draw_Width  : Positive;
   Draw_Height : Positive) return Boolean
is
   Object : constant Image_Object_Access :=
     Find_Image_Object_By_Storage_Order
       (R, Event.Stream_ID, R.Last_Stored_Image_Order);
   Placement : Conventional_Placement_Access;
   Columns : Positive;
   Rows : Positive;
begin
   if Object = null
     or else R.Kitty_Placement_Count >= R.Graphics_Limits.Placements
   then
      return False;
   end if;
   Columns := Positive'Max (1, 1 + (Draw_Width - 1) / R.CW);
   Rows := Positive'Max (1, 1 + (Draw_Height - 1) / R.CH);
   if not Terminal.App.Image_Store.Allocation_Allowed
     (R.Image_Allocation_Control)
   then
      return False;
   end if;
   Placement := new Conventional_Placement'
     (Stream_ID      => Event.Stream_ID,
      Alternate_Screen => Event.Alternate_Screen,
      Screen_Generation => Event.Screen_Generation,
      Image_ID       => 0,
      Image_Storage_Order => Object.Storage_Order,
      Protocol       => Protocol,
      Placement_ID   => 0,
      Row            => Event.Row,
      Col            => Event.Col,
      Columns        => Columns,
      Rows           => Rows,
      Source_X       => 0,
      Source_Y       => 0,
      Source_Width   => 0,
      Source_Height  => 0,
      Cell_X         => 0,
      Cell_Y         => 0,
      Draw_Offset_X  => 0,
      Draw_Offset_Y  => 0,
      Draw_Width     => Draw_Width,
      Draw_Height    => Draw_Height,
      Z_Index        => 0,
      Parent_Image_ID => 0,
      Parent_Placement_ID => 0,
      Parent_Offset_X => 0,
      Parent_Offset_Y => 0,
      Scroll_Sequence => Event.Scroll_Sequence,
      Clip_Top        => 0,
      Clip_Bottom     => 0,
      History_Attached => False,
      Next           => R.Conventional_Placements);
   R.Conventional_Placements := Placement;
   R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
   return True;
exception
   when Storage_Error | Constraint_Error =>
      return False;
end Store_Auxiliary_Placement;
