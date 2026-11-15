procedure Terminal.App.Image_Placements.Update_Algorithm
  (Container : in out Container_Type;
   Placement : Placement_Access;
   Process   : not null access procedure (Item : in out Placement_State))
is
   Original : Placement_State;
   Candidate : Placement_State;
begin
   if Is_Null_Placement (Placement) or else not Linked (Placement) then
      raise Constraint_Error with "placement is not linked";
   end if;
   Original := State_Of (Placement);
   Candidate := Original;
   Process (Candidate);
   if not Same_Identity_State (Original, Candidate) then
      Rebuild (Container, Placement, Candidate);
   end if;
   Assign_State (Placement, Candidate);
end Terminal.App.Image_Placements.Update_Algorithm;
