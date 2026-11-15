separate (Terminal.App.Renderer)
procedure Delete_Conventional_Placements_By_Z
  (R       : in out Renderer;
   Stream_ID : Terminal.Core.Graphics_Stream_ID;
   Z_Index : Integer;
   Alternate_Screen : Boolean;
   Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
   Delete_Data : Boolean)
is
   Deleted_Orders : Image_Storage_Order_List := (others => 0);
   Deleted_Count : Natural := 0;
   function Matches (Current : Conventional_Placement_State) return Boolean is
     (Current.Stream_ID = Stream_ID
      and then Current.Protocol = RM.Image_Kitty
      and then Current.Alternate_Screen = Alternate_Screen
      and then Current.Screen_Generation = Screen_Generation
      and then Current.Z_Index = Z_Index);
   procedure Remember (Current : Conventional_Placement_State) is
   begin
      if Delete_Data then
         Remember_Deleted_Image
           (Deleted_Orders, Deleted_Count, Current.Image_Storage_Order);
      end if;
   end Remember;
begin
   Placements_State.Delete_Conventional_If
     (R, Matches'Access, Remember'Access);
   if Delete_Data then
      Delete_Selected_Unplaced_Image_Objects
        (R, Stream_ID, Deleted_Orders, Deleted_Count);
   end if;
end Delete_Conventional_Placements_By_Z;
