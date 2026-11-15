separate (Terminal.App.Renderer)
procedure Delete_Visible_Conventional_Placements
  (R           : in out Renderer;
   Snapshot    : Terminal.Core.Render_Snapshot;
   Delete_Data : Boolean)
is
   Position : Placements_State.Conventional_Cursor :=
     Placements_State.First_Conventional (R);
   Deleted_Orders : Image_Storage_Order_List := (others => 0);
   Deleted_Count : Natural := 0;
begin
   while Placements_State.Has_Element (Position) loop
      declare
         Current : constant Conventional_Placement_State :=
           Placements_State.Element (Position);
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
            Placements_State.Delete (R, Position);
         else
            Placements_State.Advance (Position);
         end if;
      end;
   end loop;
   if Delete_Data then
      Delete_Selected_Unplaced_Image_Objects
        (R, Snapshot.Graphics_Stream, Deleted_Orders, Deleted_Count);
   end if;
end Delete_Visible_Conventional_Placements;
