with Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Image_Placements.Indexing;
with Terminal.App.Image_Placements.Removal_Algorithm;
with Terminal.App.Image_Placements.Update_Algorithm;
with Terminal.App.Image_Placements.Bulk_Update_Algorithm;

package body Terminal.App.Image_Placements is
   use type Virtual_Placement_Access;
   use type Conventional_Placement_Access;
   use type Ada.Containers.Hash_Type;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Stream_ID;

   function Mix
     (Left, Right : Ada.Containers.Hash_Type)
      return Ada.Containers.Hash_Type is
     (Left * 16#0100_0193# xor Right);

   function Hash (Key : Placement_Key) return Ada.Containers.Hash_Type is
      use type Ada.Containers.Hash_Type;
   begin
      return Mix
        (Mix
           (Mix
              (Mix
                 (Ada.Containers.Hash_Type'Mod (Key.Stream_ID),
                  (if Key.Alternate_Screen then 1 else 0)),
               Ada.Containers.Hash_Type'Mod (Key.Screen_Generation)),
            Ada.Containers.Hash_Type'Mod (Key.Image_ID)),
         Ada.Containers.Hash_Type'Mod (Key.Placement_ID));
   end Hash;

   function Hash (Key : Address_Key) return Ada.Containers.Hash_Type is
   begin
      return Mix
        (Mix
           (Ada.Containers.Hash_Type'Mod (Key.Stream_ID),
            Ada.Containers.Hash_Type'Mod (Key.Image_ID)),
         Ada.Containers.Hash_Type'Mod (Key.Placement_ID));
   end Hash;

   function Hash (Key : Image_Key) return Ada.Containers.Hash_Type is
   begin
      return Mix
        (Ada.Containers.Hash_Type'Mod (Key.Stream_ID),
         Ada.Containers.Hash_Type'Mod (Key.Image_ID));
   end Hash;

   procedure Free_Virtual is new Ada.Unchecked_Deallocation
     (Virtual_Placement, Virtual_Placement_Access);
   procedure Free_Conventional is new Ada.Unchecked_Deallocation
     (Conventional_Placement, Conventional_Placement_Access);

   package Virtual_State_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Virtual_Placement_State);
   package Conventional_State_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Conventional_Placement_State);

   function State
     (Placement : not null Virtual_Placement_Access)
      return Virtual_Placement_State is (Placement.State);

   function State
     (Placement : not null Conventional_Placement_Access)
      return Conventional_Placement_State is (Placement.State);

   procedure Configure_Unlinked
     (Placement : not null Virtual_Placement_Access;
      Process   : not null access procedure
        (Item : in out Virtual_Placement_State)) is
   begin
      if Placement.Link.Linked then
         raise Program_Error with "cannot configure a linked virtual placement";
      end if;
      Process (Placement.State);
   end Configure_Unlinked;

   procedure Configure_Unlinked
     (Placement : not null Conventional_Placement_Access;
      Process   : not null access procedure
        (Item : in out Conventional_Placement_State)) is
   begin
      if Placement.Link.Linked then
         raise Program_Error with
           "cannot configure a linked conventional placement";
      end if;
      Process (Placement.State);
   end Configure_Unlinked;

   function Count (Container : Store) return Natural is
     (Container.Placement_Count);

   function First_Virtual
     (Container : Store) return Virtual_Placement_Access is
     (Container.Virtual_Head);

   function First_Conventional
     (Container : Store) return Conventional_Placement_Access is
     (Container.Conventional_Head);

   function Next
     (Placement : Virtual_Placement_Access) return Virtual_Placement_Access is
     (if Placement = null then null else Placement.Link.Next_Link);

   function Next
     (Placement : Conventional_Placement_Access)
      return Conventional_Placement_Access is
     (if Placement = null then null else Placement.Link.Next_Link);

   function Find_Virtual
     (Container         : Store;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Access
   is
      Key : constant Placement_Key :=
        (Stream_ID, Alternate_Screen, Screen_Generation,
         Image_ID, Placement_ID);
   begin
      if Placement_ID = 0 then
         return null;
      elsif Container.Virtual_By_Key.Contains (Key) then
         return Container.Virtual_By_Key.Element (Key);
      else
         return null;
      end if;
   end Find_Virtual;

   function Find_Addressed_Virtual
     (Container    : Store;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Access
   is
      Key : constant Address_Key := (Stream_ID, Image_ID, Placement_ID);
   begin
      if Placement_ID = 0 then
         return null;
      elsif Container.Virtual_By_Address.Contains (Key) then
         return Container.Virtual_By_Address.Element (Key);
      else
         return null;
      end if;
   end Find_Addressed_Virtual;

   function Has_Virtual
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID) return Boolean
   is (Container.Virtual_Image_Counts.Contains ((Stream_ID, Image_ID)));

   function Find_Conventional
     (Container         : Store;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Access
   is
      Key : constant Placement_Key :=
        (Stream_ID, Alternate_Screen, Screen_Generation,
         Image_ID, Placement_ID);
   begin
      if Placement_ID = 0 then
         return null;
      elsif Container.Conventional_By_Key.Contains (Key) then
         return Container.Conventional_By_Key.Element (Key);
      else
         return null;
      end if;
   end Find_Conventional;

   function Find_Addressed_Conventional
     (Container    : Store;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Access
   is
      Key : constant Address_Key := (Stream_ID, Image_ID, Placement_ID);
   begin
      if Placement_ID = 0 then
         return null;
      elsif Container.Conventional_By_Address.Contains (Key) then
         return Container.Conventional_By_Address.Element (Key);
      else
         return null;
      end if;
   end Find_Addressed_Conventional;

   function Has_Conventional
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID) return Boolean
   is (Container.Conventional_Image_Counts.Contains ((Stream_ID, Image_ID)));

   function Key_Of (Placement : Virtual_Placement_Access)
      return Placement_Key is
     (Placement.State.Stream_ID,
      Placement.State.Alternate_Screen,
      Placement.State.Screen_Generation,
      Placement.State.Image_ID,
      Placement.State.Placement_ID);

   function Key_Of (Value : Virtual_Placement_State)
      return Placement_Key is
     (Value.Stream_ID,
      Value.Alternate_Screen,
      Value.Screen_Generation,
      Value.Image_ID,
      Value.Placement_ID);

   function Key_Of (Placement : Conventional_Placement_Access)
      return Placement_Key is
     (Placement.State.Stream_ID,
      Placement.State.Alternate_Screen,
      Placement.State.Screen_Generation,
      Placement.State.Image_ID,
      Placement.State.Placement_ID);

   function Key_Of (Value : Conventional_Placement_State)
      return Placement_Key is
     (Value.Stream_ID,
      Value.Alternate_Screen,
      Value.Screen_Generation,
      Value.Image_ID,
      Value.Placement_ID);

   function Address_Of (Placement : Virtual_Placement_Access)
      return Address_Key is
     (Placement.State.Stream_ID, Placement.State.Image_ID, Placement.State.Placement_ID);

   function Address_Of (Value : Virtual_Placement_State)
      return Address_Key is
     (Value.Stream_ID, Value.Image_ID, Value.Placement_ID);

   function Address_Of (Placement : Conventional_Placement_Access)
      return Address_Key is
     (Placement.State.Stream_ID, Placement.State.Image_ID, Placement.State.Placement_ID);

   function Address_Of (Value : Conventional_Placement_State)
      return Address_Key is
     (Value.Stream_ID, Value.Image_ID, Value.Placement_ID);

   function Image_Of (Placement : Virtual_Placement_Access)
      return Image_Key is
     (Placement.State.Stream_ID, Placement.State.Image_ID);

   function Image_Of (Value : Virtual_Placement_State)
      return Image_Key is
     (Value.Stream_ID, Value.Image_ID);

   function Image_Of (Placement : Conventional_Placement_Access)
      return Image_Key is
     (Placement.State.Stream_ID, Placement.State.Image_ID);

   function Image_Of (Value : Conventional_Placement_State)
      return Image_Key is
     (Value.Stream_ID, Value.Image_ID);

   function Has_Key (Value : Virtual_Placement_State) return Boolean is
     (Value.Placement_ID /= 0);

   function Has_Key (Value : Conventional_Placement_State) return Boolean is
     (Value.Placement_ID /= 0);

   function Is_Addressable
     (Value : Virtual_Placement_State) return Boolean is
     (Value.Placement_ID /= 0);

   function Is_Addressable
     (Value : Conventional_Placement_State) return Boolean is
     (Value.Placement_ID /= 0
      and then Value.Protocol = Terminal.App.Render_Model.Image_Kitty);

   function Is_Null (Placement : Virtual_Placement_Access) return Boolean is
     (Placement = null);

   function Is_Null
     (Placement : Conventional_Placement_Access) return Boolean is
     (Placement = null);

   function Is_Linked
     (Placement : Virtual_Placement_Access) return Boolean is
     (Placement /= null and then Placement.Link.Linked);

   function Is_Linked
     (Placement : Conventional_Placement_Access) return Boolean is
     (Placement /= null and then Placement.Link.Linked);

   procedure Set_State
     (Placement : Virtual_Placement_Access;
      Value     : Virtual_Placement_State) is
   begin
      Placement.State := Value;
   end Set_State;

   procedure Set_State
     (Placement : Conventional_Placement_Access;
      Value     : Conventional_Placement_State) is
   begin
      Placement.State := Value;
   end Set_State;

   procedure Set_Next
     (Placement : Virtual_Placement_Access;
      Value     : Virtual_Placement_Access) is
   begin
      Placement.Link.Next_Link := Value;
   end Set_Next;

   procedure Set_Next
     (Placement : Conventional_Placement_Access;
      Value     : Conventional_Placement_Access) is
   begin
      Placement.Link.Next_Link := Value;
   end Set_Next;

   procedure Set_Linked
     (Placement : Virtual_Placement_Access;
      Value     : Boolean) is
   begin
      Placement.Link.Linked := Value;
   end Set_Linked;

   procedure Set_Linked
     (Placement : Conventional_Placement_Access;
      Value     : Boolean) is
   begin
      Placement.Link.Linked := Value;
   end Set_Linked;

   function Same_Identity
     (Left, Right : Virtual_Placement_State) return Boolean is
     (Left.Stream_ID = Right.Stream_ID
      and then Left.Alternate_Screen = Right.Alternate_Screen
      and then Left.Screen_Generation = Right.Screen_Generation
      and then Left.Image_ID = Right.Image_ID
      and then Left.Placement_ID = Right.Placement_ID);

   function Same_Identity
     (Left, Right : Conventional_Placement_State) return Boolean is
     (Left.Stream_ID = Right.Stream_ID
      and then Left.Alternate_Screen = Right.Alternate_Screen
      and then Left.Screen_Generation = Right.Screen_Generation
      and then Left.Image_ID = Right.Image_ID
      and then Left.Placement_ID = Right.Placement_ID
      and then
        (Left.Protocol = Terminal.App.Render_Model.Image_Kitty)
        = (Right.Protocol = Terminal.App.Render_Model.Image_Kitty));

   procedure Increment
     (Counts : in out Image_Count_Maps.Map;
      Key    : Image_Key) is
   begin
      if Counts.Contains (Key) then
         Counts.Replace (Key, Counts.Element (Key) + 1);
      else
         Counts.Insert (Key, 1);
      end if;
   end Increment;

   procedure Decrement
     (Counts : in out Image_Count_Maps.Map;
      Key    : Image_Key) is
   begin
      if not Counts.Contains (Key) then
         raise Program_Error with "placement image index is inconsistent";
      elsif Counts.Element (Key) = 1 then
         Counts.Delete (Key);
      else
         Counts.Replace (Key, Counts.Element (Key) - 1);
      end if;
   end Decrement;

   package Virtual_Indexing is new Terminal.App.Image_Placements.Indexing
     (Placement_Access  => Virtual_Placement_Access,
      Placement_State   => Virtual_Placement_State,
      Key_Maps          => Virtual_Placement_Maps,
      Address_Maps      => Virtual_Address_Maps,
      Image_Key         => Image_Key,
      Image_Count_Maps  => Image_Count_Maps,
      State_Of          => State,
      Next_Of           => Next,
      Key_Of_State      => Key_Of,
      Address_Of_State  => Address_Of,
      Image_Of_State    => Image_Of,
      Has_Key_State     => Has_Key,
      Addressable_State => Is_Addressable,
      Is_Null_Placement => Is_Null,
      Increment         => Increment,
      Decrement         => Decrement);

   package Conventional_Indexing is new Terminal.App.Image_Placements.Indexing
     (Placement_Access  => Conventional_Placement_Access,
      Placement_State   => Conventional_Placement_State,
      Key_Maps          => Conventional_Placement_Maps,
      Address_Maps      => Conventional_Address_Maps,
      Image_Key         => Image_Key,
      Image_Count_Maps  => Image_Count_Maps,
      State_Of          => State,
      Next_Of           => Next,
      Key_Of_State      => Key_Of,
      Address_Of_State  => Address_Of,
      Image_Of_State    => Image_Of,
      Has_Key_State     => Has_Key,
      Addressable_State => Is_Addressable,
      Is_Null_Placement => Is_Null,
      Increment         => Increment,
      Decrement         => Decrement);

   type Virtual_Indexes is record
      By_Key       : Virtual_Placement_Maps.Map;
      By_Address   : Virtual_Address_Maps.Map;
      Image_Counts : Image_Count_Maps.Map;
   end record;

   type Conventional_Indexes is record
      By_Key       : Conventional_Placement_Maps.Map;
      By_Address   : Conventional_Address_Maps.Map;
      Image_Counts : Image_Count_Maps.Map;
   end record;

   procedure Add
     (Indexes   : in out Virtual_Indexes;
      Placement : Virtual_Placement_Access;
      Value     : Virtual_Placement_State) is
   begin
      Virtual_Indexing.Add
        (Indexes.By_Key, Indexes.By_Address, Indexes.Image_Counts,
         Placement, Value);
   end Add;

   procedure Add
     (Indexes   : in out Conventional_Indexes;
      Placement : Conventional_Placement_Access;
      Value     : Conventional_Placement_State) is
   begin
      Conventional_Indexing.Add
        (Indexes.By_Key, Indexes.By_Address, Indexes.Image_Counts,
         Placement, Value);
   end Add;

   procedure Commit
     (Container : in out Store;
      Indexes   : in out Virtual_Indexes) is
   begin
      Virtual_Placement_Maps.Move
        (Container.Virtual_By_Key, Indexes.By_Key);
      Virtual_Address_Maps.Move
        (Container.Virtual_By_Address, Indexes.By_Address);
      Image_Count_Maps.Move
        (Container.Virtual_Image_Counts, Indexes.Image_Counts);
   end Commit;

   procedure Commit
     (Container : in out Store;
      Indexes   : in out Conventional_Indexes) is
   begin
      Conventional_Placement_Maps.Move
        (Container.Conventional_By_Key, Indexes.By_Key);
      Conventional_Address_Maps.Move
        (Container.Conventional_By_Address, Indexes.By_Address);
      Image_Count_Maps.Move
        (Container.Conventional_Image_Counts, Indexes.Image_Counts);
   end Commit;

   procedure Index
     (Container : in out Store;
      Placement : Virtual_Placement_Access) is
   begin
      Virtual_Indexing.Index
        (Container.Virtual_By_Key,
         Container.Virtual_By_Address,
         Container.Virtual_Image_Counts,
         Placement);
   end Index;

   procedure Unindex
     (Container : in out Store;
      Placement : Virtual_Placement_Access) is
   begin
      Virtual_Indexing.Unindex
        (Container.Virtual_By_Key,
         Container.Virtual_By_Address,
         Container.Virtual_Image_Counts,
         Placement);
   end Unindex;

   procedure Validate_Unindex
     (Container : Store;
      Placement : Virtual_Placement_Access) is
   begin
      Virtual_Indexing.Validate_Unindex
        (Container.Virtual_By_Key,
         Container.Virtual_By_Address,
         Container.Virtual_Image_Counts,
         Placement);
   end Validate_Unindex;

   procedure Validate_Unindex
     (Container : Store;
      Placement : Conventional_Placement_Access) is
   begin
      Conventional_Indexing.Validate_Unindex
        (Container.Conventional_By_Key,
         Container.Conventional_By_Address,
         Container.Conventional_Image_Counts,
         Placement);
   end Validate_Unindex;

   procedure Unindex
     (Container : in out Store;
      Placement : Conventional_Placement_Access) is
   begin
      Conventional_Indexing.Unindex
        (Container.Conventional_By_Key,
         Container.Conventional_By_Address,
         Container.Conventional_Image_Counts,
         Placement);
   end Unindex;

   procedure Index
     (Container : in out Store;
      Placement : Conventional_Placement_Access) is
   begin
      Conventional_Indexing.Index
        (Container.Conventional_By_Key,
         Container.Conventional_By_Address,
         Container.Conventional_Image_Counts,
         Placement);
   end Index;

   procedure Move_Relative_Descendants
     (Container           : in out Store;
      Stream_ID           : Terminal.Core.Graphics_Stream_ID;
      Parent_Image_ID     : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID;
      Alternate_Screen    : Boolean;
      Screen_Generation   : Terminal.Core.Graphics_Screen_Generation;
      Maximum_Depth       : Positive)
   is separate;
   procedure Prepend
     (Container : in out Store;
      Placement : Virtual_Placement_Access) is
   begin
      if Placement = null then
         raise Constraint_Error with "cannot link a null virtual placement";
      elsif Placement.Link.Linked then
         raise Program_Error with "virtual placement is already linked";
      elsif Container.Placement_Count =
        Terminal.Common.Graphics_Limits.Max_Placements
      then
         raise Storage_Error with "graphics placement count overflow";
      end if;
      Index (Container, Placement);
      Placement.Link.Next_Link := Container.Virtual_Head;
      Placement.Link.Linked := True;
      Container.Virtual_Head := Placement;
      Container.Placement_Count := Container.Placement_Count + 1;
   end Prepend;

   procedure Prepend
     (Container : in out Store;
      Placement : Conventional_Placement_Access) is
   begin
      if Placement = null then
         raise Constraint_Error with
           "cannot link a null conventional placement";
      elsif Placement.Link.Linked then
         raise Program_Error with "conventional placement is already linked";
      elsif Container.Placement_Count =
        Terminal.Common.Graphics_Limits.Max_Placements
      then
         raise Storage_Error with "graphics placement count overflow";
      end if;
      Index (Container, Placement);
      Placement.Link.Next_Link := Container.Conventional_Head;
      Placement.Link.Linked := True;
      Container.Conventional_Head := Placement;
      Container.Placement_Count := Container.Placement_Count + 1;
   end Prepend;

   procedure Rebuild_One
     (Container : in out Store;
      Placement : Virtual_Placement_Access;
      Candidate : Virtual_Placement_State)
   is
      Next_Indexes : Virtual_Indexes;
      Current : Virtual_Placement_Access := Container.Virtual_Head;
   begin
      while Current /= null loop
         Add
           (Next_Indexes, Current,
            (if Current = Placement then Candidate else Current.State));
         Current := Current.Link.Next_Link;
      end loop;
      Commit (Container, Next_Indexes);
   end Rebuild_One;

   procedure Rebuild_One
     (Container : in out Store;
      Placement : Conventional_Placement_Access;
      Candidate : Conventional_Placement_State)
   is
      Next_Indexes : Conventional_Indexes;
      Current : Conventional_Placement_Access := Container.Conventional_Head;
   begin
      while Current /= null loop
         Add
           (Next_Indexes, Current,
            (if Current = Placement then Candidate else Current.State));
         Current := Current.Link.Next_Link;
      end loop;
      Commit (Container, Next_Indexes);
   end Rebuild_One;

   procedure Rebuild_All
     (Container  : in out Store;
      Candidates : Virtual_State_Vectors.Vector)
   is
      Next_Indexes : Virtual_Indexes;
      Current : Virtual_Placement_Access := Container.Virtual_Head;
   begin
      for I in 1 .. Natural (Candidates.Length) loop
         Add (Next_Indexes, Current, Candidates.Element (Positive (I)));
         Current := Current.Link.Next_Link;
      end loop;
      Commit (Container, Next_Indexes);
   end Rebuild_All;

   procedure Rebuild_All
     (Container  : in out Store;
      Candidates : Conventional_State_Vectors.Vector)
   is
      Next_Indexes : Conventional_Indexes;
      Current : Conventional_Placement_Access := Container.Conventional_Head;
   begin
      for I in 1 .. Natural (Candidates.Length) loop
         Add (Next_Indexes, Current, Candidates.Element (Positive (I)));
         Current := Current.Link.Next_Link;
      end loop;
      Commit (Container, Next_Indexes);
   end Rebuild_All;

   procedure Update_Virtual is new Terminal.App.Image_Placements.Update_Algorithm
     (Container_Type      => Store,
      Placement_Access    => Virtual_Placement_Access,
      Placement_State     => Virtual_Placement_State,
      Is_Null_Placement   => Is_Null,
      Linked              => Is_Linked,
      State_Of            => State,
      Assign_State        => Set_State,
      Same_Identity_State => Same_Identity,
      Rebuild             => Rebuild_One);

   procedure Update_Conventional is new Terminal.App.Image_Placements.Update_Algorithm
     (Container_Type      => Store,
      Placement_Access    => Conventional_Placement_Access,
      Placement_State     => Conventional_Placement_State,
      Is_Null_Placement   => Is_Null,
      Linked              => Is_Linked,
      State_Of            => State,
      Assign_State        => Set_State,
      Same_Identity_State => Same_Identity,
      Rebuild             => Rebuild_One);

   procedure Update_All_Virtual is new Terminal.App.Image_Placements.Bulk_Update_Algorithm
     (Container_Type      => Store,
      Placement_Access    => Virtual_Placement_Access,
      Placement_State     => Virtual_Placement_State,
      State_Vectors       => Virtual_State_Vectors,
      Is_Null_Placement   => Is_Null,
      State_Of            => State,
      Assign_State        => Set_State,
      Next_Of             => Next,
      Same_Identity_State => Same_Identity,
      Rebuild             => Rebuild_All);

   procedure Update_All_Conventional is new Terminal.App.Image_Placements.Bulk_Update_Algorithm
     (Container_Type      => Store,
      Placement_Access    => Conventional_Placement_Access,
      Placement_State     => Conventional_Placement_State,
      State_Vectors       => Conventional_State_Vectors,
      Is_Null_Placement   => Is_Null,
      State_Of            => State,
      Assign_State        => Set_State,
      Next_Of             => Next,
      Same_Identity_State => Same_Identity,
      Rebuild             => Rebuild_All);

   procedure Update
     (Container : in out Store;
      Placement : Virtual_Placement_Access;
      Process   : not null access procedure
        (Item : in out Virtual_Placement_State)) is
   begin
      Update_Virtual (Container, Placement, Process);
   end Update;

   procedure Update_All
     (Container : in out Store;
      Process   : not null access procedure
        (Item : in out Virtual_Placement_State)) is
   begin
      Update_All_Virtual
        (Container,
         Container.Virtual_Head,
         Ada.Containers.Count_Type (Container.Placement_Count),
         Process);
   end Update_All;

   procedure Update_All
     (Container : in out Store;
      Process   : not null access procedure
        (Item : in out Conventional_Placement_State)) is
   begin
      Update_All_Conventional
        (Container,
         Container.Conventional_Head,
         Ada.Containers.Count_Type (Container.Placement_Count),
         Process);
   end Update_All;

   procedure Update
     (Container : in out Store;
      Placement : Conventional_Placement_Access;
      Process   : not null access procedure
        (Item : in out Conventional_Placement_State)) is
   begin
      Update_Conventional (Container, Placement, Process);
   end Update;

   procedure Validate_Placement_Count (Container : Store) is
   begin
      if Container.Placement_Count = 0 then
         raise Program_Error with "graphics placement count underflow";
      end if;
   end Validate_Placement_Count;

   procedure Decrement_Placement_Count (Container : in out Store) is
   begin
      Container.Placement_Count := Container.Placement_Count - 1;
   end Decrement_Placement_Count;

   procedure Validate_Remove
     (Container : Store;
      Previous  : Virtual_Placement_Access;
      Current   : Virtual_Placement_Access) is
   begin
      if Current = null then
         raise Constraint_Error with "cannot remove a null placement";
      elsif Container.Placement_Count = 0 then
         raise Program_Error with "graphics placement count underflow";
      elsif Previous = null and then Container.Virtual_Head /= Current then
         raise Program_Error with "placement is not the list head";
      elsif Previous /= null and then Previous.Link.Next_Link /= Current then
         raise Program_Error with "placement predecessor mismatch";
      end if;
      Validate_Unindex (Container, Current);
   end Validate_Remove;

   procedure Validate_Remove
     (Container : Store;
      Previous  : Conventional_Placement_Access;
      Current   : Conventional_Placement_Access) is
   begin
      if Current = null then
         raise Constraint_Error with "cannot remove a null placement";
      elsif Container.Placement_Count = 0 then
         raise Program_Error with "graphics placement count underflow";
      elsif Previous = null and then Container.Conventional_Head /= Current then
         raise Program_Error with "placement is not the list head";
      elsif Previous /= null and then Previous.Link.Next_Link /= Current then
         raise Program_Error with "placement predecessor mismatch";
      end if;
      Validate_Unindex (Container, Current);
   end Validate_Remove;

   procedure Remove_Virtual is new Terminal.App.Image_Placements.Removal_Algorithm
     (Container_Type    => Store,
      Placement_Access  => Virtual_Placement_Access,
      Null_Placement    => null,
      Is_Null_Placement => Is_Null,
      Next_Of           => Next,
      Assign_Next       => Set_Next,
      Assign_Linked     => Set_Linked,
      Unindex_Placement => Unindex,
      Validate_Count    => Validate_Placement_Count,
      Decrement_Count   => Decrement_Placement_Count,
      Free_Placement    => Free_Virtual);

   procedure Remove_Conventional is new Terminal.App.Image_Placements.Removal_Algorithm
     (Container_Type    => Store,
      Placement_Access  => Conventional_Placement_Access,
      Null_Placement    => null,
      Is_Null_Placement => Is_Null,
      Next_Of           => Next,
      Assign_Next       => Set_Next,
      Assign_Linked     => Set_Linked,
      Unindex_Placement => Unindex,
      Validate_Count    => Validate_Placement_Count,
      Decrement_Count   => Decrement_Placement_Count,
      Free_Placement    => Free_Conventional);

   procedure Remove
     (Container : in out Store;
      Previous  : Virtual_Placement_Access;
      Current   : in out Virtual_Placement_Access;
      Next      : out Virtual_Placement_Access) is
   begin
      Remove_Virtual
        (Container, Container.Virtual_Head, Previous, Current, Next);
   end Remove;

   procedure Remove
     (Container : in out Store;
      Previous  : Conventional_Placement_Access;
      Current   : in out Conventional_Placement_Access;
      Next      : out Conventional_Placement_Access) is
   begin
      Remove_Conventional
        (Container, Container.Conventional_Head, Previous, Current, Next);
   end Remove;

   procedure Release_Unowned
     (Placement : in out Virtual_Placement_Access) is
   begin
      if Placement /= null then
         if Placement.Link.Linked then
            raise Program_Error with
              "cannot release a linked virtual placement as unowned";
         end if;
         Free_Virtual (Placement);
      end if;
   end Release_Unowned;

   procedure Release_Unowned
     (Placement : in out Conventional_Placement_Access) is
   begin
      if Placement /= null then
         if Placement.Link.Linked then
            raise Program_Error with
              "cannot release a linked conventional placement as unowned";
         end if;
         Free_Conventional (Placement);
      end if;
   end Release_Unowned;

   procedure Release (Container : in out Store) is
      Virtual_Current : Virtual_Placement_Access := Container.Virtual_Head;
      Conventional_Current : Conventional_Placement_Access :=
        Container.Conventional_Head;
   begin
      while Virtual_Current /= null loop
         declare
            Next : constant Virtual_Placement_Access :=
              Virtual_Current.Link.Next_Link;
         begin
            Free_Virtual (Virtual_Current);
            Virtual_Current := Next;
         end;
      end loop;
      while Conventional_Current /= null loop
         declare
            Next : constant Conventional_Placement_Access :=
              Conventional_Current.Link.Next_Link;
         begin
            Free_Conventional (Conventional_Current);
            Conventional_Current := Next;
         end;
      end loop;
      Container.Virtual_Head := null;
      Container.Conventional_Head := null;
      Container.Placement_Count := 0;
      Container.Virtual_By_Key.Clear;
      Container.Conventional_By_Key.Clear;
      Container.Virtual_By_Address.Clear;
      Container.Conventional_By_Address.Clear;
      Container.Virtual_Image_Counts.Clear;
      Container.Conventional_Image_Counts.Clear;
   end Release;

   overriding procedure Finalize (Container : in out Store) is
   begin
      Release (Container);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Renderer_State,
            E,
            "finalize image placements");
   end Finalize;

   function Resolve
     (Cell_Width   : Natural;
      Cell_Height  : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header       : Terminal.App.Graphics.Graphics_Header) return Geometry
   is separate;
end Terminal.App.Image_Placements;
