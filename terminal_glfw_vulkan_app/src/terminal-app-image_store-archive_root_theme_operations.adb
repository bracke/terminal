separate (Terminal.App.Image_Store)
procedure Archive_Root_Theme_Operations
  (Container      : in out Store;
   Object         : Image_Object_Access;
   Max_Operations : Positive)
is
   type Archive_Entry is record
      Operation : Theme_Operation_Access := null;
      Keep      : Boolean := False;
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
   elsif Object.Theme_Operations = null then
      return;
   elsif Object.Theme_Operation_Count > Max_Operations then
      raise Program_Error with "theme operation limit invariant violated";
   end if;

   declare
      Operation_Count : constant Positive :=
        Positive (Object.Theme_Operation_Count);
      Entries : Archive_Vectors.Vector;
      Needed : Frame_Sets.Set;
      Current : Theme_Operation_Access := Object.Theme_Operations;
      New_Head : Theme_Operation_Access := null;
      New_Tail : Theme_Operation_Access := null;
      New_Count : Natural := 0;
      New_Bytes : Natural := 0;
      New_Addresses : Address_Sets.Set;
   begin
      Entries.Reserve_Capacity (Ada.Containers.Count_Type (Operation_Count));
      for I in 1 .. Operation_Count loop
         if Current = null then
            raise Program_Error with "theme operation count invariant violated";
         end if;
         Entries.Append
           (Archive_Entry'(Operation => Current, Keep => False));
         Current := Current.Next;
      end loop;
      if Current /= null then
         raise Program_Error with "theme operation count invariant violated";
      end if;

      Needed.Include (1);
      for I in reverse Entries.First_Index .. Entries.Last_Index loop
         Current := Entries (I).Operation;
         if Needed.Contains (Current.Target_Frame) then
            Entries.Replace_Element (I, (Operation => Current, Keep => True));
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
            if Entries (I).Operation.Bytes /= null then
               New_Addresses.Insert (Entries (I).Operation.Bytes.all'Address);
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
         else
            Free_Image_Data (Current.Bytes);
            Free_Theme_Operation (Current);
         end if;
      end loop;
      Object.Theme_Operations := New_Head;
      Object.Theme_Operations_Tail := New_Tail;
      Object.Theme_Operation_Count := New_Count;
      Object.Theme_Operation_Bytes := New_Bytes;
      Address_Sets.Move
        (Target => Object.Theme_Addresses, Source => New_Addresses);
      Synchronize (Container, Object);
   end;
end Archive_Root_Theme_Operations;
