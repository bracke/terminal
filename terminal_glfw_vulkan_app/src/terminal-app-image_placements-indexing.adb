package body Terminal.App.Image_Placements.Indexing is
   use type Key_Maps.Key_Type;
   use type Address_Maps.Key_Type;

   procedure Add
     (By_Key       : in out Key_Maps.Map;
      By_Address   : in out Address_Maps.Map;
      Image_Counts : in out Image_Count_Maps.Map;
      Placement    : Placement_Access;
      Value        : Placement_State)
   is
      Full : constant Key_Maps.Key_Type := Key_Of_State (Value);
      Address : constant Address_Maps.Key_Type := Address_Of_State (Value);
   begin
      if Has_Key_State (Value) and then not By_Key.Contains (Full) then
         By_Key.Insert (Full, Placement);
      end if;
      if Addressable_State (Value) and then not By_Address.Contains (Address) then
         By_Address.Insert (Address, Placement);
      end if;
      Increment (Image_Counts, Image_Of_State (Value));
   end Add;

   procedure Index
     (By_Key       : in out Key_Maps.Map;
      By_Address   : in out Address_Maps.Map;
      Image_Counts : in out Image_Count_Maps.Map;
      Placement    : Placement_Access)
   is
      Value : constant Placement_State := State_Of (Placement);
      Full : constant Key_Maps.Key_Type := Key_Of_State (Value);
      Address : constant Address_Maps.Key_Type := Address_Of_State (Value);
      Had_Full : constant Boolean :=
        Has_Key_State (Value) and then By_Key.Contains (Full);
      Old_Full : Placement_Access;
      Had_Address : constant Boolean :=
        Addressable_State (Value) and then By_Address.Contains (Address);
      Old_Address : Placement_Access;
   begin
      if Had_Full then
         Old_Full := By_Key.Element (Full);
      end if;
      if Had_Address then
         Old_Address := By_Address.Element (Address);
      end if;
      if Has_Key_State (Value) then
         By_Key.Include (Full, Placement);
      end if;
      if Addressable_State (Value) then
         By_Address.Include (Address, Placement);
      end if;
      Increment (Image_Counts, Image_Of_State (Value));
   exception
      when others =>
         if Has_Key_State (Value) then
            if Had_Full then
               By_Key.Include (Full, Old_Full);
            else
               By_Key.Exclude (Full);
            end if;
         end if;
         if Addressable_State (Value) then
            if Had_Address then
               By_Address.Include (Address, Old_Address);
            else
               By_Address.Exclude (Address);
            end if;
         end if;
         raise;
   end Index;

   procedure Validate_Unindex
     (By_Key       : Key_Maps.Map;
      By_Address   : Address_Maps.Map;
      Image_Counts : Image_Count_Maps.Map;
      Placement    : Placement_Access)
   is
      Value : constant Placement_State := State_Of (Placement);
      Full : constant Key_Maps.Key_Type := Key_Of_State (Value);
      Address : constant Address_Maps.Key_Type := Address_Of_State (Value);
      Image : constant Image_Key := Image_Of_State (Value);
   begin
      if Has_Key_State (Value) then
         if not By_Key.Contains (Full)
           or else Is_Null_Placement (By_Key.Element (Full))
           or else Key_Of_State (State_Of (By_Key.Element (Full))) /= Full
         then
            raise Program_Error with "placement key index is inconsistent";
         end if;
      end if;
      if Addressable_State (Value) then
         if not By_Address.Contains (Address)
           or else Is_Null_Placement (By_Address.Element (Address))
           or else
             not Addressable_State (State_Of (By_Address.Element (Address)))
           or else
             Address_Of_State (State_Of (By_Address.Element (Address))) /=
               Address
         then
            raise Program_Error with
              "placement address index is inconsistent";
         end if;
      end if;
      if not Image_Counts.Contains (Image)
        or else Image_Counts.Element (Image) = 0
      then
         raise Program_Error with "placement image index is inconsistent";
      end if;
   end Validate_Unindex;

   procedure Unindex
     (By_Key       : in out Key_Maps.Map;
      By_Address   : in out Address_Maps.Map;
      Image_Counts : in out Image_Count_Maps.Map;
      Placement    : Placement_Access)
   is
      Value : constant Placement_State := State_Of (Placement);
      Full : constant Key_Maps.Key_Type := Key_Of_State (Value);
      Address : constant Address_Maps.Key_Type := Address_Of_State (Value);
      Replacement : Placement_Access := Next_Of (Placement);
   begin
      Validate_Unindex (By_Key, By_Address, Image_Counts, Placement);
      if Has_Key_State (Value)
        and then By_Key.Contains (Full)
        and then By_Key.Element (Full) = Placement
      then
         while not Is_Null_Placement (Replacement)
           and then Key_Of_State (State_Of (Replacement)) /= Full
         loop
            Replacement := Next_Of (Replacement);
         end loop;
         if Is_Null_Placement (Replacement) then
            By_Key.Delete (Full);
         else
            By_Key.Replace (Full, Replacement);
         end if;
      end if;
      Replacement := Next_Of (Placement);
      if Addressable_State (Value)
        and then By_Address.Contains (Address)
        and then By_Address.Element (Address) = Placement
      then
         while not Is_Null_Placement (Replacement)
           and then
             (not Addressable_State (State_Of (Replacement))
              or else Address_Of_State (State_Of (Replacement)) /= Address)
         loop
            Replacement := Next_Of (Replacement);
         end loop;
         if Is_Null_Placement (Replacement) then
            By_Address.Delete (Address);
         else
            By_Address.Replace (Address, Replacement);
         end if;
      end if;
      Decrement (Image_Counts, Image_Of_State (Value));
   end Unindex;
end Terminal.App.Image_Placements.Indexing;
