generic
   type Container_Type is limited private;
   type Placement_Access is private;
   Null_Placement : Placement_Access;
   with function Is_Null_Placement
     (Placement : Placement_Access) return Boolean;
   with function Next_Of
     (Placement : Placement_Access) return Placement_Access;
   with procedure Assign_Next
     (Placement : Placement_Access; Value : Placement_Access);
   with procedure Assign_Linked
     (Placement : Placement_Access; Value : Boolean);
   with procedure Unindex_Placement
     (Container : in out Container_Type; Placement : Placement_Access);
   with procedure Validate_Count (Container : Container_Type);
   with procedure Decrement_Count (Container : in out Container_Type);
   with procedure Free_Placement (Placement : in out Placement_Access);
procedure Terminal.App.Image_Placements.Removal_Algorithm
  (Container : in out Container_Type;
   Head      : in out Placement_Access;
   Previous  : Placement_Access;
   Current   : in out Placement_Access;
   Following : out Placement_Access);
