separate (Terminal.App.Renderer.Placement_Operations)
function Store_Auxiliary_Placement
  (R           : in out Renderer;
   Event       : Terminal.Core.Graphics_Event;
   Protocol    : RM.Image_Protocol;
   Draw_Width  : Positive;
   Draw_Height : Positive) return Boolean
is
   Object : constant Image_Object_Access :=
     Image_Objects.Find_By_Storage_Order
       (R, Event.Stream_ID, R.Graphics_State.Transaction.Last_Stored_Image_Order);
   Placement : Conventional_Placement_Access := null;
   Columns : Positive;
   Rows : Positive;
   procedure Configure (Item : in out Conventional_Placement_State) is
   begin
      Item.Stream_ID := Event.Stream_ID;
      Item.Alternate_Screen := Event.Alternate_Screen;
      Item.Screen_Generation := Event.Screen_Generation;
      Item.Image_Storage_Order := Object.Storage_Order;
      Item.Protocol := Protocol;
      Item.Row := Event.Row;
      Item.Col := Event.Col;
      Item.Columns := Columns;
      Item.Rows := Rows;
      Item.Draw_Width := Draw_Width;
      Item.Draw_Height := Draw_Height;
      Item.Scroll_Sequence := Event.Scroll_Sequence;
   end Configure;
begin
   if Object = null
     or else Placements_State.Stored_Placement_Count (R) >= R.Graphics_State.Policy.Limits.Placements
   then
      return False;
   end if;
   Columns := Positive'Max (1, 1 + (Draw_Width - 1) / R.Text_State.CW);
   Rows := Positive'Max (1, 1 + (Draw_Height - 1) / R.Text_State.CH);
   if not Terminal.App.Image_Store.Allocation_Allowed
     (R.Graphics_State.Resources.Allocation_Control)
   then
      return False;
   end if;
   Placement := new Conventional_Placement;
   Terminal.App.Image_Placements.Configure_Unlinked
     (Placement, Configure'Access);
   Placements_State.Prepend_Conventional_Placement (R, Placement);
   return True;
exception
   when Storage_Error =>
      if Placement /= null then
         Placements_State.Release_Unowned (Placement);
      end if;
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      return False;
end Store_Auxiliary_Placement;
