with Ada.Containers;

package body Terminal.App.Image_Store.Indexes is
   use type Interfaces.Unsigned_64;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;

   procedure Install
     (Container : in out Store;
      Object    : Image_Object_Access;
      Control   : access Allocation_Control := null)
   is
      ID_Key : constant Object_Key :=
        (Object.State.Stream_ID, Object.State.ID);
      Number_Key : constant Object_Key :=
        (Object.State.Stream_ID, Object.State.Number);
      Order_Key : constant Storage_Key :=
        (Object.State.Stream_ID, Object.State.Storage_Order);
      ID_Inserted, Number_Inserted, Order_Inserted : Boolean := False;
      ID_Replaced, Number_Replaced, Order_Replaced : Boolean := False;
      Previous_ID, Previous_Number, Previous_Order : Image_Object_Access := null;

      procedure Require_Allocation is
      begin
         if Control /= null and then not Allocation_Allowed (Control.all) then
            raise Storage_Error with "injected image-index allocation failure";
         end if;
      end Require_Allocation;

      procedure Set_Object
        (Map       : in out Object_Maps.Map;
         Key       : Object_Key;
         Target    : Image_Object_Access;
         Inserted  : out Boolean;
         Replaced  : out Boolean;
         Previous  : out Image_Object_Access)
      is
      begin
         Inserted := False;
         Replaced := False;
         Previous := null;
         if Map.Contains (Key) then
            Previous := Map.Element (Key);
            Map.Replace (Key, Target);
            Replaced := True;
         else
            Map.Insert (Key, Target);
            Inserted := True;
         end if;
      end Set_Object;

      procedure Roll_Back is
      begin
         if Order_Inserted then
            Container.By_Storage_Order.Delete (Order_Key);
         elsif Order_Replaced then
            Container.By_Storage_Order.Replace (Order_Key, Previous_Order);
         end if;
         if Number_Inserted then
            Container.By_Number.Delete (Number_Key);
         elsif Number_Replaced then
            Container.By_Number.Replace (Number_Key, Previous_Number);
         end if;
         if ID_Inserted then
            Container.By_ID.Delete (ID_Key);
         elsif ID_Replaced then
            Container.By_ID.Replace (ID_Key, Previous_ID);
         end if;
      end Roll_Back;
   begin
      Require_Allocation;
      Container.By_ID.Reserve_Capacity
        (Ada.Containers.Count_Type (Container.Objects));
      Container.By_Number.Reserve_Capacity
        (Ada.Containers.Count_Type (Container.Objects));
      Container.By_Storage_Order.Reserve_Capacity
        (Ada.Containers.Count_Type (Container.Objects));
      if Object.State.ID /= 0 then
         Require_Allocation;
         Set_Object
           (Container.By_ID, ID_Key, Object,
            ID_Inserted, ID_Replaced, Previous_ID);
      end if;
      if Object.State.Number /= 0 then
         Require_Allocation;
         Set_Object
           (Container.By_Number, Number_Key, Object,
            Number_Inserted, Number_Replaced, Previous_Number);
      end if;
      if Object.State.Storage_Order /= 0 then
         Require_Allocation;
         if Container.By_Storage_Order.Contains (Order_Key) then
            Previous_Order := Container.By_Storage_Order.Element (Order_Key);
            Container.By_Storage_Order.Replace (Order_Key, Object);
            Order_Replaced := True;
         else
            Container.By_Storage_Order.Insert (Order_Key, Object);
            Order_Inserted := True;
         end if;
      end if;
      --  Attach the collision chains only after every allocating map
      --  operation has succeeded.  This keeps rollback allocation-free and
      --  leaves the existing index topology untouched on failure.
      if Object.State.ID /= 0 then
         Object.ID_Index_Previous := null;
         Object.ID_Index_Next := Previous_ID;
         if Previous_ID /= null then
            Previous_ID.ID_Index_Previous := Object;
         end if;
      end if;
      if Object.State.Number /= 0 then
         Object.Number_Index_Previous := null;
         Object.Number_Index_Next := Previous_Number;
         if Previous_Number /= null then
            Previous_Number.Number_Index_Previous := Object;
         end if;
      end if;
   exception
      when others =>
         Roll_Back;
         raise;
   end Install;

   type Collision_Index_Kind is (ID_Index, Number_Index);

   function Previous
     (Object : Image_Object_Access;
      Kind   : Collision_Index_Kind) return Image_Object_Access is
     (if Kind = ID_Index
      then Object.ID_Index_Previous
      else Object.Number_Index_Previous);

   function Following
     (Object : Image_Object_Access;
      Kind   : Collision_Index_Kind) return Image_Object_Access is
     (if Kind = ID_Index
      then Object.ID_Index_Next
      else Object.Number_Index_Next);

   function Matches
     (Object : Image_Object_Access;
      Kind   : Collision_Index_Kind;
      Key    : Object_Key) return Boolean is
     (Object /= null
      and then Object.State.Stream_ID = Key.Stream_ID
      and then
        (if Kind = ID_Index
         then Object.State.ID = Key.Value
         else Object.State.Number = Key.Value));

   function Head_At
     (Container : Store;
      Kind      : Collision_Index_Kind;
      Key       : Object_Key) return Image_Object_Access is
     (if Kind = ID_Index
      then
        (if Container.By_ID.Contains (Key)
         then Container.By_ID.Element (Key)
         else null)
      else
        (if Container.By_Number.Contains (Key)
         then Container.By_Number.Element (Key)
         else null));

   procedure Validate_Chain
     (Container : Store;
      Object    : not null Image_Object_Access;
      Kind      : Collision_Index_Kind;
      Key       : Object_Key)
   is
      Current : Image_Object_Access := Object;
      Adjacent : Image_Object_Access;
      Steps : Natural := 0;
      Node_Limit : constant Natural :=
        Natural (Container.By_Storage_Order.Length);
      Label_Text : constant String :=
        (if Kind = ID_Index then "image ID" else "image number");
   begin
      while Previous (Current, Kind) /= null loop
         Adjacent := Previous (Current, Kind);
         if Following (Adjacent, Kind) /= Current
           or else not Matches (Adjacent, Kind, Key)
         then
            raise Program_Error with
              Label_Text & " index predecessor is inconsistent";
         end if;
         Current := Adjacent;
         Steps := Steps + 1;
         if Steps > Node_Limit then
            raise Program_Error with Label_Text & " index contains a cycle";
         end if;
      end loop;
      if Head_At (Container, Kind, Key) /= Current then
         raise Program_Error with Label_Text & " index head is inconsistent";
      end if;

      Current := Object;
      Steps := 0;
      while Following (Current, Kind) /= null loop
         Adjacent := Following (Current, Kind);
         if Previous (Adjacent, Kind) /= Current
           or else not Matches (Adjacent, Kind, Key)
         then
            raise Program_Error with
              Label_Text & " index successor is inconsistent";
         end if;
         Current := Adjacent;
         Steps := Steps + 1;
         if Steps > Node_Limit then
            raise Program_Error with Label_Text & " index contains a cycle";
         end if;
      end loop;
   end Validate_Chain;

   procedure Validate_Remove
     (Container : Store;
      Object    : not null Image_Object_Access)
   is
      ID_Key : constant Object_Key :=
        (Object.State.Stream_ID, Object.State.ID);
      Number_Key : constant Object_Key :=
        (Object.State.Stream_ID, Object.State.Number);
      Order_Key : constant Storage_Key :=
        (Object.State.Stream_ID, Object.State.Storage_Order);
   begin
      if Object.State.ID /= 0 then
         Validate_Chain (Container, Object, ID_Index, ID_Key);
      elsif Object.ID_Index_Previous /= null or else Object.ID_Index_Next /= null
      then
         raise Program_Error with "unidentified image is linked in the ID index";
      end if;
      if Object.State.Number /= 0 then
         Validate_Chain (Container, Object, Number_Index, Number_Key);
      elsif Object.Number_Index_Previous /= null
        or else Object.Number_Index_Next /= null
      then
         raise Program_Error with
           "unnumbered image is linked in the number index";
      end if;
      if Object.State.Storage_Order /= 0
        and then
          (not Container.By_Storage_Order.Contains (Order_Key)
           or else Container.By_Storage_Order.Element (Order_Key) /= Object)
      then
         raise Program_Error with "image storage-order index is inconsistent";
      end if;
   end Validate_Remove;

   procedure Remove_Unchecked
     (Container : in out Store;
      Object    : not null Image_Object_Access)
   is
      ID_Key : constant Object_Key :=
        (Object.State.Stream_ID, Object.State.ID);
      Number_Key : constant Object_Key :=
        (Object.State.Stream_ID, Object.State.Number);
      Order_Key : constant Storage_Key :=
        (Object.State.Stream_ID, Object.State.Storage_Order);

      procedure Remove_ID is
      begin
         if Object.ID_Index_Previous = null then
            if Object.ID_Index_Next = null then
               Container.By_ID.Delete (ID_Key);
            else
               Container.By_ID.Replace (ID_Key, Object.ID_Index_Next);
            end if;
         else
            Object.ID_Index_Previous.ID_Index_Next := Object.ID_Index_Next;
         end if;
         if Object.ID_Index_Next /= null then
            Object.ID_Index_Next.ID_Index_Previous := Object.ID_Index_Previous;
         end if;
         Object.ID_Index_Previous := null;
         Object.ID_Index_Next := null;
      end Remove_ID;

      procedure Remove_Number is
      begin
         if Object.Number_Index_Previous = null then
            if Object.Number_Index_Next = null then
               Container.By_Number.Delete (Number_Key);
            else
               Container.By_Number.Replace
                 (Number_Key, Object.Number_Index_Next);
            end if;
         else
            Object.Number_Index_Previous.Number_Index_Next :=
              Object.Number_Index_Next;
         end if;
         if Object.Number_Index_Next /= null then
            Object.Number_Index_Next.Number_Index_Previous :=
              Object.Number_Index_Previous;
         end if;
         Object.Number_Index_Previous := null;
         Object.Number_Index_Next := null;
      end Remove_Number;
   begin
      if Object.State.ID /= 0 then
         Remove_ID;
      end if;
      if Object.State.Number /= 0 then
         Remove_Number;
      end if;
      if Object.State.Storage_Order /= 0
      then
         Container.By_Storage_Order.Delete (Order_Key);
      end if;
   end Remove_Unchecked;

   procedure Remove
     (Container : in out Store;
      Object    : not null Image_Object_Access) is
   begin
      Validate_Remove (Container, Object);
      Remove_Unchecked (Container, Object);
   end Remove;
end Terminal.App.Image_Store.Indexes;
