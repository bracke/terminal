separate (Terminal.App.Renderer)
function Store_Conventional_Placement
  (R      : in out Renderer;
   Event  : Terminal.Core.Graphics_Event;
   Header : Terminal.App.Graphics.Graphics_Header;
   Prepared : in out Conventional_Placement_Access)
   return Placement_Store_Status
is
   Placement : Conventional_Placement_Access :=
     Find_Addressed_Conventional_Placement
       (R,
        Event.Stream_ID,
        Header.Kitty_ID,
        Header.Kitty_Placement_ID);
   Object : constant Image_Object_Access :=
     (if Header.Kitty_ID = 0
      then Find_Image_Object_By_Storage_Order
        (R, Event.Stream_ID, R.Last_Stored_Image_Order)
      else Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID));
   Geometry : constant Placement_Geometry :=
     Resolve_Placement_Geometry (R, Object, Header);
begin
   if Header.Kitty_Virtual_Placement
     or else not Geometry.Valid
     or else Object = null
   then
      return Placement_Rejected;
   end if;

   --  Anonymous transmissions cannot subsequently be addressed, so a
   --  supplied placement identifier has no protocol meaning.
   if Header.Kitty_ID = 0 and then Header.Kitty_Parent_ID /= 0 then
      return Placement_Rejected;
   end if;

   declare
      Relative_Status : constant Relative_Placement_Status :=
        Validate_Relative_Placement
          (R,
           Event.Stream_ID,
           Event.Alternate_Screen,
           Event.Screen_Generation,
           Header.Kitty_ID,
           Header.Kitty_Placement_ID,
           Header.Kitty_Parent_ID,
           Header.Kitty_Parent_Placement_ID);
   begin
      if Relative_Status /= Relative_Valid then
         return To_Placement_Status (Relative_Status);
      end if;
   end;

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
         Placement := new Conventional_Placement;
      end if;
      Placement.Next := R.Conventional_Placements;
      R.Conventional_Placements := Placement;
      R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
   elsif Prepared /= null then
      Free_Conventional_Placement (Prepared);
   end if;

   declare
      Next : constant Conventional_Placement_Access := Placement.Next;
   begin
      Placement.all :=
        (Stream_ID      => Event.Stream_ID,
         Alternate_Screen => Event.Alternate_Screen,
         Screen_Generation => Event.Screen_Generation,
         Image_ID       => Header.Kitty_ID,
         Image_Storage_Order => Object.Storage_Order,
         Protocol       => RM.Image_Kitty,
         Placement_ID   =>
           (if Header.Kitty_ID = 0
            then 0
            else Header.Kitty_Placement_ID),
         Row            => Event.Row,
         Col            => Event.Col,
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
         Parent_Image_ID => Header.Kitty_Parent_ID,
         Parent_Placement_ID => Header.Kitty_Parent_Placement_ID,
         Parent_Offset_X => Header.Kitty_Parent_Offset_X,
         Parent_Offset_Y => Header.Kitty_Parent_Offset_Y,
         Scroll_Sequence => Event.Scroll_Sequence,
         Clip_Top        => 0,
         Clip_Bottom     => 0,
         History_Attached => False,
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
end Store_Conventional_Placement;
