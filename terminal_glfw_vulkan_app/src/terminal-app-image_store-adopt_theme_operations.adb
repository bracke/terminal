separate (Terminal.App.Image_Store)
procedure Adopt_Theme_Operations
  (Container : in out Store;
   Object    : Image_Object_Access;
   Head      : in out Theme_Operation_Access)
is
   Current : Theme_Operation_Access := Head;
   Slow : Theme_Operation_Access := Head;
   Fast : Theme_Operation_Access := Head;
   Tail : Theme_Operation_Access := null;
   Count : Natural := 0;
   Bytes : Natural := 0;
   Seen : Address_Sets.Set;

   procedure Register (Data : Terminal.App.Render_Model.Image_Data_Access) is
      Address : System.Address;
   begin
      if Data = null then
         return;
      end if;
      Address := Data.all'Address;
      if Seen.Contains (Address) then
         raise Program_Error with "theme operations share owned storage";
      end if;
      Seen.Insert (Address);
   end Register;
begin
   if not Is_Owned (Container, Object) then
      raise Program_Error with "image object is not owned by this store";
   elsif Object.Theme_Operations /= null then
      raise Program_Error with "image object already has theme operations";
   end if;
   while Fast /= null and then Fast.Next /= null loop
      Slow := Slow.Next;
      Fast := Fast.Next.Next;
      if Slow = Fast then
         raise Program_Error with "theme operation list is cyclic";
      end if;
   end loop;
   while Current /= null loop
      if (Current.Bytes = null and then Current.Length /= 0)
        or else (Current.Bytes /= null
                 and then Current.Length /= Current.Bytes'Length)
      then
         raise Constraint_Error with
           "theme operation length does not match data";
      end if;
      if Owns_Non_Theme_Data (Object, Current.Bytes) then
         raise Program_Error with "theme operation aliases owned storage";
      end if;
      Register (Current.Bytes);
      if Count = Natural'Last or else Current.Length > Natural'Last - Bytes then
         raise Storage_Error with "theme operation accounting overflow";
      end if;
      Count := Count + 1;
      Bytes := Bytes + Current.Length;
      Tail := Current;
      Current := Current.Next;
   end loop;
   Address_Sets.Move (Target => Object.Theme_Addresses, Source => Seen);
   Object.Theme_Operations := Head;
   Object.Theme_Operations_Tail := Tail;
   Object.Theme_Operation_Count := Count;
   Object.Theme_Operation_Bytes := Bytes;
   begin
      Synchronize (Container, Object);
   exception
      when others =>
         Object.Theme_Operations := null;
         Object.Theme_Operations_Tail := null;
         Object.Theme_Operation_Count := 0;
         Object.Theme_Operation_Bytes := 0;
         Object.Theme_Addresses.Clear;
         raise;
   end;
   Head := null;
end Adopt_Theme_Operations;
