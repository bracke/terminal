separate (Terminal.App.Renderer.Placement_Operations)
function Resolve_Conventional_Placement_Origin
  (R         : Renderer;
   Snapshot  : Terminal.Core.Render_Snapshot;
   Placement : Conventional_Placement_State;
   Row       : out Integer;
   Col       : out Integer;
   Use_Index : Boolean := False) return Boolean
is
   Current : Placements_State.Conventional_Placement_Value :=
     (Exists => True, Value => Placement);
   Current_Value : Conventional_Placement_State renames Current.Value;
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
   if not Current.Exists then
      return False;
   end if;

   for Depth in 0 .. Max_Relative_Placement_Depth loop
      if Current_Value.Parent_Image_ID = 0 then
         if Current_Value.Row >
             Integer'Last - Integer (Snapshot.Scrollback_Offset)
         then
            return False;
         end if;
         Base_Row := Current_Value.Row + Integer (Snapshot.Scrollback_Offset);
         Base_Col := Current_Value.Col;
         Base_Found := True;
         exit;
      end if;

      Row_Offset :=
        Row_Offset + Long_Long_Integer (Current_Value.Parent_Offset_Y);
      Col_Offset :=
        Col_Offset + Long_Long_Integer (Current_Value.Parent_Offset_X);

      declare
         Parent : constant Placements_State.Conventional_Placement_Value :=
           (if Use_Index
            then Placements_State.Value_Of
              (Terminal.App.Placeholder_Index.Find_Conventional
                 (R.Frame_State.Placement_Index,
                  Current_Value.Stream_ID,
                  Current_Value.Alternate_Screen,
                  Current_Value.Screen_Generation,
                  Current_Value.Parent_Image_ID,
                  Current_Value.Parent_Placement_ID))
            else Placements_State.Find_Conventional_Placement
              (R,
               Current_Value.Stream_ID,
               Current_Value.Alternate_Screen,
               Current_Value.Screen_Generation,
               Current_Value.Parent_Image_ID,
               Current_Value.Parent_Placement_ID));
      begin
         if Parent.Exists then
            Current := Parent;
         elsif Resolve_Virtual_Placement_Origin
             (R,
              Snapshot,
              Current_Value.Parent_Image_ID,
              Current_Value.Parent_Placement_ID,
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
