separate (Terminal.App.Renderer)
procedure Delete_Conventional_Placements_Intersecting
  (R          : in out Renderer;
   Stream_ID  : Terminal.Core.Graphics_Stream_ID;
   Row        : Positive;
   Col        : Positive;
   Match_Row  : Boolean := True;
   Match_Col  : Boolean := True;
   Match_Z    : Boolean := False;
   Z_Index    : Integer := 0;
   Match_Screen : Boolean := False;
   Alternate_Screen : Boolean := False;
   Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
   Snapshot     : Terminal.Core.Render_Snapshot;
   Delete_Data  : Boolean)
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
         Row_Intersects : constant Boolean :=
           Resolved
           and then Long_Long_Integer (Row) >= Long_Long_Integer (Origin_Row)
           and then Long_Long_Integer (Row) <
             Long_Long_Integer (Origin_Row)
               + Long_Long_Integer (Current.Rows);
         Col_Intersects : constant Boolean :=
           Resolved
           and then Long_Long_Integer (Col) >= Long_Long_Integer (Origin_Col)
           and then Long_Long_Integer (Col) <
             Long_Long_Integer (Origin_Col)
               + Long_Long_Integer (Current.Columns);
         Match : constant Boolean :=
           Current.Stream_ID = Stream_ID
           and then Current.Protocol = RM.Image_Kitty
           and then
             (not Match_Screen
              or else
                (Current.Alternate_Screen = Alternate_Screen
                 and then Current.Screen_Generation = Screen_Generation))
           and then (not Match_Row or else Row_Intersects)
           and then (not Match_Col or else Col_Intersects)
           and then (not Match_Z or else Current.Z_Index = Z_Index);
      begin
         if Match then
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
end Delete_Conventional_Placements_Intersecting;
