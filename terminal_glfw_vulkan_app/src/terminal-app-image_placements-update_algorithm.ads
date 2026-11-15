generic
   type Container_Type is limited private;
   type Placement_Access is private;
   type Placement_State is private;
   with function Is_Null_Placement
     (Placement : Placement_Access) return Boolean;
   with function Linked
     (Placement : Placement_Access) return Boolean;
   with function State_Of
     (Placement : Placement_Access) return Placement_State;
   with procedure Assign_State
     (Placement : Placement_Access; Value : Placement_State);
   with function Same_Identity_State
     (Left, Right : Placement_State) return Boolean;
   with procedure Rebuild
     (Container : in out Container_Type;
      Placement : Placement_Access;
      Candidate : Placement_State);
procedure Terminal.App.Image_Placements.Update_Algorithm
  (Container : in out Container_Type;
   Placement : Placement_Access;
   Process   : not null access procedure (Item : in out Placement_State));
