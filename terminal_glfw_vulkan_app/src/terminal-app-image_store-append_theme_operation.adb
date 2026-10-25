separate (Terminal.App.Image_Store)
procedure Append_Theme_Operation
  (Container : in out Store;
   Object    : Image_Object_Access;
   Operation : in out Theme_Operation_Access)
is
   Previous_Tail : Theme_Operation_Access;
begin
   if Operation = null then
      raise Constraint_Error with "cannot append a null theme operation";
   elsif not Is_Owned (Container, Object) then
      raise Program_Error with "image object is not owned by this store";
   elsif Operation.Next /= null then
      raise Program_Error with "theme operation is already linked";
   elsif (Operation.Bytes = null and then Operation.Length /= 0)
     or else (Operation.Bytes /= null
              and then Operation.Length /= Operation.Bytes'Length)
   then
      raise Constraint_Error with "theme operation length does not match data";
   elsif Operation.Bytes /= null
     and then (Owns_Non_Theme_Data (Object, Operation.Bytes)
               or else Object.Theme_Addresses.Contains
                 (Operation.Bytes.all'Address))
   then
      raise Program_Error with "theme operation aliases owned storage";
   elsif Object.Theme_Operation_Count = Natural'Last
     or else Operation.Length > Natural'Last - Object.Theme_Operation_Bytes
   then
      raise Storage_Error with "theme operation accounting overflow";
   end if;
   Previous_Tail := Object.Theme_Operations_Tail;
   if Operation = Previous_Tail then
      raise Program_Error with "theme operation is already linked";
   end if;
   if Operation.Bytes /= null then
      Object.Theme_Addresses.Insert (Operation.Bytes.all'Address);
   end if;
   if Previous_Tail = null then
      Object.Theme_Operations := Operation;
   else
      Previous_Tail.Next := Operation;
   end if;
   Object.Theme_Operations_Tail := Operation;
   Object.Theme_Operation_Count := Object.Theme_Operation_Count + 1;
   Object.Theme_Operation_Bytes := Object.Theme_Operation_Bytes + Operation.Length;
   begin
      Synchronize (Container, Object);
   exception
      when others =>
         if Previous_Tail = null then
            Object.Theme_Operations := null;
         else
            Previous_Tail.Next := null;
         end if;
         Object.Theme_Operations_Tail := Previous_Tail;
         Object.Theme_Operation_Count := Object.Theme_Operation_Count - 1;
         Object.Theme_Operation_Bytes :=
           Object.Theme_Operation_Bytes - Operation.Length;
         if Operation.Bytes /= null then
            Object.Theme_Addresses.Delete (Operation.Bytes.all'Address);
         end if;
         raise;
   end;
   Operation := null;
end Append_Theme_Operation;
