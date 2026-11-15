with Ada.Containers.Hashed_Maps;

generic
   type Placement_Access is private;
   type Placement_State is private;
   with package Key_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type => <>, Element_Type => Placement_Access, others => <>);
   with package Address_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type => <>, Element_Type => Placement_Access, others => <>);
   type Image_Key is private;
   with package Image_Count_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type => Image_Key, Element_Type => Natural, others => <>);
   with function State_Of
     (Placement : Placement_Access) return Placement_State;
   with function Next_Of
     (Placement : Placement_Access) return Placement_Access;
   with function Key_Of_State
     (Value : Placement_State) return Key_Maps.Key_Type;
   with function Address_Of_State
     (Value : Placement_State) return Address_Maps.Key_Type;
   with function Image_Of_State
     (Value : Placement_State) return Image_Key;
   with function Has_Key_State
     (Value : Placement_State) return Boolean;
   with function Addressable_State
     (Value : Placement_State) return Boolean;
   with function Is_Null_Placement
     (Placement : Placement_Access) return Boolean;
   with procedure Increment
     (Counts : in out Image_Count_Maps.Map; Key : Image_Key);
   with procedure Decrement
     (Counts : in out Image_Count_Maps.Map; Key : Image_Key);
package Terminal.App.Image_Placements.Indexing is
   procedure Add
     (By_Key       : in out Key_Maps.Map;
      By_Address   : in out Address_Maps.Map;
      Image_Counts : in out Image_Count_Maps.Map;
      Placement    : Placement_Access;
      Value        : Placement_State);
   procedure Index
     (By_Key       : in out Key_Maps.Map;
      By_Address   : in out Address_Maps.Map;
      Image_Counts : in out Image_Count_Maps.Map;
      Placement    : Placement_Access);
   procedure Validate_Unindex
     (By_Key       : Key_Maps.Map;
      By_Address   : Address_Maps.Map;
      Image_Counts : Image_Count_Maps.Map;
      Placement    : Placement_Access);
   procedure Unindex
     (By_Key       : in out Key_Maps.Map;
      By_Address   : in out Address_Maps.Map;
      Image_Counts : in out Image_Count_Maps.Map;
      Placement    : Placement_Access);
end Terminal.App.Image_Placements.Indexing;
