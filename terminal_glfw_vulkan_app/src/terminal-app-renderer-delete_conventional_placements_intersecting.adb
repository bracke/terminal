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
   Deleted_Orders : Image_Storage_Order_List := (others => 0);
   Deleted_Count : Natural := 0;

   function Matches (Current : Conventional_Placement_State) return Boolean is
      Origin_Row : Integer := 0;
      Origin_Col : Integer := 0;
      Resolved : constant Boolean :=
        Resolve_Conventional_Placement_Origin
          (R, Snapshot, Current, Origin_Row, Origin_Col);
      Row_Intersects : constant Boolean :=
        Resolved
        and then Long_Long_Integer (Row) >= Long_Long_Integer (Origin_Row)
        and then Long_Long_Integer (Row) <
          Long_Long_Integer (Origin_Row) + Long_Long_Integer (Current.Rows);
      Col_Intersects : constant Boolean :=
        Resolved
        and then Long_Long_Integer (Col) >= Long_Long_Integer (Origin_Col)
        and then Long_Long_Integer (Col) <
          Long_Long_Integer (Origin_Col) + Long_Long_Integer (Current.Columns);
   begin
      return Current.Stream_ID = Stream_ID
        and then Current.Protocol = RM.Image_Kitty
        and then
          (not Match_Screen
           or else
             (Current.Alternate_Screen = Alternate_Screen
              and then Current.Screen_Generation = Screen_Generation))
        and then (not Match_Row or else Row_Intersects)
        and then (not Match_Col or else Col_Intersects)
        and then (not Match_Z or else Current.Z_Index = Z_Index);
   end Matches;
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
end Delete_Conventional_Placements_Intersecting;
