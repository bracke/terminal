separate (Terminal.App.Renderer)
function Store_Virtual_Placement
  (R         : in out Renderer;
   Event     : Terminal.Core.Graphics_Event;
   Header    : Terminal.App.Graphics.Graphics_Header;
   Prepared  : in out Virtual_Placement_Access)
   return Placement_Store_Status
is
   Placement : Virtual_Placement_Access :=
     Find_Addressed_Virtual_Placement
       (R,
        Event.Stream_ID,
        Header.Kitty_ID,
        Header.Kitty_Placement_ID);
   Object : constant Image_Object_Access :=
     Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
   Geometry : constant Placement_Geometry :=
     Resolve_Placement_Geometry (R, Object, Header);
begin
   if Header.Kitty_ID = 0
     or else not Header.Kitty_Virtual_Placement
     or else Header.Kitty_Parent_ID /= 0
     or else not Geometry.Valid
   then
      --  Kitty virtual placements are prototypes, not positioned objects,
      --  and therefore cannot themselves be relative placements.
      return Placement_Rejected;
   end if;

   if Placement = null then
      if R.Kitty_Placement_Count >= R.Graphics_Limits.Placements then
         R.Image_Store_Allocation_Failed := True;
         return Placement_No_Space;
      end if;
      if Prepared /= null then
         Placement := Prepared;
         Prepared := null;
      else
         if not Terminal.App.Image_Store.Allocation_Allowed
           (R.Image_Allocation_Control)
         then
            R.Image_Store_Allocation_Failed := True;
            return Placement_No_Space;
         end if;
         Placement := new Virtual_Placement;
      end if;
      Placement.Next := R.Virtual_Placements;
      R.Virtual_Placements := Placement;
      R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
   elsif Prepared /= null then
      Free_Virtual_Placement (Prepared);
   end if;

   declare
      Next : constant Virtual_Placement_Access := Placement.Next;
   begin
      Placement.all :=
        (Stream_ID      => Event.Stream_ID,
         Alternate_Screen => Event.Alternate_Screen,
         Screen_Generation => Event.Screen_Generation,
         Image_ID       => Header.Kitty_ID,
         Image_Storage_Order => Object.Storage_Order,
         Placement_ID   => Header.Kitty_Placement_ID,
         Columns        => Geometry.Columns,
         Rows           => Geometry.Rows,
         Source_X       => Header.Kitty_Source_X,
         Source_Y       => Header.Kitty_Source_Y,
         Source_Width   => Header.Kitty_Source_Width,
         Source_Height  => Header.Kitty_Source_Height,
         Cell_X         => Header.Kitty_Cell_X,
         Cell_Y         => Header.Kitty_Cell_Y,
         Draw_Offset_X  => Geometry.Draw_Offset_X,
         Draw_Offset_Y  => Geometry.Draw_Offset_Y,
         Draw_Width     => Geometry.Draw_Width,
         Draw_Height    => Geometry.Draw_Height,
         Z_Index        => Header.Kitty_Z_Index,
         Parent_Offset_X => 0,
         Parent_Offset_Y => 0,
         Next           => Next);
   end;
   Move_Relative_Descendants
     (R,
      Event.Stream_ID,
      Header.Kitty_ID,
      Header.Kitty_Placement_ID,
      Event.Alternate_Screen,
      Event.Screen_Generation);
   return Placement_Stored;
exception
   when Storage_Error =>
      R.Image_Store_Allocation_Failed := True;
      return Placement_No_Space;
end Store_Virtual_Placement;
