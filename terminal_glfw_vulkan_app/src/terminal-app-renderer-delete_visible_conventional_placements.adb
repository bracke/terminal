separate (Terminal.App.Renderer)
procedure Delete_Visible_Conventional_Placements
  (R           : in out Renderer;
   Snapshot    : Terminal.Core.Render_Snapshot;
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
         Origin_Row : Integer := 0;
         Origin_Col : Integer := 0;
         Resolved : constant Boolean :=
           Resolve_Conventional_Placement_Origin
             (R, Snapshot, Current, Origin_Row, Origin_Col);
         Visible : constant Boolean :=
           Resolved
           and then Current.Stream_ID = Snapshot.Graphics_Stream
           and then Current.Protocol = RM.Image_Kitty
           and then Current.Alternate_Screen = Snapshot.Alternate_Screen
           and then Current.Screen_Generation = Snapshot.Screen_Generation
           and then Origin_Row <= Snapshot.Rows
           and then Origin_Col <= Snapshot.Cols
           and then Long_Long_Integer (Origin_Row)
             + Long_Long_Integer (Current.Rows) - 1 >= 1
           and then Long_Long_Integer (Origin_Col)
             + Long_Long_Integer (Current.Columns) - 1 >= 1;
      begin
         if Visible then
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
        (R, Snapshot.Graphics_Stream, Deleted_Orders, Deleted_Count);
   end if;
end Delete_Visible_Conventional_Placements;
