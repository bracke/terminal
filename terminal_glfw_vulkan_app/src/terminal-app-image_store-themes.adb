with Ada.Containers;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;
with System;
with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.Image_Store.Themes is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Render_Model.Image_Data_View;
   procedure Free_Operation is new Ada.Unchecked_Deallocation
     (Theme_Operation, Theme_Operation_Access);

   function Descriptor_Of
     (Operation : not null Theme_Operation_Access)
      return Theme_Operation_Descriptor is
   begin
      if Operation.Is_Composition then
         return
           (Is_Composition   => True,
            Archived_Frames  => Operation.Archived_Frames,
            Target_Frame     => Operation.Target_Frame,
            Target_X         => Operation.Target_X,
            Target_Y         => Operation.Target_Y,
            Composition_Mode => Operation.Composition_Mode,
            Source_Frame     => Operation.Source_Frame,
            Source_X         => Operation.Source_X,
            Source_Y         => Operation.Source_Y,
            Region_Width     => Operation.Region_Width,
            Region_Height    => Operation.Region_Height);
      else
         return
           (Is_Composition       => False,
            Archived_Frames      => Operation.Archived_Frames,
            Target_Frame         => Operation.Target_Frame,
            Target_X             => Operation.Target_X,
            Target_Y             => Operation.Target_Y,
            Composition_Mode     => Operation.Composition_Mode,
            New_Frame            => Operation.New_Frame,
            Base_Frame           => Operation.Base_Frame,
            Raw_Format           => Operation.Raw_Format,
            Data_Width           => Operation.Data_Width,
            Data_Height          => Operation.Data_Height,
            Data_Row_Stride_Bytes => Operation.Data_Row_Stride_Bytes,
            Background_Color     => Operation.Background_Color);
      end if;
   end Descriptor_Of;

   function Data_Description_Valid
     (Description : Theme_Operation_Descriptor;
      Length      : Natural) return Boolean
   is
      Bytes_Per_Pixel : Natural;
      Row_Bytes       : Natural;
      Required        : Natural;
   begin
      if Description.Is_Composition then
         return Length = 0
           and then Description.Region_Width > 0
           and then Description.Region_Height > 0
           and then Description.Composition_Mode <= 1;
      end if;

      Bytes_Per_Pixel :=
        (if Description.Raw_Format = 8 then 1
         elsif Description.Raw_Format = 16 then 2
         elsif Description.Raw_Format in 24 | 32
         then Description.Raw_Format / 8
         else 0);
      if Bytes_Per_Pixel = 0
        or else Description.Data_Width = 0
        or else Description.Data_Height = 0
        or else Description.Data_Width > Natural'Last / Bytes_Per_Pixel
      then
         return False;
      end if;
      Row_Bytes := Description.Data_Width * Bytes_Per_Pixel;
      if Description.Data_Row_Stride_Bytes < Row_Bytes
        or else
          Description.Data_Height - 1 >
            (Natural'Last - Row_Bytes) / Description.Data_Row_Stride_Bytes
      then
         return False;
      end if;
      Required :=
        (Description.Data_Height - 1) * Description.Data_Row_Stride_Bytes
        + Row_Bytes;
      return Length >= Required and then Description.Composition_Mode <= 1;
   end Data_Description_Valid;

   procedure Validate_Data_Description
     (Description : Theme_Operation_Descriptor;
      Length      : Natural) is
   begin
      if not Data_Description_Valid (Description, Length) then
         raise Constraint_Error with "invalid or truncated theme operation data";
      end if;
   end Validate_Data_Description;

   procedure Create
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Owned_Image_Data.Owner;
      Operation   : out Theme_Operation_Access)
   is
      Length : constant Natural := Terminal.App.Owned_Image_Data.Length (Data);
   begin
      Validate_Data_Description (Description, Length);
      if Description.Is_Composition then
         Operation := new Theme_Operation'
           (Is_Composition   => True,
            Archived_Frames  => Description.Archived_Frames,
            Target_Frame     => Description.Target_Frame,
            Target_X         => Description.Target_X,
            Target_Y         => Description.Target_Y,
            Composition_Mode => Description.Composition_Mode,
            Bytes            => <>,
            Length           => Length,
            Owner            => null,
            Next             => null,
            Source_Frame     => Description.Source_Frame,
            Source_X         => Description.Source_X,
            Source_Y         => Description.Source_Y,
            Region_Width     => Description.Region_Width,
            Region_Height    => Description.Region_Height);
      else
         Operation := new Theme_Operation'
           (Is_Composition       => False,
            Archived_Frames      => Description.Archived_Frames,
            Target_Frame         => Description.Target_Frame,
            Target_X             => Description.Target_X,
            Target_Y             => Description.Target_Y,
            Composition_Mode     => Description.Composition_Mode,
            Bytes                => <>,
            Length               => Length,
            Owner                => null,
            Next                 => null,
            New_Frame            => Description.New_Frame,
            Base_Frame           => Description.Base_Frame,
            Raw_Format           => Description.Raw_Format,
            Data_Width           => Description.Data_Width,
            Data_Height          => Description.Data_Height,
            Data_Row_Stride_Bytes => Description.Data_Row_Stride_Bytes,
            Background_Color     => Description.Background_Color);
      end if;
      Terminal.App.Owned_Image_Data.Move (Data, Operation.Bytes);
   end Create;

   procedure Append_Unowned
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access) is
   begin
      if Operation = null or else Operation.Next /= null then
         raise Program_Error with "theme operation is null or already linked";
      elsif Head = null then
         Head := Operation;
      elsif Tail = null then
         raise Program_Error with "theme-list tail invariant violated";
      else
         Tail.Next := Operation;
      end if;
      Tail := Operation;
      Operation := null;
   end Append_Unowned;

   procedure Release_Unowned (Head : in out Theme_Operation_Access) is
   begin
      Release_Theme_Operation_List (Head);
   end Release_Unowned;

   function Unowned_Length
     (Operation : Theme_Operation_Access) return Natural
   is
      Current : Theme_Operation_Access := Operation;
      Slow    : Theme_Operation_Access := Operation;
      Fast    : Theme_Operation_Access := Operation;
      Total   : Natural := 0;
   begin
      while Fast /= null and then Fast.Next /= null loop
         Slow := Slow.Next;
         Fast := Fast.Next.Next;
         if Slow = Fast then
            raise Program_Error with "theme operation list is cyclic";
         end if;
      end loop;
      while Current /= null loop
         if Current.Owner /= null then
            raise Program_Error with
              "owned theme operation requires borrow-bound traversal";
         elsif Current.Length > Natural'Last - Total then
            raise Storage_Error with "theme operation length overflow";
         end if;
         Total := Total + Current.Length;
         Current := Current.Next;
      end loop;
      return Total;
   end Unowned_Length;

   function Element
     (Borrow   : Data_Borrow;
      Position : Cursor) return Theme_Operation_Access
   is
   begin
      if Borrow.Hold.Object = null then
         raise Program_Error with "theme traversal requires an active borrow";
      elsif Position.Owner /= Borrow.Hold.Object then
         raise Program_Error with "theme cursor belongs to a different borrow";
      elsif Position.Token = 0 or else Position.Token /= Borrow.Hold.Token then
         raise Program_Error with "theme cursor borrow has expired";
      elsif Position.Current = null then
         raise Constraint_Error with "theme cursor has no element";
      end if;
      if Position.Current.Owner /= Borrow.Hold.Object then
         raise Program_Error with "theme cursor is not owned by borrowed object";
      end if;
      return Position.Current;
   end Element;

   function First (Borrow : Data_Borrow) return Cursor is
   begin
      if Borrow.Hold.Object = null then
         raise Program_Error with "theme traversal requires an active borrow";
      end if;
      return
        (Owner   => Borrow.Hold.Object,
         Current => Borrow.Hold.Object.State.Theme_Operations,
         Token   => Borrow.Hold.Token);
   end First;

   function Has_Element (Position : Cursor) return Boolean is
     (Position.Current /= null);

   procedure Next (Borrow : Data_Borrow; Position : in out Cursor) is
      Current : constant Theme_Operation_Access := Element (Borrow, Position);
   begin
      Position.Current := Current.Next;
   end Next;

   function Descriptor
     (Borrow   : Data_Borrow;
      Position : Cursor) return Theme_Operation_Descriptor
   is
      Operation : constant Theme_Operation_Access :=
        Element (Borrow, Position);
   begin
      return Descriptor_Of (Operation);
   end Descriptor;

   function Visit_Data
     (Borrow   : Data_Borrow;
      Position : Cursor;
      Process  : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array)) return Boolean
   is
      View : constant Terminal.App.Render_Model.Image_Data_View :=
        Terminal.App.Owned_Image_Data.Unsafe_View
          (Element (Borrow, Position).Bytes);
   begin
      if View /= null then
         Process (View.all);
         return True;
      end if;
      return False;
   end Visit_Data;

   function Count (Object : Image_Object_Access) return Natural is
     (if Object = null then 0 else Object.State.Theme_Operation_Count);

   procedure Clear
     (Container : in out Store; Object : Image_Object_Access)
   is
      Previous : Theme_Operation_Access;
      Previous_Tail : Theme_Operation_Access;
      Previous_Count : Natural;
      Previous_Bytes : Natural;
      Previous_Addresses : Address_Sets.Set;
   begin
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Object.State.Theme_Transaction_Active then
         raise Program_Error with "theme transaction is active";
      end if;
      Assert_Not_Borrowed (Object.all);
      Previous := Object.State.Theme_Operations;
      Previous_Tail := Object.State.Theme_Operations_Tail;
      Previous_Count := Object.State.Theme_Operation_Count;
      Previous_Bytes := Object.State.Theme_Operation_Bytes;
      Address_Sets.Move
        (Target => Previous_Addresses, Source => Object.State.Theme_Addresses);
      Object.State.Theme_Operations := null;
      Object.State.Theme_Operations_Tail := null;
      Object.State.Theme_Operation_Count := 0;
      Object.State.Theme_Operation_Bytes := 0;
      begin
         Synchronize (Container, Object);
      exception
         when others =>
            Object.State.Theme_Operations := Previous;
            Object.State.Theme_Operations_Tail := Previous_Tail;
            Object.State.Theme_Operation_Count := Previous_Count;
            Object.State.Theme_Operation_Bytes := Previous_Bytes;
            Address_Sets.Move
              (Target => Object.State.Theme_Addresses,
               Source => Previous_Addresses);
            raise;
      end;
      Release_Theme_Operation_List (Previous);
   end Clear;

   procedure Archive_Root
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive)
   is
      type Archive_Entry is record
         Operation : Theme_Operation_Access := null;
         Keep      : Boolean := False;
         Previous_Next : Theme_Operation_Access := null;
         Previous_Archived : Boolean := False;
      end record;
      package Archive_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Archive_Entry);
      function Hash_Frame (Value : Positive) return Ada.Containers.Hash_Type is
        (Ada.Containers.Hash_Type'Mod (Value));
      package Frame_Sets is new Ada.Containers.Hashed_Sets
        (Element_Type        => Positive,
         Hash                => Hash_Frame,
         Equivalent_Elements => "=");
   begin
      if not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Object.State.Theme_Operations = null then
         return;
      elsif Object.State.Theme_Transaction_Active then
         raise Program_Error with "theme transaction is active";
      elsif Object.State.Theme_Operation_Count > Max_Operations then
         raise Program_Error with "theme operation limit invariant violated";
      end if;
      Assert_Not_Borrowed (Object.all);
      declare
         Operation_Count : constant Positive :=
           Positive (Object.State.Theme_Operation_Count);
         Entries : Archive_Vectors.Vector;
         Needed : Frame_Sets.Set;
         Current : Theme_Operation_Access := Object.State.Theme_Operations;
         New_Head : Theme_Operation_Access := null;
         New_Tail : Theme_Operation_Access := null;
         New_Count : Natural := 0;
         New_Bytes : Natural := 0;
         New_Addresses : Address_Sets.Set;
         Previous_Addresses : Address_Sets.Set;
         Previous_Head : constant Theme_Operation_Access :=
           Object.State.Theme_Operations;
         Previous_Tail : constant Theme_Operation_Access :=
           Object.State.Theme_Operations_Tail;
         Previous_Count : constant Natural := Object.State.Theme_Operation_Count;
         Previous_Bytes : constant Natural := Object.State.Theme_Operation_Bytes;
      begin
         Entries.Reserve_Capacity (Ada.Containers.Count_Type (Operation_Count));
         for I in 1 .. Operation_Count loop
            if Current = null then
               raise Program_Error with
                 "theme operation count invariant violated";
            end if;
            Entries.Append
              (Archive_Entry'
                 (Operation         => Current,
                  Keep              => False,
                  Previous_Next     => Current.Next,
                  Previous_Archived => Current.Archived_Frames));
            Current := Current.Next;
         end loop;
         if Current /= null then
            raise Program_Error with "theme operation count invariant violated";
         end if;
         Needed.Include (1);
         for I in reverse Entries.First_Index .. Entries.Last_Index loop
            Current := Entries (I).Operation;
            if Needed.Contains (Current.Target_Frame) then
               Entries.Replace_Element
                 (I,
                  Archive_Entry'
                    (Operation         => Current,
                     Keep              => True,
                     Previous_Next     => Entries (I).Previous_Next,
                     Previous_Archived => Entries (I).Previous_Archived));
               if Current.Is_Composition then
                  if Current.Source_Frame > 0 then
                     Needed.Include (Positive (Current.Source_Frame));
                  end if;
               elsif Current.New_Frame then
                  Needed.Exclude (Current.Target_Frame);
                  if Current.Base_Frame > 0 then
                     Needed.Include (Positive (Current.Base_Frame));
                  end if;
               end if;
            end if;
         end loop;
         for I in Entries.First_Index .. Entries.Last_Index loop
            if Entries (I).Keep then
               New_Count := New_Count + 1;
               New_Bytes := Checked_Total
                 (New_Bytes, Entries (I).Operation.Length);
               if not Terminal.App.Owned_Image_Data.Is_Empty
                 (Entries (I).Operation.Bytes)
               then
                  New_Addresses.Insert
                    (Terminal.App.Owned_Image_Data.Unsafe_View
                       (Entries (I).Operation.Bytes).all'Address);
               end if;
            end if;
         end loop;
         for I in Entries.First_Index .. Entries.Last_Index loop
            Current := Entries (I).Operation;
            Current.Next := null;
            if Entries (I).Keep then
               Current.Archived_Frames := True;
               if New_Tail = null then
                  New_Head := Current;
               else
                  New_Tail.Next := Current;
               end if;
               New_Tail := Current;
            end if;
         end loop;
         Address_Sets.Move
           (Target => Previous_Addresses, Source => Object.State.Theme_Addresses);
         Object.State.Theme_Operations := New_Head;
         Object.State.Theme_Operations_Tail := New_Tail;
         Object.State.Theme_Operation_Count := New_Count;
         Object.State.Theme_Operation_Bytes := New_Bytes;
         Address_Sets.Move
           (Target => Object.State.Theme_Addresses, Source => New_Addresses);
         begin
            Synchronize (Container, Object);
         exception
            when others =>
               for I in Entries.First_Index .. Entries.Last_Index loop
                  Entries (I).Operation.Next := Entries (I).Previous_Next;
                  Entries (I).Operation.Archived_Frames :=
                    Entries (I).Previous_Archived;
               end loop;
               Object.State.Theme_Operations := Previous_Head;
               Object.State.Theme_Operations_Tail := Previous_Tail;
               Object.State.Theme_Operation_Count := Previous_Count;
               Object.State.Theme_Operation_Bytes := Previous_Bytes;
               Address_Sets.Move
                 (Target => New_Addresses,
                  Source => Object.State.Theme_Addresses);
               Address_Sets.Move
                 (Target => Object.State.Theme_Addresses,
                  Source => Previous_Addresses);
               raise;
         end;
         for I in Entries.First_Index .. Entries.Last_Index loop
            if not Entries (I).Keep then
               Current := Entries (I).Operation;
               Terminal.App.Owned_Image_Data.Release (Current.Bytes);
               Free_Operation (Current);
            end if;
         end loop;
      end;
   end Archive_Root;

   procedure Append_List
     (Container   : in out Store;
      Object      : Image_Object_Access;
      Head        : in out Theme_Operation_Access;
      First       : out Theme_Operation_Access;
      Last        : out Theme_Operation_Access;
      Added_Count : out Natural;
      Added_Bytes : out Natural)
   is
      Current : Theme_Operation_Access := Head;
      Slow    : Theme_Operation_Access := Head;
      Fast    : Theme_Operation_Access := Head;
      Previous_Tail : Theme_Operation_Access;
      Seen : Address_Sets.Set;
   begin
      First := null;
      Last := null;
      Added_Count := 0;
      Added_Bytes := 0;
      if Head = null then
         raise Constraint_Error with "cannot append an empty theme list";
      elsif not Is_Owned (Container, Object) then
         raise Program_Error with "image object is not owned by this store";
      end if;
      Assert_Not_Borrowed (Object.all);
      while Fast /= null and then Fast.Next /= null loop
         Slow := Slow.Next;
         Fast := Fast.Next.Next;
         if Slow = Fast then
            raise Program_Error with "theme operation list is cyclic";
         end if;
      end loop;
      while Current /= null loop
         Validate_Data_Description (Descriptor_Of (Current), Current.Length);
         if Current.Owner /= null then
            raise Program_Error with "theme operation is already owned";
         elsif (Terminal.App.Owned_Image_Data.Is_Empty (Current.Bytes)
                and then Current.Length /= 0)
           or else (not Terminal.App.Owned_Image_Data.Is_Empty (Current.Bytes)
                    and then Current.Length /=
                      Terminal.App.Owned_Image_Data.Length (Current.Bytes))
         then
            raise Constraint_Error with
              "theme operation length does not match data";
         elsif not Terminal.App.Owned_Image_Data.Is_Empty (Current.Bytes)
           and then
             (Owns_Data_View
                (Object,
                 Terminal.App.Owned_Image_Data.Unsafe_View (Current.Bytes))
              or else Object.State.Theme_Addresses.Contains
                (Terminal.App.Owned_Image_Data.Unsafe_View
                   (Current.Bytes).all'Address)
              or else Seen.Contains
                (Terminal.App.Owned_Image_Data.Unsafe_View
                   (Current.Bytes).all'Address))
         then
            raise Program_Error with "theme operation aliases owned storage";
         elsif Added_Count = Natural'Last
           or else Current.Length > Natural'Last - Added_Bytes
         then
            raise Storage_Error with "theme operation accounting overflow";
         end if;
         if not Terminal.App.Owned_Image_Data.Is_Empty (Current.Bytes) then
            Seen.Insert
              (Terminal.App.Owned_Image_Data.Unsafe_View
                 (Current.Bytes).all'Address);
         end if;
         Added_Count := Added_Count + 1;
         Added_Bytes := Added_Bytes + Current.Length;
         Last := Current;
         Current := Current.Next;
      end loop;
      if Added_Count > Natural'Last - Object.State.Theme_Operation_Count
        or else Added_Bytes > Natural'Last - Object.State.Theme_Operation_Bytes
      then
         raise Storage_Error with "theme operation accounting overflow";
      end if;

      declare
         Combined_Addresses : Address_Sets.Set := Object.State.Theme_Addresses;
         Previous_Addresses : Address_Sets.Set;
      begin
         for Address of Seen loop
            Combined_Addresses.Insert (Address);
         end loop;
         First := Head;
         Previous_Tail := Object.State.Theme_Operations_Tail;
         if Previous_Tail = null then
            Object.State.Theme_Operations := First;
         else
            Previous_Tail.Next := First;
         end if;
         Object.State.Theme_Operations_Tail := Last;
         Object.State.Theme_Operation_Count :=
           Object.State.Theme_Operation_Count + Added_Count;
         Object.State.Theme_Operation_Bytes :=
           Object.State.Theme_Operation_Bytes + Added_Bytes;
         Current := First;
         while Current /= null loop
            Current.Owner := Object;
            Current := Current.Next;
         end loop;
         Address_Sets.Move
           (Target => Previous_Addresses, Source => Object.State.Theme_Addresses);
         Address_Sets.Move
           (Target => Object.State.Theme_Addresses, Source => Combined_Addresses);
         begin
            Synchronize (Container, Object);
         exception
            when others =>
               if Previous_Tail = null then
                  Object.State.Theme_Operations := null;
               else
                  Previous_Tail.Next := null;
               end if;
               Object.State.Theme_Operations_Tail := Previous_Tail;
               Object.State.Theme_Operation_Count :=
                 Object.State.Theme_Operation_Count - Added_Count;
               Object.State.Theme_Operation_Bytes :=
                 Object.State.Theme_Operation_Bytes - Added_Bytes;
               Current := First;
               while Current /= null loop
                  Current.Owner := null;
                  Current := Current.Next;
               end loop;
               Address_Sets.Move
                 (Target => Combined_Addresses,
                  Source => Object.State.Theme_Addresses);
               Address_Sets.Move
                 (Target => Object.State.Theme_Addresses,
                  Source => Previous_Addresses);
               First := null;
               Last := null;
               raise;
         end;
      end;
      Head := null;
   end Append_List;

   procedure Start
     (Transaction : in out Append_Transaction;
      Object      : Image_Object_Access;
      Operation   : in out Theme_Operation_Access)
   is
      Previous : constant Theme_Operation_Access :=
        (if Object = null then null else Object.State.Theme_Operations_Tail);
      First, Last : Theme_Operation_Access;
      Count, Bytes : Natural;
   begin
      if Transaction.Operation /= null then
         raise Program_Error with "theme append transaction is already active";
      elsif not Is_Owned (Transaction.Container.all, Object) then
         raise Program_Error with "image object is not owned by this store";
      elsif Object.State.Theme_Transaction_Active then
         raise Program_Error with "image object already has an active theme transaction";
      end if;
      Object.State.Theme_Transaction_Active := True;
      Object.State.Theme_Transaction_Quarantined := False;
      begin
         Append_List
           (Transaction.Container.all, Object, Operation,
            First, Last, Count, Bytes);
      exception
         when others =>
            Object.State.Theme_Transaction_Active := False;
            raise;
      end;
      Transaction.Object := Object;
      Transaction.Previous_Tail := Previous;
      Transaction.Operation := First;
      Transaction.Last := Last;
      Transaction.Count := Count;
      Transaction.Bytes := Bytes;
   end Start;

   procedure Commit (Transaction : in out Append_Transaction) is
   begin
      if Transaction.Object /= null then
         Transaction.Object.State.Theme_Transaction_Active := False;
         Transaction.Object.State.Theme_Transaction_Quarantined := False;
      end if;
      Transaction.Object := null;
      Transaction.Previous_Tail := null;
      Transaction.Operation := null;
      Transaction.Last := null;
      Transaction.Count := 0;
      Transaction.Bytes := 0;
   end Commit;

   procedure Rollback (Transaction : in out Append_Transaction) is
      Object : constant Image_Object_Access := Transaction.Object;
      Operation : Theme_Operation_Access := Transaction.Operation;
      Current : Theme_Operation_Access;
      Seen_Count : Natural := 0;
      Seen_Bytes : Natural := 0;
   begin
      if Operation = null then
         return;
      elsif not Is_Owned (Transaction.Container.all, Object)
        or else Object.State.Theme_Operations_Tail /= Transaction.Last
        or else Transaction.Last = null
        or else Transaction.Last.Next /= null
        or else Object.State.Theme_Operation_Count < Transaction.Count
        or else Object.State.Theme_Operation_Bytes < Transaction.Bytes
        or else Object.Accounted_Bytes < Transaction.Bytes
        or else Transaction.Container.Bytes < Transaction.Bytes
      then
         raise Program_Error with "theme append transaction invariant violated";
      end if;
      Current := Operation;
      while Current /= null loop
         if Current.Owner /= Object
           or else Seen_Count = Natural'Last
           or else Current.Length > Natural'Last - Seen_Bytes
           or else
             (not Terminal.App.Owned_Image_Data.Is_Empty (Current.Bytes)
              and then not Object.State.Theme_Addresses.Contains
                (Terminal.App.Owned_Image_Data.Unsafe_View
                   (Current.Bytes).all'Address))
         then
            raise Program_Error with
              "theme append transaction ownership invariant violated";
         end if;
         Seen_Count := Seen_Count + 1;
         Seen_Bytes := Seen_Bytes + Current.Length;
         Current := Current.Next;
      end loop;
      if Seen_Count /= Transaction.Count
        or else Seen_Bytes /= Transaction.Bytes
      then
         raise Program_Error with "theme append transaction suffix mismatch";
      end if;
      Assert_Not_Borrowed (Object.all);
      if Transaction.Previous_Tail = null then
         Object.State.Theme_Operations := null;
      else
         Transaction.Previous_Tail.Next := null;
      end if;
      Object.State.Theme_Operations_Tail := Transaction.Previous_Tail;
      Object.State.Theme_Operation_Count :=
        Object.State.Theme_Operation_Count - Transaction.Count;
      Object.State.Theme_Operation_Bytes :=
        Object.State.Theme_Operation_Bytes - Transaction.Bytes;
      Object.Accounted_Bytes := Object.Accounted_Bytes - Transaction.Bytes;
      Transaction.Container.Bytes :=
        Transaction.Container.Bytes - Transaction.Bytes;
      Current := Operation;
      while Current /= null loop
         if not Terminal.App.Owned_Image_Data.Is_Empty (Current.Bytes) then
            Object.State.Theme_Addresses.Exclude
              (Terminal.App.Owned_Image_Data.Unsafe_View
                 (Current.Bytes).all'Address);
         end if;
         Current.Owner := null;
         Current := Current.Next;
      end loop;
      Transaction.Object := null;
      Object.State.Theme_Transaction_Active := False;
      Object.State.Theme_Transaction_Quarantined := False;
      Transaction.Previous_Tail := null;
      Transaction.Operation := null;
      Transaction.Last := null;
      Transaction.Count := 0;
      Transaction.Bytes := 0;
      Release_Theme_Operation_List (Operation);
   end Rollback;

   overriding procedure Finalize
     (Transaction : in out Append_Transaction) is
   begin
      if Transaction.Operation /= null then
         Rollback (Transaction);
      end if;
   exception
      when E : others =>
         --  Never convert a failed rollback into a committed history suffix.
         --  Keep the transaction locked against mutation and mark the object
         --  quarantined. Explicit deletion and store finalization can then
         --  reclaim it without treating the provisional suffix as committed.
         if Transaction.Object /= null then
            Transaction.Object.State.Theme_Transaction_Quarantined := True;
         end if;
         Transaction.Object := null;
         Transaction.Previous_Tail := null;
         Transaction.Operation := null;
         Transaction.Last := null;
         Transaction.Count := 0;
         Transaction.Bytes := 0;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Theme_Transaction,
            E,
            "rollback theme append transaction");
   end Finalize;
end Terminal.App.Image_Store.Themes;
