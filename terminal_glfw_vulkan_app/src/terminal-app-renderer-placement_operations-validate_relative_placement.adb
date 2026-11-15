separate (Terminal.App.Renderer.Placement_Operations)
function Validate_Relative_Placement
  (R                   : Renderer;
   Stream_ID           : Terminal.Core.Graphics_Stream_ID;
   Alternate_Screen    : Boolean;
   Screen_Generation   : Terminal.Core.Graphics_Screen_Generation;
   Child_Image_ID      : Terminal.Core.Graphics_ID;
   Child_Placement_ID  : Terminal.Core.Graphics_ID;
   Parent_Image_ID     : Terminal.Core.Graphics_ID;
   Parent_Placement_ID : Terminal.Core.Graphics_ID)
   return Relative_Placement_Status
is
   Current_Image_ID : Terminal.Core.Graphics_ID := Parent_Image_ID;
   Current_Placement_ID : Terminal.Core.Graphics_ID :=
     Parent_Placement_ID;
begin
   if Parent_Image_ID = 0 then
      return Relative_Valid;
   end if;

   for Depth in 1 .. Max_Relative_Placement_Depth loop
      if Current_Image_ID = Child_Image_ID
        and then Current_Placement_ID = Child_Placement_ID
      then
         return Relative_Cycle;
      end if;

      declare
         Parent : constant Placements_State.Conventional_Placement_Value :=
           Placements_State.Find_Conventional_Placement
             (R,
              Stream_ID,
              Alternate_Screen,
              Screen_Generation,
              Current_Image_ID,
              Current_Placement_ID);
      begin
         if Parent.Exists then
            if Parent.Value.Parent_Image_ID = 0 then
               return Relative_Valid;
            end if;
            Current_Image_ID := Parent.Value.Parent_Image_ID;
            Current_Placement_ID := Parent.Value.Parent_Placement_ID;
         else
            return
              (if not Placements_State.Find_Virtual_Placement
                 (R,
                  Stream_ID,
                  Alternate_Screen,
                  Screen_Generation,
                  Current_Image_ID,
                  Current_Placement_ID).Exists
               then Relative_Parent_Missing
               else Relative_Valid);
         end if;
      end;
   end loop;

   --  A conforming implementation must permit at least eight ancestors.
   --  This implementation deliberately accepts up to thirty-two.
   return Relative_Too_Deep;
end Validate_Relative_Placement;
