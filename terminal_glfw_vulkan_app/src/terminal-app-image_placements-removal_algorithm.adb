procedure Terminal.App.Image_Placements.Removal_Algorithm
  (Container : in out Container_Type;
   Head      : in out Placement_Access;
   Previous  : Placement_Access;
   Current   : in out Placement_Access;
   Following : out Placement_Access) is
begin
   if Is_Null_Placement (Current) then
      raise Constraint_Error with "cannot remove a null placement";
   elsif Is_Null_Placement (Previous) and then Head /= Current then
      raise Program_Error with "placement is not the list head";
   elsif not Is_Null_Placement (Previous)
     and then Next_Of (Previous) /= Current
   then
      raise Program_Error with "placement predecessor mismatch";
   end if;
   Validate_Count (Container);
   Unindex_Placement (Container, Current);
   Following := Next_Of (Current);
   if Is_Null_Placement (Previous) then
      Head := Following;
   else
      Assign_Next (Previous, Following);
   end if;
   Assign_Linked (Current, False);
   Assign_Next (Current, Null_Placement);
   Free_Placement (Current);
   Decrement_Count (Container);
end Terminal.App.Image_Placements.Removal_Algorithm;
