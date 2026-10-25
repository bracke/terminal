separate (Terminal.App.Renderer)
function Resolve_Conventional_Placement_Origin
  (R         : Renderer;
   Snapshot  : Terminal.Core.Render_Snapshot;
   Placement : Conventional_Placement_Access;
   Row       : out Integer;
   Col       : out Integer;
   Use_Index : Boolean := False) return Boolean
is
   Current : Conventional_Placement_Access := Placement;
   Row_Offset : Long_Long_Integer := 0;
   Col_Offset : Long_Long_Integer := 0;
   Base_Row : Integer := 0;
   Base_Col : Integer := 0;
   Base_Found : Boolean := False;
   Resolved_Row : Long_Long_Integer;
   Resolved_Col : Long_Long_Integer;
begin
   Row := 0;
   Col := 0;
   if Current = null then
      return False;
   end if;

   for Depth in 0 .. Max_Relative_Placement_Depth loop
      if Current.Parent_Image_ID = 0 then
         if Snapshot.Scrollback_Offset > Integer'Last
           or else Current.Row >
             Integer'Last - Integer (Snapshot.Scrollback_Offset)
         then
            return False;
         end if;
         Base_Row := Current.Row + Integer (Snapshot.Scrollback_Offset);
         Base_Col := Current.Col;
         Base_Found := True;
         exit;
      end if;

      Row_Offset :=
        Row_Offset + Long_Long_Integer (Current.Parent_Offset_Y);
      Col_Offset :=
        Col_Offset + Long_Long_Integer (Current.Parent_Offset_X);

      declare
         Parent : constant Conventional_Placement_Access :=
           (if Use_Index
            then Terminal.App.Placeholder_Index.Find_Conventional
              (R.Placement_Index,
               Current.Stream_ID,
               Current.Alternate_Screen,
               Current.Screen_Generation,
               Current.Parent_Image_ID,
               Current.Parent_Placement_ID)
            else Find_Conventional_Placement
              (R,
               Current.Stream_ID,
               Current.Alternate_Screen,
               Current.Screen_Generation,
               Current.Parent_Image_ID,
               Current.Parent_Placement_ID));
      begin
         if Parent /= null then
            Current := Parent;
         elsif Resolve_Virtual_Placement_Origin
             (R,
              Snapshot,
              Current.Parent_Image_ID,
              Current.Parent_Placement_ID,
              Base_Row,
              Base_Col,
              Use_Index)
         then
            Base_Found := True;
            exit;
         else
            return False;
         end if;
      end;
   end loop;

   if not Base_Found or else Base_Col = 0 then
      return False;
   end if;

   Resolved_Row := Long_Long_Integer (Base_Row) + Row_Offset;
   Resolved_Col := Long_Long_Integer (Base_Col) + Col_Offset;
   if Resolved_Row < Long_Long_Integer (Integer'First)
     or else Resolved_Row > Long_Long_Integer (Integer'Last)
     or else Resolved_Col < Long_Long_Integer (Integer'First)
     or else Resolved_Col > Long_Long_Integer (Integer'Last)
   then
      return False;
   end if;

   Row := Integer (Resolved_Row);
   Col := Integer (Resolved_Col);
   return True;
end Resolve_Conventional_Placement_Origin;
