separate (Terminal.App.Renderer)
procedure Delete_Conventional_Placements_By_Z
  (R       : in out Renderer;
   Stream_ID : Terminal.Core.Graphics_Stream_ID;
   Z_Index : Integer;
   Alternate_Screen : Boolean;
   Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
   Delete_Data : Boolean)
is
   Previous : Conventional_Placement_Access := null;
   Current  : Conventional_Placement_Access := R.Conventional_Placements;
   Deleted_Orders : Image_Storage_Order_List := (others => 0);
   Deleted_Count : Natural := 0;
begin
   while Current /= null loop
      declare
         Next : constant Conventional_Placement_Access := Current.Next;
      begin
         if Current.Stream_ID = Stream_ID
           and then Current.Protocol = RM.Image_Kitty
           and then Current.Alternate_Screen = Alternate_Screen
           and then Current.Screen_Generation = Screen_Generation
           and then Current.Z_Index = Z_Index
         then
            if Delete_Data then
               Remember_Deleted_Image
                 (Deleted_Orders,
                  Deleted_Count,
                  Current.Image_Storage_Order);
            end if;
            if Previous = null then
               R.Conventional_Placements := Next;
            else
               Previous.Next := Next;
            end if;
            Free_Conventional_Placement (Current);
            R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
         else
            Previous := Current;
         end if;
         Current := Next;
      end;
   end loop;
   if Delete_Data then
      Delete_Selected_Unplaced_Image_Objects
        (R, Stream_ID, Deleted_Orders, Deleted_Count);
   end if;
end Delete_Conventional_Placements_By_Z;
