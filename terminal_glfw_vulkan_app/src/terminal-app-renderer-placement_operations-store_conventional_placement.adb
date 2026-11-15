separate (Terminal.App.Renderer.Placement_Operations)
function Store_Conventional_Placement
  (R      : in out Renderer;
   Event  : Terminal.Core.Graphics_Event;
   Header : Terminal.App.Graphics.Graphics_Header;
   Prepared : in out Conventional_Placement_Access)
   return Placement_Store_Status
is
   Existing : constant Boolean :=
     Placements_State.Find_Addressed_Conventional_Placement
       (R, Event.Stream_ID, Header.Kitty_ID,
        Header.Kitty_Placement_ID).Exists;
   Object : constant Image_Object_Access :=
     (if Header.Kitty_ID = 0
      then Image_Objects.Find_By_Storage_Order
        (R, Event.Stream_ID, R.Graphics_State.Transaction.Last_Stored_Image_Order)
      else Image_Objects.Find (R, Event.Stream_ID, Header.Kitty_ID));
   Geometry : constant Placement_Geometry :=
     Placements_State.Resolve_Placement_Geometry (R, Object, Header);
   procedure Configure (Placement : in out Conventional_Placement_State) is
   begin
      Placement.Stream_ID := Event.Stream_ID;
      Placement.Alternate_Screen := Event.Alternate_Screen;
      Placement.Screen_Generation := Event.Screen_Generation;
      Placement.Image_ID := Header.Kitty_ID;
      Placement.Image_Storage_Order := Object.Storage_Order;
      Placement.Protocol := RM.Image_Kitty;
      Placement.Placement_ID :=
        (if Header.Kitty_ID = 0 then 0 else Header.Kitty_Placement_ID);
      Placement.Row := Event.Row;
      Placement.Col := Event.Col;
      Placement.Columns := Geometry.Columns;
      Placement.Rows := Geometry.Rows;
      Placement.Source_X := Header.Kitty_Source_X;
      Placement.Source_Y := Header.Kitty_Source_Y;
      Placement.Source_Width := Header.Kitty_Source_Width;
      Placement.Source_Height := Header.Kitty_Source_Height;
      Placement.Cell_X := Header.Kitty_Cell_X;
      Placement.Cell_Y := Header.Kitty_Cell_Y;
      Placement.Draw_Offset_X := Geometry.Draw_Offset_X;
      Placement.Draw_Offset_Y := Geometry.Draw_Offset_Y;
      Placement.Draw_Width := Geometry.Draw_Width;
      Placement.Draw_Height := Geometry.Draw_Height;
      Placement.Z_Index := Header.Kitty_Z_Index;
      Placement.Parent_Image_ID := Header.Kitty_Parent_ID;
      Placement.Parent_Placement_ID := Header.Kitty_Parent_Placement_ID;
      Placement.Parent_Offset_X := Header.Kitty_Parent_Offset_X;
      Placement.Parent_Offset_Y := Header.Kitty_Parent_Offset_Y;
      Placement.Scroll_Sequence := Event.Scroll_Sequence;
      Placement.Clip_Top := 0;
      Placement.Clip_Bottom := 0;
      Placement.History_Attached := False;
   end Configure;
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

   if not Existing then
      if Placements_State.Stored_Placement_Count (R) >= R.Graphics_State.Policy.Limits.Placements then
         R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
         return Placement_No_Space;
      end if;
      if Prepared /= null then
         Terminal.App.Image_Placements.Configure_Unlinked
           (Prepared, Configure'Access);
         Placements_State.Prepend_Conventional_Placement (R, Prepared);
         Prepared := null;
      else
         if not Terminal.App.Image_Store.Allocation_Allowed
           (R.Graphics_State.Resources.Allocation_Control)
         then
            R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
            return Placement_No_Space;
         end if;
         declare
            Placement : Conventional_Placement_Access :=
              new Conventional_Placement;
         begin
            Terminal.App.Image_Placements.Configure_Unlinked
              (Placement, Configure'Access);
            Placements_State.Prepend_Conventional_Placement (R, Placement);
         exception
            when others =>
               if Placement /= null then
                  Placements_State.Release_Unowned (Placement);
               end if;
               raise;
         end;
      end if;
   elsif Prepared /= null then
      Placements_State.Release_Unowned (Prepared);
      Placements_State.Update_Addressed_Conventional_Placement
        (R, Event.Stream_ID, Header.Kitty_ID, Header.Kitty_Placement_ID,
         Configure'Access);
   else
      Placements_State.Update_Addressed_Conventional_Placement
        (R, Event.Stream_ID, Header.Kitty_ID, Header.Kitty_Placement_ID,
         Configure'Access);
   end if;
   Placements_State.Move_Relative_Descendants
     (R,
      Event.Stream_ID,
      Header.Kitty_ID,
      Header.Kitty_Placement_ID,
      Event.Alternate_Screen,
      Event.Screen_Generation);
   return Placement_Stored;
exception
   when Storage_Error =>
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      return Placement_No_Space;
end Store_Conventional_Placement;
