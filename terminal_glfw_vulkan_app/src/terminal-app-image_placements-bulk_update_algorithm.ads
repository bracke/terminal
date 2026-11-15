with Ada.Containers;
with Ada.Containers.Vectors;

generic
   type Container_Type is limited private;
   type Placement_Access is private;
   type Placement_State is private;
   with package State_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Placement_State, others => <>);
   with function Is_Null_Placement
     (Placement : Placement_Access) return Boolean;
   with function State_Of
     (Placement : Placement_Access) return Placement_State;
   with procedure Assign_State
     (Placement : Placement_Access; Value : Placement_State);
   with function Next_Of
     (Placement : Placement_Access) return Placement_Access;
   with function Same_Identity_State
     (Left, Right : Placement_State) return Boolean;
   with procedure Rebuild
     (Container : in out Container_Type;
      Candidates : State_Vectors.Vector);
procedure Terminal.App.Image_Placements.Bulk_Update_Algorithm
  (Container : in out Container_Type;
   Head      : Placement_Access;
   Capacity  : Ada.Containers.Count_Type;
   Process   : not null access procedure (Item : in out Placement_State));
